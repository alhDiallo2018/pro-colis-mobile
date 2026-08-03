import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';

import '../../services/notification_engine.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final NotificationEngine _engine = NotificationEngine();
  final ApiService _api = ApiService();
  List<NotificationPreference> _preferences = [];
  List<Map<String, dynamic>> _serverPreferences = [];
  bool _loading = true;

  String _channelToServer(NotificationChannel c) =>
      c == NotificationChannel.inApp
          ? 'in_app'
          : c == NotificationChannel.email
              ? 'email'
              : 'sms';

  NotificationChannel? _channelFromServer(String s) {
    switch (s) {
      case 'in_app':
      case 'inApp':
        return NotificationChannel.inApp;
      case 'email':
        return NotificationChannel.email;
      case 'sms':
        return NotificationChannel.sms;
      default:
        return null;
    }
  }

  Map<String, dynamic> _toServer(NotificationPreference p) => {
        'eventType': p.eventType.value,
        'channels': p.channels.map(_channelToServer).toList(),
      };

  NotificationEventType? _eventTypeFromServer(Object? value) {
    final rawValue = value?.toString();
    for (final eventType in NotificationEventType.values) {
      if (eventType.value == rawValue) return eventType;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // On part des défauts (tous les types) puis on surcharge avec le serveur.
    final prefs = await _engine.getPreferences();
    final byType = {for (final p in prefs) p.eventType: p};
    try {
      final server = await _api.getNotificationPreferences();
      for (final m in server) {
        // Les réglages chauffeur utilisent le format `{type, enabled}` dans
        // le même champ JSON. On les conserve sans les interpréter comme un
        // faux événement `parcel_created`.
        final et = _eventTypeFromServer(m['eventType']);
        if (et == null) continue;
        final chans = ((m['channels'] as List?) ?? [])
            .map((c) => _channelFromServer(c.toString()))
            .whereType<NotificationChannel>()
            .toList();
        byType[et] = NotificationPreference(
          eventType: et,
          channels: chans.isNotEmpty ? chans : [NotificationChannel.inApp],
        );
      }
      _serverPreferences = server;
    } catch (_) {
      // Serveur indisponible : on garde les préférences locales.
    }
    if (mounted) {
      setState(() {
        _preferences = prefs.map((p) => byType[p.eventType] ?? p).toList();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    try {
      // Le cache conserve le choix hors ligne, mais le message de succès n'est
      // affiché qu'après confirmation de la persistance par l'API.
      await _engine.updatePreferences(_preferences);
      // Le backend stocke ce document JSON tel quel. Préserver les entrées
      // inconnues empêche cet écran d'effacer les trois réglages chauffeur.
      final serverPayload = <Map<String, dynamic>>[
        ..._serverPreferences
            .where((entry) => _eventTypeFromServer(entry['eventType']) == null)
            .map(Map<String, dynamic>.from),
        ..._preferences.map(_toServer),
      ];
      final synchronized = await _api.updateNotificationPreferences(
        serverPayload,
      );
      if (synchronized) _serverPreferences = serverPayload;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synchronized
                ? 'Préférences enregistrées'
                : 'Préférences locales enregistrées, synchronisation en attente',
          ),
          backgroundColor: synchronized ? AppTheme.green600 : AppTheme.amber600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NotificationPreferences] Échec de sauvegarde: '
        '$error\n$stackTrace',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d’enregistrer les préférences'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _toggleChannel(int index, NotificationChannel channel) {
    setState(() {
      final current = _preferences[index].channels;
      final updated = current.contains(channel)
          ? current.where((c) => c != channel).toList()
          : [...current, channel];
      _preferences[index] = _preferences[index].copyWith(
          channels: updated.isNotEmpty ? updated : [NotificationChannel.inApp]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('Enregistrer'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.teal50,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppTheme.teal600, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Gérez vos préférences de notification pour chaque type d\'événement.',
                          style: AppFonts.manrope(
                              fontSize: 13, color: AppTheme.teal700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_preferences.length, (i) {
                  final pref = _preferences[i];
                  final hasEmail =
                      pref.channels.contains(NotificationChannel.email);
                  final hasSms =
                      pref.channels.contains(NotificationChannel.sms);
                  final hasInApp =
                      pref.channels.contains(NotificationChannel.inApp);

                  return PcCard(
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pref.eventType.label,
                            style: AppFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _ChannelChip(
                                label: 'In-app',
                                icon: Icons.notifications_active,
                                enabled: hasInApp,
                                alwaysOn: true,
                                onToggle: () {},
                              ),
                              const SizedBox(width: 8),
                              _ChannelChip(
                                label: 'Email',
                                icon: Icons.email_outlined,
                                enabled: hasEmail,
                                onToggle: () => _toggleChannel(
                                    i, NotificationChannel.email),
                              ),
                              const SizedBox(width: 8),
                              _ChannelChip(
                                label: 'SMS',
                                icon: Icons.sms_outlined,
                                enabled: hasSms,
                                onToggle: () =>
                                    _toggleChannel(i, NotificationChannel.sms),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool alwaysOn;
  final VoidCallback onToggle;

  const _ChannelChip({
    required this.label,
    required this.icon,
    required this.enabled,
    this.alwaysOn = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alwaysOn ? null : onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? AppTheme.teal50 : AppTheme.slate100,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: enabled ? AppTheme.teal500 : AppTheme.slate200,
            width: enabled ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: enabled ? AppTheme.teal600 : AppTheme.slate400),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? AppTheme.teal700 : AppTheme.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
