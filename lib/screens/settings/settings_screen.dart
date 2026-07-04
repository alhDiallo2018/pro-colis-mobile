// lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../screens/help/help_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _biometricEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
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

  Future<void> _changePin() async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
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

              final changeResult = await ref
                  .read(authProvider.notifier)
                  .changePin(
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

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.slate200),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _SettingsGroup(
            title: 'Compte',
            children: [
              _SettingsRow(
                icon: Icons.person_rounded,
                title: 'Informations personnelles',
                onTap: _navigateToProfile,
              ),
              const _SettingsDivider(),
              _SettingsRow(
                icon: Icons.pin_rounded,
                title: 'Modifier le code PIN',
                onTap: _changePin,
              ),
              const _SettingsDivider(),
              _SettingsRow(
                icon: Icons.language_rounded,
                title: 'Langue',
                onTap: () {},
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Français',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: 'Notifications',
            children: [
              _SettingsRow(
                icon: Icons.notifications_rounded,
                title: 'Notifications push',
                trailing: Switch(
                  value: _pushEnabled,
                  onChanged: _togglePushNotifications,
                ),
                chevron: false,
              ),
              const _SettingsDivider(),
              _SettingsRow(
                icon: Icons.mail_rounded,
                title: 'E-mails',
                trailing: Switch(
                  value: _emailEnabled,
                  onChanged: _toggleEmailNotifications,
                ),
                chevron: false,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: 'Sécurité',
            children: [
              _SettingsRow(
                icon: Icons.fingerprint_rounded,
                title: 'Déverrouillage biométrique',
                trailing: Switch(
                  value: _biometricEnabled,
                  onChanged: (value) =>
                      setState(() => _biometricEnabled = value),
                ),
                chevron: false,
              ),
              const _SettingsDivider(),
              const _SettingsRow(
                icon: Icons.devices_rounded,
                title: 'Appareils connectés',
                onTap: _noopSettingsAction,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: 'À propos',
            children: [
              const _SettingsRow(
                icon: Icons.description_rounded,
                title: 'Conditions d’utilisation',
                onTap: _noopSettingsAction,
              ),
              const _SettingsDivider(),
              const _SettingsRow(
                icon: Icons.shield_rounded,
                title: 'Confidentialité',
                onTap: _noopSettingsAction,
              ),
              const _SettingsDivider(),
              _SettingsRow(
                icon: Icons.help_rounded,
                title: 'Aide & support',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Se déconnecter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.red500,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'PRO COLIS · v1.0.0',
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
}

void _noopSettingsAction() {}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        ProcolisCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 68);
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.trailing,
    this.chevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(icon, color: AppTheme.slate600, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null)
                trailing!
              else if (chevron)
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.slate400),
            ],
          ),
        ),
      ),
    );
  }
}
