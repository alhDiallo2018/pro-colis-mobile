// lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:procolis/theme/fonts.dart';

import '../../providers/auth_provider.dart';
import '../../providers/session_timeout_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/session_timeout_preference.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../screens/help/help_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/app_update_gate.dart';
import '../../widgets/pc_components.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _biometricBusy = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
    _loadBiometricState();
  }

  /// Le réglage reflète l'appareil : afficher un interrupteur actif sur un
  /// téléphone sans capteur promettait un déverrouillage qui n'arrivait jamais.
  Future<void> _loadBiometricState() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);

    try {
      if (!value) {
        await BiometricService.disable();
        if (!mounted) return;
        setState(() => _biometricEnabled = false);
        _notify('Déverrouillage biométrique désactivé');
        return;
      }

      // Vérifier localement l'identité avant d'activer le verrou pour ce compte.
      final approved = await BiometricService.authenticate(
        'Confirmez votre empreinte pour activer le déverrouillage',
      );
      if (!approved) {
        _notify('Empreinte non reconnue');
        return;
      }

      final user = ref.read(authProvider).user;
      if (user == null) {
        _notify('Reconnectez-vous une fois pour activer cette option');
        return;
      }
      await BiometricService.enableForSession(user.id);
      if (!mounted) return;
      setState(() => _biometricEnabled = true);
      _notify('Déverrouillage biométrique activé');
    } catch (error, stackTrace) {
      debugPrint('[Settings] Configuration biométrique impossible : $error');
      debugPrintStack(
        label: '[Settings] Trace de configuration biométrique',
        stackTrace: stackTrace,
      );
      _notify('Impossible de modifier le déverrouillage biométrique');
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pushEnabled = prefs.getBool('pref_notifications_push') ?? true;
        _emailEnabled = prefs.getBool('pref_notifications_email') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _togglePushNotifications(bool value) async {
    setState(() => _pushEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_notifications_push', value);
    } catch (_) {}
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    setState(() => _emailEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_notifications_email', value);
    } catch (_) {}
  }

  String _localeLabel(Locale? locale) {
    if (locale == null) return 'Automatique';
    switch (locale.languageCode) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      case 'wo':
        return 'Wolof';
      default:
        return locale.languageCode;
    }
  }

  Future<void> _pickLanguage(WidgetRef ref, String? currentCode) async {
    final choices = <(String?, String)>[
      (null, 'Automatique (système)'),
      ('fr', 'Français'),
      ('en', 'English'),
      ('wo', 'Wolof'),
    ];
    final picked = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: choices
              .map(
                (c) => ListTile(
                  leading: Icon(
                    c.$1 == currentCode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(c.$2),
                  onTap: () => Navigator.pop(ctx, c.$1),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (!mounted) return;
    await ref.read(localeProvider.notifier).set(
          picked == null ? null : Locale(picked),
        );
  }

  Future<void> _changePin() async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le code PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN actuel',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.length != 6) {
                    return 'Le PIN doit comporter 6 chiffres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Nouveau PIN',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.length != 6) {
                    return 'Le PIN doit comporter 6 chiffres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le nouveau PIN',
                  counterText: '',
                ),
                validator: (value) {
                  if (value != newPinController.text) {
                    return 'Les PIN ne correspondent pas';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final changeResult =
                  await ref.read(authProvider.notifier).changePin(
                        currentPinController.text,
                        newPinController.text,
                      );

              if (!ctx.mounted) return;

              if (changeResult['success'] == true) {
                Navigator.pop(ctx, true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN modifié avec succès'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      changeResult['message']?.toString() ??
                          'Erreur lors du changement de PIN',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );

    currentPinController.dispose();
    newPinController.dispose();
    confirmPinController.dispose();
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _pickSessionTimeout() async {
    final current = ref.read(sessionTimeoutProvider);
    final picked = await showModalBottomSheet<SessionTimeoutOption>(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.slate300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Durée de session',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nous vous redemanderons de vous connecter après cette durée d’inactivité.',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                for (final option in SessionTimeoutOption.values)
                  _timeoutOptionTile(ctx, option, option == current),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    await ref.read(sessionTimeoutProvider.notifier).setOption(picked);
    if (!mounted) return;
    _notify('Durée de session mise à jour : ${picked.label}');
  }

  Widget _timeoutOptionTile(
      BuildContext ctx, SessionTimeoutOption option, bool selected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: () => Navigator.of(ctx).pop(option),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: .08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppTheme.primary : AppTheme.slate400,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: AppFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.description,
                      style: AppFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: AppTheme.slate200),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ==================== COMPTE ====================
          const PcSectionHeader('Compte'),
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                PcListRow(
                  icon: Icons.person_rounded,
                  iconTone: PcTone.primary,
                  title: 'Informations personnelles',
                  subtitle: 'Nom, e-mail et coordonnées',
                  chevron: true,
                  onTap: _navigateToProfile,
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.pin_rounded,
                  iconTone: PcTone.neutral,
                  title: 'Modifier le code PIN',
                  subtitle: 'Changer votre code de connexion',
                  chevron: true,
                  onTap: _changePin,
                ),
                const PcDivider(),
                Consumer(
                  builder: (context, ref, _) {
                    final locale = ref.watch(localeProvider);
                    final label = _localeLabel(locale);
                    return PcListRow(
                      icon: Icons.language_rounded,
                      iconTone: PcTone.neutral,
                      title: 'Langue',
                      subtitle: "Langue de l'application",
                      trailing: Text(
                        label,
                        style: AppFonts.plusJakartaSans(
                          color: AppTheme.slate500,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      chevron: true,
                      onTap: () => _pickLanguage(ref, locale?.languageCode),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ==================== APPARENCE ====================
          const PcSectionHeader('Apparence'),
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                PcListRow(
                  icon: Icons.dark_mode_rounded,
                  iconTone: PcTone.primary,
                  title: 'Thème',
                  subtitle: 'Clair, sombre ou selon l\'appareil',
                  trailing: Text(
                    themeModeLabel(ref.watch(themeModeProvider)),
                    style: AppFonts.plusJakartaSans(
                      color: AppTheme.slate500,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: _themeModeSelector(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ==================== NOTIFICATIONS ====================
          const PcSectionHeader('Notifications'),
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                PcListRow(
                  icon: Icons.tune_rounded,
                  iconTone: PcTone.primary,
                  title: 'Préférences de notification',
                  subtitle: 'Gérer les types de notifications',
                  chevron: true,
                  onTap: () => context.go('/settings/notifications'),
                ),
                const PcDivider(),
                _switchRow(
                  icon: Icons.notifications_rounded,
                  tone: PcTone.primary,
                  title: 'Notifications push',
                  subtitle: 'Alertes en temps réel sur cet appareil',
                  value: _pushEnabled,
                  onChanged: _togglePushNotifications,
                ),
                const PcDivider(),
                _switchRow(
                  icon: Icons.mail_rounded,
                  tone: PcTone.green,
                  title: 'E-mails',
                  subtitle: 'Recevoir les mises à jour par e-mail',
                  value: _emailEnabled,
                  onChanged: _toggleEmailNotifications,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ==================== SÉCURITÉ ====================
          const PcSectionHeader('Sécurité'),
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _switchRow(
                  icon: Icons.fingerprint_rounded,
                  tone: PcTone.primary,
                  title: 'Déverrouillage biométrique',
                  subtitle: _biometricAvailable
                      ? 'Ouvrir l’app par empreinte ou reconnaissance faciale'
                      : 'Aucun capteur configuré sur cet appareil',
                  value: _biometricEnabled,
                  onChanged: _biometricAvailable && !_biometricBusy
                      ? _toggleBiometric
                      : null,
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.timer_rounded,
                  iconTone: PcTone.primary,
                  title: 'Durée de session',
                  subtitle: ref.watch(sessionTimeoutProvider).description,
                  trailing: Text(
                    ref.watch(sessionTimeoutProvider).label,
                    style: AppFonts.plusJakartaSans(
                      color: AppTheme.slate500,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  chevron: true,
                  onTap: _pickSessionTimeout,
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.devices_rounded,
                  iconTone: PcTone.neutral,
                  title: 'Appareils connectés',
                  subtitle: 'Gérer vos sessions actives',
                  chevron: true,
                  onTap: _noopSettingsAction,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ==================== À PROPOS ====================
          const PcSectionHeader('À propos'),
          const AppUpdateSettingsTile(),
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                PcListRow(
                  icon: Icons.description_rounded,
                  iconTone: PcTone.neutral,
                  title: 'Conditions d’utilisation',
                  chevron: true,
                  // Empile la page légale pour que le retour restaure les paramètres.
                  onTap: () => context.push('/cgu'),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.shield_rounded,
                  iconTone: PcTone.neutral,
                  title: 'Confidentialité',
                  chevron: true,
                  onTap: () => context.push('/confidentialite'),
                ),
                const PcDivider(),
                PcListRow(
                  icon: Icons.help_rounded,
                  iconTone: PcTone.neutral,
                  title: 'Aide & support',
                  chevron: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ==================== DÉCONNEXION ====================
          PcButton(
            'Se déconnecter',
            icon: Icons.logout_rounded,
            variant: PcButtonVariant.danger,
            block: true,
            onPressed: _logout,
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'SENDPROCOLIS · v1.0.0',
              style: AppTheme.mono(
                color: AppTheme.slate400,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sélecteur segmenté du mode d'affichage. Le choix est appliqué et persisté
  /// immédiatement : toute l'application se reconstruit dans le nouveau thème.
  Widget _themeModeSelector() {
    final current = ref.watch(themeModeProvider);
    return Row(
      children: [
        _themeModeOption(
            ThemeMode.system, Icons.brightness_auto_rounded, current),
        const SizedBox(width: 8),
        _themeModeOption(ThemeMode.light, Icons.light_mode_rounded, current),
        const SizedBox(width: 8),
        _themeModeOption(ThemeMode.dark, Icons.dark_mode_rounded, current),
      ],
    );
  }

  Widget _themeModeOption(ThemeMode mode, IconData icon, ThemeMode current) {
    final selected = mode == current;
    return Expanded(
      child: Material(
        color: selected ? AppTheme.primary : AppTheme.slate100,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: selected
              ? null
              : () => ref.read(themeModeProvider.notifier).setMode(mode),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : AppTheme.slate500,
                ),
                const SizedBox(height: 4),
                Text(
                  themeModeLabel(mode),
                  style: AppFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.slate600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required PcTone tone,
    required String title,
    required String subtitle,
    required bool value,
    // Nul = interrupteur desactive : sur un appareil sans capteur biometrique,
    // l'option reste visible mais inactionnable plutot que d'etre escamotee.
    required ValueChanged<bool>? onChanged,
  }) {
    return PcListRow(
      icon: icon,
      iconTone: tone,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppTheme.primary,
      ),
    );
  }
}

void _noopSettingsAction() {}
