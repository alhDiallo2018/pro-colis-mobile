// mobile/lib/screens/profile/profile_screen.dart

// ignore_for_file: unused_element, avoid_print, use_build_context_synchronously

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_text_field.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // ==================== CONSTANTES DE COULEUR (THÈME BLEU/BLANC) ====================
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color backgroundColor = Color(0xFFF5F8FA);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color errorColor = Color(0xFFC62828);

  late User _user;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  
  // API base URL
  static const String baseUrl = 'https://procolis-backend.onrender.com';
  
  // Contrôleurs
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

  // ==================== GESTION PHOTO ====================
  
  String _getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (imagePath.startsWith('http')) return imagePath;
    return '$baseUrl$imagePath';
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
      final response = await apiService.uploadAndUpdateProfilePhoto(_profileImage!);
      
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
      backgroundColor: cardColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Changer la photo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textPrimary,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.photo_library, color: primaryBlue),
              title: const Text('Choisir dans la galerie'),
              onTap: () { Navigator.pop(context); _pickImage(); },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: primaryBlue),
              title: const Text('Prendre une photo'),
              onTap: () { Navigator.pop(context); _takePhoto(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== MISE À JOUR ====================
  
  Future<void> _updateProfile() async {
    if (_fullNameController.text.trim().isEmpty) {
      _showSnackBar('Le nom complet est requis', errorColor);
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('L\'email est requis', errorColor);
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Le téléphone est requis', errorColor);
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
          data['vehicleYear'] = int.tryParse(_vehicleYearController.text.trim());
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
          setState(() => _isEditing = false);
          _showSnackBar('Profil mis à jour', successColor);
          await ref.read(authProvider.notifier).refreshUser();
          await _initializeData();
        } else {
          _showSnackBar(response['message'] ?? 'Erreur', errorColor);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Erreur: $e', errorColor);
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
    
    final result = await ref.read(authProvider.notifier).updatePin(
      currentPin: _currentPinController.text,
      newPin: _newPinController.text,
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

  // ==================== FONCTIONS COULEUR ====================
  
  Color _getColorFromString(String colorName) {
    final lowerColor = colorName.toLowerCase();
    switch (lowerColor) {
      case 'blanc':
        return Colors.white;
      case 'noir':
        return Colors.black;
      case 'gris':
        return Colors.grey;
      case 'bleu':
        return primaryBlue;
      case 'rouge':
        return Colors.red;
      case 'vert':
        return Colors.green;
      case 'jaune':
        return Colors.yellow;
      case 'beige':
        return Colors.brown.shade50;
      case 'marron':
        return Colors.brown;
      case 'orange':
        return Colors.orange;
      case 'violet':
        return Colors.purple;
      case 'rose':
        return Colors.pink;
      case 'bordeaux':
        return Colors.deepPurple;
      case 'kaki':
        return Colors.lime.shade700;
      case 'argenté':
        return Colors.grey.shade400;
      case 'doré':
        return Colors.amber.shade700;
      case 'bleu ciel':
        return Colors.lightBlue;
      case 'bleu marine':
        return darkBlue;
      case 'gris foncé':
        return Colors.grey.shade800;
      case 'gris clair':
        return Colors.grey.shade300;
      case 'blanc cassé':
        return Colors.white70;
      default:
        return Colors.grey;
    }
  }

  Widget _buildColorDisplay(String? colorName) {
    if (colorName == null || colorName.isEmpty) {
      return const Text('Non renseigné');
    }
    
    final color = _getColorFromString(colorName);
    final isLightColor = color == Colors.white || color == Colors.yellow || color == Colors.white70;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.grey.shade400, width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            colorName,
            style: TextStyle(
              color: isLightColor ? Colors.black : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUILD ====================
  
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    if (!_isInitialized || authState.user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
          ),
        ),
      );
    }
    
    _user = authState.user!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Modifier le profil' : 'Mon profil',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: textPrimary,
          ),
        ),
        backgroundColor: cardColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: primaryBlue),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isLoading ? null : _updateProfile,
              child: Text(
                'Enregistrer',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading || _isUploadingPhoto
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfilePhotoSection(),
                  const SizedBox(height: 24),
                  
                  _buildSectionCard(
                    title: 'Informations personnelles',
                    icon: Icons.person,
                    color: primaryBlue,
                    child: _buildPersonalInfoSection(),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildSectionCard(
                    title: 'Sécurité',
                    icon: Icons.lock,
                    color: warningColor,
                    child: _buildPinSection(),
                  ),
                  
                  if (_user.role == UserRole.driver) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Véhicule',
                      icon: Icons.directions_car,
                      color: Colors.purple,
                      child: _buildVehicleSection(),
                    ),
                  ],
                  
                  if (_user.role == UserRole.admin) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: 'Point de service',
                      icon: Icons.business,
                      color: Colors.teal,
                      child: _buildGarageSection(),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Statistiques',
                    icon: Icons.analytics,
                    color: successColor,
                    child: _buildStatsSection(),
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      icon: const Icon(Icons.logout, color: errorColor, size: 18),
                      label: const Text('Se déconnecter', style: TextStyle(color: errorColor)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 65,
                  backgroundColor: lightBlue,
                  child: _getProfileImageWidget(),
                ),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardColor, width: 3),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: _showImageSourceDialog,
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
            ],
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton.icon(
                onPressed: _showImageSourceDialog,
                icon: Icon(Icons.camera_alt, size: 16, color: primaryBlue),
                label: Text(
                  'Changer la photo',
                  style: TextStyle(color: primaryBlue),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getProfileImageWidget() {
    if (_profileImage != null) {
      if (kIsWeb) {
        return ClipOval(
          child: Image.network(
            _profileImage!.path,
            width: 130,
            height: 130,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
          ),
        );
      } else {
        return ClipOval(
          child: Image.file(
            File(_profileImage!.path),
            width: 130,
            height: 130,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
          ),
        );
      }
    }
    
    if (_user.profilePhoto != null && _user.profilePhoto!.isNotEmpty) {
      final fullImageUrl = _getFullImageUrl(_user.profilePhoto);
      return ClipOval(
        child: Image.network(
          fullImageUrl,
          width: 130,
          height: 130,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Erreur chargement image: $error');
            return _buildInitialsAvatar();
          },
        ),
      );
    }
    
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    return Text(
      _user.initials,
      style: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w500,
        color: primaryBlue,
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      children: [
        _buildModernField(
          icon: Icons.person,
          label: 'Nom complet',
          value: _user.fullName,
          isEditing: _isEditing,
          controller: _fullNameController,
        ),
        const SizedBox(height: 12),
        _buildModernField(
          icon: Icons.email,
          label: 'Email',
          value: _user.email,
          isEditing: _isEditing,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildModernField(
          icon: Icons.phone,
          label: 'Téléphone',
          value: _user.phone,
          isEditing: _isEditing,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _buildModernField(
          icon: Icons.location_on,
          label: 'Adresse',
          value: _user.address ?? 'Non renseigné',
          isEditing: _isEditing,
          controller: _addressController,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernField(
                icon: Icons.location_city,
                label: 'Ville',
                value: _user.city ?? 'Non renseigné',
                isEditing: _isEditing,
                controller: _cityController,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernField(
                icon: Icons.map,
                label: 'Région',
                value: _user.region ?? 'Non renseigné',
                isEditing: _isEditing,
                controller: _regionController,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernField({
    required IconData icon,
    required String label,
    required String value,
    required bool isEditing,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    if (isEditing) {
      return CustomTextField(
        controller: controller,
        label: label,
        prefixIcon: icon,
        keyboardType: keyboardType ?? TextInputType.text,
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSection() {
    return Column(
      children: [
        _buildModernField(
          icon: Icons.local_taxi,
          label: 'Plaque d\'immatriculation',
          value: _user.vehiclePlate ?? 'Non renseigné',
          isEditing: _isEditing,
          controller: _vehiclePlateController,
        ),
        const SizedBox(height: 12),
        _buildModernField(
          icon: Icons.directions_car,
          label: 'Modèle',
          value: _user.vehicleModel ?? 'Non renseigné',
          isEditing: _isEditing,
          controller: _vehicleModelController,
        ),
        const SizedBox(height: 12),
        if (_isEditing)
          CustomTextField(
            controller: _vehicleColorController,
            label: 'Couleur',
            prefixIcon: Icons.color_lens,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.color_lens, size: 18, color: primaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Couleur',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      _buildColorDisplay(_user.vehicleColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _buildModernField(
          icon: Icons.calendar_today,
          label: 'Année',
          value: _user.vehicleYear?.toString() ?? 'Non renseigné',
          isEditing: _isEditing,
          controller: _vehicleYearController,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildGarageSection() {
    final garageName = _user.garageName ?? 'Chargement...';
    final garageId = _user.garageId ?? 'Non assigné';
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.business, size: 22, color: primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Point de service',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      garageName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: $garageId',
                      style: TextStyle(fontSize: 11, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pin, size: 22, color: primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Code PIN',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _showPinChangeForm ? 'Modification en cours...' : '●●●●●●',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _showPinChangeForm ? Icons.close : Icons.edit,
                  color: primaryBlue,
                ),
                onPressed: () => setState(() => _showPinChangeForm = !_showPinChangeForm),
              ),
            ],
          ),
        ),
        if (_showPinChangeForm) ...[
          const SizedBox(height: 12),
          CustomTextField(
            controller: _currentPinController,
            label: 'PIN actuel',
            prefixIcon: Icons.lock,
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _newPinController,
            label: 'Nouveau PIN (6 chiffres)',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: _confirmPinController,
            label: 'Confirmer le PIN',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _updatePin,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text('Mettre à jour le PIN'),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsSection() {
    return Column(
      children: [
        _buildStatsRow('Inscription', _formatDate(_user.createdAt)),
        const Divider(),
        _buildStatsRow('Dernière connexion', _formatDate(_user.lastLogin)),
        const Divider(),
        _buildStatsRow('Rôle', _user.role.label),
        const Divider(),
        _buildStatsRow('Statut', _user.isActive ? 'Actif' : 'Inactif'),
        if (_user.isDriver) ...[
          const Divider(),
          _buildStatsRow('Statut chauffeur', _user.driverStatus?.label ?? 'En attente'),
        ],
      ],
    );
  }

  Widget _buildStatsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Jamais';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}