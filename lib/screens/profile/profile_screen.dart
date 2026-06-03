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
      if (mounted) _showSnackBar('Erreur: $e', Colors.red);
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
      if (mounted) _showSnackBar('Erreur: $e', Colors.red);
    }
  }

  Future<void> _uploadProfilePhoto() async {
    if (_profileImage == null) return;
    
    setState(() => _isUploadingPhoto = true);
    
    try {
      final apiService = ApiService();
      final response = await apiService.uploadAndUpdateProfilePhoto(_profileImage!);
      
      if (mounted && response['success'] == true) {
        _showSnackBar('Photo de profil mise à jour', Colors.green);
        await ref.read(authProvider.notifier).refreshUser();
        await _initializeData();
      } else if (mounted) {
        _showSnackBar(response['message'] ?? 'Erreur', Colors.red);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF0B6E3A)),
              title: const Text('Choisir dans la galerie'),
              onTap: () { Navigator.pop(context); _pickImage(); },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0B6E3A)),
              title: const Text('Prendre une photo'),
              onTap: () { Navigator.pop(context); _takePhoto(); },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MISE À JOUR ====================
  
  Future<void> _updateProfile() async {
    if (_fullNameController.text.trim().isEmpty) {
      _showSnackBar('Le nom complet est requis', Colors.red);
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('L\'email est requis', Colors.red);
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Le téléphone est requis', Colors.red);
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
          _showSnackBar('Profil mis à jour', Colors.green);
          await ref.read(authProvider.notifier).refreshUser();
          await _initializeData();
        } else {
          _showSnackBar(response['message'] ?? 'Erreur', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Erreur: $e', Colors.red);
      }
    }
  }

  Future<void> _updatePin() async {
    if (_newPinController.text != _confirmPinController.text) {
      _showSnackBar('Les PIN ne correspondent pas', Colors.red);
      return;
    }
    if (_newPinController.text.length != 6) {
      _showSnackBar('Le PIN doit contenir 6 chiffres', Colors.red);
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
        _showSnackBar('PIN mis à jour', Colors.green);
      } else {
        _showSnackBar(result['message'], Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
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
        return Colors.blue;
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
        return Colors.blue.shade900;
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
            width: 16,
            height: 16,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    _user = authState.user!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le profil' : 'Mon profil'),
        backgroundColor: const Color(0xFF0B6E3A),
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isLoading ? null : _updateProfile,
              child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading || _isUploadingPhoto
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfilePhotoSection(),
                  const SizedBox(height: 24),
                  
                  const _SectionHeader(title: 'Informations personnelles', icon: Icons.person),
                  const SizedBox(height: 12),
                  _buildPersonalInfoSection(),
                  
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'Sécurité', icon: Icons.lock),
                  const SizedBox(height: 12),
                  _buildPinSection(),
                  
                  if (_user.role == UserRole.driver) ...[
                    const SizedBox(height: 24),
                    const _SectionHeader(title: 'Véhicule', icon: Icons.directions_car),
                    const SizedBox(height: 12),
                    _buildVehicleSection(),
                  ],
                  
                  if (_user.role == UserRole.admin) ...[
                    const SizedBox(height: 24),
                    const _SectionHeader(title: 'Point de service', icon: Icons.business),
                    const SizedBox(height: 12),
                    _buildGarageSection(),
                  ],
                  
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'Statistiques', icon: Icons.analytics),
                  const SizedBox(height: 12),
                  _buildStatsSection(),
                  
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
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
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
              CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFF0B6E3A).withAlpha(25),
                child: _getProfileImageWidget(),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B6E3A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: _showImageSourceDialog,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
            ],
          ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: _showImageSourceDialog,
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text('Changer la photo'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getProfileImageWidget() {
    // Photo temporaire sélectionnée
    if (_profileImage != null) {
      if (kIsWeb) {
        return ClipOval(
          child: Image.network(
            _profileImage!.path,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
          ),
        );
      } else {
        return ClipOval(
          child: Image.file(
            File(_profileImage!.path),
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
          ),
        );
      }
    }
    
    // Photo existante
    if (_user.profilePhoto != null && _user.profilePhoto!.isNotEmpty) {
      final fullImageUrl = _getFullImageUrl(_user.profilePhoto);
      return ClipOval(
        child: Image.network(
          fullImageUrl,
          width: 120,
          height: 120,
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
      style: const TextStyle(fontSize: 50, color: Color(0xFF0B6E3A)),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      children: [
        _EditableField(
          label: 'Nom complet',
          value: _user.fullName,
          isEditing: _isEditing,
          controller: _fullNameController,
          icon: Icons.person,
        ),
        const SizedBox(height: 12),
        _EditableField(
          label: 'Email',
          value: _user.email,
          isEditing: _isEditing,
          controller: _emailController,
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _EditableField(
          label: 'Téléphone',
          value: _user.phone,
          isEditing: _isEditing,
          controller: _phoneController,
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _EditableField(
          label: 'Adresse',
          value: _user.address ?? 'Non renseigné',
          isEditing: _isEditing,
          controller: _addressController,
          icon: Icons.location_on,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _EditableField(
                label: 'Ville',
                value: _user.city ?? 'Non renseigné',
                isEditing: _isEditing,
                controller: _cityController,
                icon: Icons.location_city,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EditableField(
                label: 'Région',
                value: _user.region ?? 'Non renseigné',
                isEditing: _isEditing,
                controller: _regionController,
                icon: Icons.map,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVehicleSection() {
    return Column(
      children: [
        // Plaque
        _EditableField(
          label: 'Plaque',
          value: _user.vehiclePlate ?? 'Non renseigné',
          isEditing: _isEditing,
          controller: _vehiclePlateController,
          icon: Icons.local_taxi,
        ),
        const SizedBox(height: 12),
        
        // Modèle
        _EditableField(
          label: 'Modèle',
          value: _user.vehicleModel ?? 'Non renseigné',
          isEditing: _isEditing,
          controller: _vehicleModelController,
          icon: Icons.directions_car,
        ),
        const SizedBox(height: 12),
        
        // Couleur - Mode édition vs visualisation
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
                Icon(Icons.color_lens, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Couleur', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      _buildColorDisplay(_user.vehicleColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        
        // Année
        _EditableField(
          label: 'Année',
          value: _user.vehicleYear?.toString() ?? 'Non renseigné',
          isEditing: _isEditing,
          controller: _vehicleYearController,
          icon: Icons.calendar_today,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _buildGarageSection() {
    final garageName = _user.garageName ?? 'Chargement...';
    final garageId = _user.garageId ?? 'Non assigné';
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B6E3A).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business, color: Color(0xFF0B6E3A), size: 24),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'ID du point de service', value: garageId),
          ],
        ),
      ),
    );
  }

  Widget _buildPinSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withAlpha(50)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0B6E3A).withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.pin, color: Color(0xFF0B6E3A)),
        ),
        title: const Text('Code PIN'),
        subtitle: Text(_showPinChangeForm ? 'Modification...' : '●●●●●●'),
        trailing: IconButton(
          icon: Icon(_showPinChangeForm ? Icons.close : Icons.edit),
          onPressed: () => setState(() => _showPinChangeForm = !_showPinChangeForm),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(label: 'Inscription', value: _formatDate(_user.createdAt)),
            const Divider(),
            _InfoRow(label: 'Dernière connexion', value: _formatDate(_user.lastLogin)),
            const Divider(),
            _InfoRow(label: 'Rôle', value: _user.role.label),
            const Divider(),
            _InfoRow(label: 'Statut', value: _user.isActive ? 'Actif' : 'Inactif'),
            if (_user.isDriver) ...[
              const Divider(),
              _InfoRow(label: 'Statut chauffeur', value: _user.driverStatus?.label ?? 'En attente'),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Jamais';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ==================== COMPOSANTS ====================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: const Color(0xFF0B6E3A), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: const Color(0xFF0B6E3A)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final String value;
  final bool isEditing;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  
  const _EditableField({
    required this.label,
    required this.value,
    required this.isEditing,
    required this.controller,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
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
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}