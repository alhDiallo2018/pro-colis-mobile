// mobile/lib/screens/profile/profile_screen.dart

// ignore_for_file: unused_element, avoid_print, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../screens/help/help_screen.dart';
import '../../services/api_service.dart';
import '../../screens/settings/settings_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/pc_components.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const ProfileScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const Color successColor = AppTheme.successColor;
  static const Color errorColor = AppTheme.errorColor;

  late User _user;
  bool _isLoading = false;
  bool _isInitialized = false;

  // Feedback intégré au formulaire (à la manière du Toast web).
  bool _profileSaved = false;
  String? _profileError;

  String _getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    return ApiService.resolveMediaUrl(imagePath);
  }
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();

  // Contrôleurs chauffeur
  final _vehiclePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehicleYearController = TextEditingController();

  // Contrôleurs PIN
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _showPinChangeForm = false;

  // Photo de profil
  XFile? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    debugPrint('📱 [PROFILE] _initializeData - Début');

    await ref.read(authProvider.notifier).refreshUser();

    final authState = ref.read(authProvider);
    if (authState.user != null) {
      _user = authState.user!;
      _initControllers();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
      debugPrint('✅ [PROFILE] Initialisation terminée');
    } else {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _initializeData();
      });
    }
  }

  void _initControllers() {
    debugPrint('📝 [PROFILE] _initControllers - Mise à jour des contrôleurs');

    _fullNameController.text = _user.fullName;
    _emailController.text = _user.email;
    _phoneController.text = _user.phone;
    _addressController.text = _user.address ?? '';
    _cityController.text = _user.city ?? '';
    _regionController.text = _user.region ?? '';
    _vehiclePlateController.text = _user.vehiclePlate ?? '';
    _vehicleModelController.text = _user.vehicleModel ?? '';
    _vehicleColorController.text = _user.vehicleColor ?? '';
    _vehicleYearController.text = _user.vehicleYear?.toString() ?? '';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _vehiclePlateController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _vehicleYearController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }


  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        _profileImage = image;
        await _uploadProfilePhoto();
      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur: $e', errorColor);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null) {
        _profileImage = image;
        await _uploadProfilePhoto();
      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur: $e', errorColor);
    }
  }

  Future<void> _uploadProfilePhoto() async {
    if (_profileImage == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final apiService = ApiService();
      final response =
          await apiService.uploadAndUpdateProfilePhoto(_profileImage!);

      if (mounted && response['success'] == true) {
        _showSnackBar('Photo de profil mise à jour', successColor);
        await ref.read(authProvider.notifier).refreshUser();
        await _initializeData();
      } else if (mounted) {
        _showSnackBar(response['message'] ?? 'Erreur', errorColor);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur: $e', errorColor);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.cardColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Changer la photo',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const PcDivider(),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppTheme.primary),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== MISE À JOUR ====================

  Future<void> _updateProfile() async {
    setState(() {
      _profileSaved = false;
      _profileError = null;
    });

    if (_fullNameController.text.trim().isEmpty) {
      setState(() => _profileError = 'Le nom complet est requis.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ApiService();

      final Map<String, dynamic> data = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'region': _regionController.text.trim(),
      };

      if (_user.role == UserRole.driver) {
        data['vehiclePlate'] = _vehiclePlateController.text.trim();
        data['vehicleModel'] = _vehicleModelController.text.trim();
        data['vehicleColor'] = _vehicleColorController.text.trim();
        if (_vehicleYearController.text.trim().isNotEmpty) {
          data['vehicleYear'] =
              int.tryParse(_vehicleYearController.text.trim());
        }
      }

      String endpoint;
      switch (_user.role) {
        case UserRole.client:
          endpoint = '/client/profile';
          break;
        case UserRole.driver:
          endpoint = '/driver/profile';
          break;
        case UserRole.admin:
          endpoint = '/garage-admin/profile';
          break;
        case UserRole.superAdmin:
          endpoint = '/super-admin/profile';
          break;
      }

      final response = await apiService.updateProfileByRole(endpoint, data);

      if (mounted) {
        setState(() => _isLoading = false);

        if (response['success'] == true) {
          setState(() {
            _profileSaved = true;
            _profileError = null;
          });
          await ref.read(authProvider.notifier).refreshUser();
          await _initializeData();
        } else {
          setState(() => _profileError = response['message'] ?? 'Erreur.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _profileError = 'Erreur: $e';
        });
      }
    }
  }

  Future<void> _updatePin() async {
    if (_newPinController.text != _confirmPinController.text) {
      _showSnackBar('Les PIN ne correspondent pas', errorColor);
      return;
    }
    if (_newPinController.text.length != 6) {
      _showSnackBar('Le PIN doit contenir 6 chiffres', errorColor);
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref.read(authProvider.notifier).changePin(
          _currentPinController.text,
          _newPinController.text,
        );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        setState(() => _showPinChangeForm = false);
        _currentPinController.clear();
        _newPinController.clear();
        _confirmPinController.clear();
        _showSnackBar('PIN mis à jour', successColor);
      } else {
        _showSnackBar(result['message'], errorColor);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpScreen()),
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (!_isInitialized || authState.user == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
        bottomNavigationBar: widget.embedded ? null : const AppBottomNav(),
      );
    }

    _user = authState.user!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openSettings,
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 112),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildInfoCard(),
          const SizedBox(height: 16),
          _buildAccountCard(),
          const SizedBox(height: 16),
          _buildSettingsCard(),
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
      bottomNavigationBar: widget.embedded ? null : const AppBottomNav(),
    );
  }

  // ---- En-tête (avatar + nom + rôle + téléphone) ----

  Widget _buildHeaderCard() {
    return PcCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildHeaderAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _user.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    PcBadge(_user.role.label, tone: PcTone.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _user.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.mono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAvatar() {
    const double d = 64;

    Widget base;
    if (_profileImage != null) {
      base = ClipOval(
        child: kIsWeb
            ? Image.network(
                _profileImage!.path,
                width: d,
                height: d,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackAvatar(d),
              )
            : Image.file(
                File(_profileImage!.path),
                width: d,
                height: d,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackAvatar(d),
              ),
      );
    } else if (_user.profilePhoto != null && _user.profilePhoto!.isNotEmpty) {
      base = ClipOval(
        child: Image.network(
          _getFullImageUrl(_user.profilePhoto),
          width: d,
          height: d,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(d),
        ),
      );
    } else {
      base = _fallbackAvatar(d);
    }

    return SizedBox(
      width: d + 4,
      height: d + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(width: d, height: d, child: base),
          // Pastille en ligne (statut).
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: AppTheme.green500,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cardColor, width: 2.5),
              ),
            ),
          ),
          // Bouton édition photo.
          Positioned(
            right: -4,
            bottom: -4,
            child: Material(
              color: AppTheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isUploadingPhoto ? null : _showImageSourceDialog,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cardColor, width: 2.5),
                  ),
                  alignment: Alignment.center,
                  child: _isUploadingPhoto
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt_rounded,
                          size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(double d) =>
      PcAvatar(_user.fullName, size: d);

  // ---- Statistiques (points / colis) ----

  Widget _buildStatsRow() {
    return const PcStatBox(
      icon: Icons.inventory_2_rounded,
      value: '31',
      label: 'Colis envoyés',
      tone: PcTone.primary,
    );
  }

  // ---- Informations personnelles (formulaire éditable) ----

  Widget _buildInfoCard() {
    final canSave = _fullNameController.text.trim().isNotEmpty && !_isLoading;

    return PcCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations personnelles',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _formField(
            controller: _fullNameController,
            label: 'Nom complet',
            icon: Icons.badge_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _formField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.mail_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _formField(
                  controller: _phoneController,
                  label: 'Téléphone',
                  icon: Icons.call_rounded,
                  readOnly: true,
                  mono: true,
                  helperText: 'Le téléphone n\'est pas modifiable',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _formField(
                  controller: _cityController,
                  label: 'Ville',
                  icon: Icons.location_on_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _formField(
                  controller: _addressController,
                  label: 'Adresse',
                  icon: Icons.home_rounded,
                ),
              ),
            ],
          ),
          if (_profileError != null) ...[
            const SizedBox(height: 14),
            _buildToast(success: false, message: _profileError!),
          ],
          if (_profileSaved && _profileError == null) ...[
            const SizedBox(height: 14),
            _buildToast(success: true, message: 'Profil mis à jour.'),
          ],
          const SizedBox(height: 18),
          PcButton(
            'Enregistrer',
            icon: Icons.save_rounded,
            block: true,
            loading: _isLoading,
            onPressed: canSave ? _updateProfile : null,
          ),
        ],
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    bool mono = false,
    String? helperText,
    void Function(String)? onChanged,
  }) {
    return CustomTextField(
      controller: controller,
      label: label,
      prefixIcon: icon,
      keyboardType: keyboardType,
      readOnly: readOnly,
      helperText: helperText,
      onChanged: onChanged,
      style: mono
          ? AppTheme.mono(fontSize: 15, color: AppTheme.textPrimary)
          : const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
    );
  }

  Widget _buildToast({required bool success, required String message}) {
    final Color bg = success ? AppTheme.green50 : AppTheme.red50;
    final Color fg = success ? AppTheme.green700 : AppTheme.red500;
    final IconData icon =
        success ? Icons.check_circle_rounded : Icons.error_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Compte & sécurité ----

  Widget _buildAccountCard() {
    return PcCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          PcListRow(
            icon: Icons.location_on_rounded,
            iconTone: PcTone.primary,
            title: 'Adresses',
            subtitle: '${_user.city ?? 'Abidjan'}, Côte d’Ivoire',
            chevron: true,
          ),
          const PcDivider(),
          PcListRow(
            icon: Icons.pin_rounded,
            iconTone: PcTone.primary,
            title: 'Code PIN',
            subtitle:
                _user.hasPin ? 'Connexion rapide activée' : 'À configurer',
            trailing: Icon(
              _showPinChangeForm
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: AppTheme.slate400,
            ),
            onTap: () =>
                setState(() => _showPinChangeForm = !_showPinChangeForm),
          ),
          if (_showPinChangeForm) _buildPinForm(),
        ],
      ),
    );
  }

  Widget _buildPinForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          CustomTextField(
            controller: _currentPinController,
            label: 'PIN actuel',
            prefixIcon: Icons.lock_rounded,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _newPinController,
            label: 'Nouveau PIN (6 chiffres)',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _confirmPinController,
            label: 'Confirmer le PIN',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 14),
          PcButton(
            'Mettre à jour le PIN',
            icon: Icons.check_rounded,
            block: true,
            loading: _isLoading,
            onPressed: _isLoading ? null : _updatePin,
          ),
        ],
      ),
    );
  }

  // ---- Paramètres / aide / déconnexion ----

  Widget _buildSettingsCard() {
    return PcCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          PcListRow(
            icon: Icons.settings_rounded,
            iconTone: PcTone.neutral,
            title: 'Paramètres',
            chevron: true,
            onTap: _openSettings,
          ),
          const PcDivider(),
          PcListRow(
            icon: Icons.help_rounded,
            iconTone: PcTone.neutral,
            title: 'Aide & support',
            chevron: true,
            onTap: _openHelp,
          ),
          const PcDivider(),
          _buildLogoutRow(),
        ],
      ),
    );
  }

  Widget _buildLogoutRow() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: _logout,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.red50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.logout_rounded,
                    size: 22, color: AppTheme.red400),
              ),
              const SizedBox(width: 12),
              Text(
                'Se déconnecter',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.red500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
