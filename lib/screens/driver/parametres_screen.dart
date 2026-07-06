// mobile/lib/screens/driver/parametres_screen.dart
// Paramètres chauffeur (compte, véhicule, disponibilité, notifications,
// sécurité, à propos) — restylé sur le design system ProColis (web-aligné).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/segmented_control.dart';

class DriverParametresScreen extends ConsumerStatefulWidget {
  const DriverParametresScreen({super.key});

  @override
  ConsumerState<DriverParametresScreen> createState() =>
      _DriverParametresScreenState();
}

class _DriverParametresScreenState
    extends ConsumerState<DriverParametresScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  int _availabilityIndex = 0;
  bool _isUpdatingAvailability = false;

  // Vehicle fields
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _typeController = TextEditingController();
  final _capacityController = TextEditingController();
  Map<String, dynamic>? _vehicle;

  // PIN fields
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _showPinForm = false;
  bool _isSaving = false;

  // Notification preferences (persistées localement en session)
  bool _notifMissions = true;
  bool _notifMessages = true;
  bool _notifPromos = false;

  static const _statuses = ['available', 'busy', 'offline'];

  @override
  void initState() {
    super.initState();
    // Initialise la disponibilité depuis le statut chauffeur courant.
    final status = ref.read(authProvider).user?.driverStatus;
    if (status != null) {
      final i = _statuses.indexOf(status.value);
      if (i >= 0) _availabilityIndex = i;
    }
    _loadVehicle();
  }

  @override
  void dispose() {
    _plateController.dispose();
    _modelController.dispose();
    _typeController.dispose();
    _capacityController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    setState(() => _isLoading = true);
    try {
      final vehicle = await _apiService.getDriverVehicle();
      if (mounted) {
        setState(() {
          _vehicle = vehicle != null ? Map<String, dynamic>.from(vehicle) : null;
          if (_vehicle != null) {
            _plateController.text = _vehicle!['plateNumber']?.toString() ?? '';
            _modelController.text = _vehicle!['model']?.toString() ?? '';
            _typeController.text = _vehicle!['type']?.toString() ?? '';
            _capacityController.text =
                _vehicle!['capacity']?.toString() ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveVehicle() async {
    setState(() => _isSaving = true);
    try {
      await _apiService.upsertVehicle({
        'plateNumber': _plateController.text.trim(),
        'model': _modelController.text.trim(),
        'type': _typeController.text.trim(),
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Véhicule enregistré'),
              backgroundColor: AppTheme.green600),
        );
        await _loadVehicle();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateAvailability(int index) async {
    setState(() {
      _availabilityIndex = index;
      _isUpdatingAvailability = true;
    });
    try {
      await _apiService.updateDriverStatus(_statuses[index]);
    } catch (e) {
      debugPrint('Erreur mise à jour disponibilité: $e');
    } finally {
      if (mounted) setState(() => _isUpdatingAvailability = false);
    }
  }

  Future<void> _changePin() async {
    if (_newPinController.text != _confirmPinController.text) {
      _showError('Les PIN ne correspondent pas');
      return;
    }
    if (_newPinController.text.length != 6) {
      _showError('Le PIN doit faire 6 chiffres');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await ref.read(authProvider.notifier).changePin(
            _currentPinController.text,
            _newPinController.text,
          );
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _showPinForm = false;
            _currentPinController.clear();
            _newPinController.clear();
            _confirmPinController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('PIN modifié avec succès'),
                backgroundColor: AppTheme.green600),
          );
        } else {
          _showError(result['message']?.toString() ?? 'Erreur');
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Voulez-vous vraiment quitter votre session ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.red400),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Paramètres'),
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // ==================== COMPTE ====================
                const PcSectionHeader('Compte'),
                if (user != null) _accountCard(user),
                const SizedBox(height: 22),

                // ==================== VÉHICULE ====================
                const PcSectionHeader('Véhicule'),
                PcCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _inputField(_plateController, 'Plaque d\'immatriculation',
                          Icons.pin_rounded, 'DK-2024-AB'),
                      const SizedBox(height: 14),
                      _inputField(_modelController, 'Modèle',
                          Icons.directions_car_rounded, 'Toyota HiAce'),
                      const SizedBox(height: 14),
                      _inputField(_typeController, 'Type de véhicule',
                          Icons.category_rounded, 'Minibus'),
                      const SizedBox(height: 14),
                      _inputField(_capacityController, 'Capacité (kg)',
                          Icons.scale_rounded, '1500',
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 18),
                      PcButton(
                        _isSaving ? 'Enregistrement…' : 'Enregistrer le véhicule',
                        icon: Icons.save_rounded,
                        block: true,
                        loading: _isSaving,
                        onPressed: _isSaving ? null : _saveVehicle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ==================== DISPONIBILITÉ ====================
                const PcSectionHeader('Disponibilité'),
                PcCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Votre statut détermine si vous recevez de nouvelles missions.',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: AppTheme.slate500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SegmentedControl(
                        options: const ['Disponible', 'Occupé', 'Hors ligne'],
                        selectedIndex: _availabilityIndex,
                        onChanged: (index) {
                          if (!_isUpdatingAvailability) {
                            _updateAvailability(index);
                          }
                        },
                      ),
                      if (_isUpdatingAvailability) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ==================== NOTIFICATIONS ====================
                const PcSectionHeader('Notifications'),
                PcCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _switchRow(
                        icon: Icons.local_shipping_rounded,
                        tone: PcTone.primary,
                        title: 'Nouvelles missions',
                        subtitle: 'Être alerté des courses disponibles',
                        value: _notifMissions,
                        onChanged: (v) => setState(() => _notifMissions = v),
                      ),
                      const PcDivider(),
                      _switchRow(
                        icon: Icons.chat_bubble_rounded,
                        tone: PcTone.green,
                        title: 'Messages',
                        subtitle: 'Notifications des conversations',
                        value: _notifMessages,
                        onChanged: (v) => setState(() => _notifMessages = v),
                      ),
                      const PcDivider(),
                      _switchRow(
                        icon: Icons.campaign_rounded,
                        tone: PcTone.amber,
                        title: 'Promotions',
                        subtitle: 'Offres et actualités ProColis',
                        value: _notifPromos,
                        onChanged: (v) => setState(() => _notifPromos = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ==================== SÉCURITÉ ====================
                const PcSectionHeader('Sécurité'),
                if (!_showPinForm)
                  PcCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: PcListRow(
                      icon: Icons.lock_rounded,
                      iconTone: PcTone.primary,
                      title: 'Code PIN',
                      subtitle: 'Modifier votre code de connexion',
                      trailing: PcButton(
                        'Modifier',
                        variant: PcButtonVariant.secondary,
                        size: PcButtonSize.sm,
                        onPressed: () => setState(() => _showPinForm = true),
                      ),
                    ),
                  )
                else
                  PcCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: _currentPinController,
                          decoration: _pinDecoration('PIN actuel', Icons.lock_rounded),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          maxLength: 6,
                          obscureText: true,
                          style: AppTheme.mono(fontSize: 15),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _newPinController,
                          decoration:
                              _pinDecoration('Nouveau PIN', Icons.lock_reset_rounded),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          maxLength: 6,
                          obscureText: true,
                          style: AppTheme.mono(fontSize: 15),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _confirmPinController,
                          decoration: _pinDecoration(
                              'Confirmer le PIN', Icons.lock_reset_rounded),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          maxLength: 6,
                          obscureText: true,
                          style: AppTheme.mono(fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: PcButton(
                                'Annuler',
                                variant: PcButtonVariant.secondary,
                                block: true,
                                onPressed: () =>
                                    setState(() => _showPinForm = false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: PcButton(
                                _isSaving ? 'Modification…' : 'Modifier',
                                icon: Icons.check_rounded,
                                block: true,
                                loading: _isSaving,
                                onPressed: _isSaving ? null : _changePin,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),

                // ==================== À PROPOS ====================
                const PcSectionHeader('À propos'),
                PcCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _infoRow('Version', '1.0.0'),
                      const SizedBox(height: 14),
                      const PcDivider(),
                      const SizedBox(height: 14),
                      _infoRow('Application', 'PRO COLIS'),
                      const SizedBox(height: 14),
                      const PcDivider(),
                      const SizedBox(height: 14),
                      _infoRow('API', ApiService.baseUrl),
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
              ],
            ),
    );
  }

  // ==================== SOUS-COMPOSANTS ====================

  Widget _accountCard(User user) {
    final metaParts = <String>[];
    if (user.phone.isNotEmpty) metaParts.add(user.formattedPhone);
    if (user.garageName != null && user.garageName!.isNotEmpty) {
      metaParts.add(user.garageName!);
    }
    return PcCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          PcAvatar(
            user.fullName.isNotEmpty ? user.fullName : 'Chauffeur',
            size: 56,
            status: PcAvatarStatus.online,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName.isNotEmpty ? user.fullName : 'Chauffeur',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const PcBadge('Chauffeur', tone: PcTone.primary),
                    if (user.phone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          user.formattedPhone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.mono(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (user.garageName != null &&
                    user.garageName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.garageName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required PcTone tone,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
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

  Widget _inputField(
      TextEditingController controller, String label, IconData icon,
      String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }

  InputDecoration _pinDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      counterText: '',
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.manrope(
                color: AppTheme.slate500, fontSize: 14)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontSize: 14)),
        ),
      ],
    );
  }
}
