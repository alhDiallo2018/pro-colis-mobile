// lib/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:procolis/theme/fonts.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../providers/theme_provider.dart';
import '../../screens/help/help_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
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

      // L'empreinte d'abord : inutile de réclamer le PIN si le capteur refuse.
      final approved = await BiometricService.authenticate(
        'Confirmez votre empreinte pour activer le déverrouillage',
      );
      if (!approved) {
        _notify('Empreinte non reconnue');
        return;
      }

      final pin = await _askPin();
      if (pin == null) return;

      final identifier =
          await ref.read(authProvider.notifier).getSavedIdentifier();
      if (identifier == null || identifier.isEmpty) {
        _notify('Reconnectez-vous une fois pour activer cette option');
        return;
      }

      // Le PIN est vérifié par l'API avant d'être mémorisé : sans ce contrôle,
      // une faute de frappe serait enregistrée et l'empreinte échouerait
      // ensuite sans que la cause soit compréhensible. La vérification passe
      // par ApiService et non par le provider : un PIN erroné y basculerait
      // l'état d'authentification en erreur et déconnecterait l'utilisateur.
      final result = await ApiService().loginWithPin(pin, identifier);
      if (result['accessToken'] == null && result['success'] != true) {
        _notify(result['message']?.toString() ?? 'Code PIN incorrect');
        return;
      }

      await BiometricService.enable(pin);
      if (!mounted) return;
      setState(() => _biometricEnabled = true);
      _notify('Déverrouillage biométrique activé');
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askPin() async {
    // Appelé après l'attente du capteur : l'écran a pu être quitté entre-temps.
    if (!mounted) return null;
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmez votre code PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: '6 chiffres',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pin == null || pin.length != 6) return null;
    return pin;
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
                PcListRow(
                  icon: Icons.language_rounded,
                  iconTone: PcTone.neutral,
                  title: 'Langue',
                  subtitle: 'Langue de l\'application',
                  trailing: Text(
                    'Français',
                    style: AppFonts.plusJakartaSans(
                      color: AppTheme.slate500,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  chevron: true,
                  onTap: () {},
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
                      ? 'Empreinte ou reconnaissance faciale'
                      : 'Aucun capteur configuré sur cet appareil',
                  value: _biometricEnabled,
                  onChanged: _biometricAvailable && !_biometricBusy
                      ? _toggleBiometric
                      : null,
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
          PcCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const PcListRow(
                  icon: Icons.description_rounded,
                  iconTone: PcTone.neutral,
                  title: 'Conditions d’utilisation',
                  chevron: true,
                  onTap: _noopSettingsAction,
                ),
                const PcDivider(),
                const PcListRow(
                  icon: Icons.shield_rounded,
                  iconTone: PcTone.neutral,
                  title: 'Confidentialité',
                  chevron: true,
                  onTap: _noopSettingsAction,
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
        _themeModeOption(ThemeMode.system, Icons.brightness_auto_rounded, current),
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
