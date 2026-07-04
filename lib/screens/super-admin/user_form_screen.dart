// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart'; // Ajoutez cette ligne
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class UserFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final User? user;
  
  const UserFormScreen({
    super.key,
    required this.isEditing,
    this.user,
  });

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _pinController = TextEditingController();
  
  // Selected values
  UserRole _selectedRole = UserRole.client;
  UserStatus _selectedStatus = UserStatus.active;
  Gender? _selectedGender;
  DriverStatus? _selectedDriverStatus;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.user != null) {
      _populateForm();
    }
  }

  void _populateForm() {
    final user = widget.user!;
    _fullNameController.text = user.fullName;
    _emailController.text = user.email;
    _phoneController.text = user.phone;
    _addressController.text = user.address ?? '';
    _cityController.text = user.city ?? '';
    _regionController.text = user.region ?? '';
    _vehiclePlateController.text = user.vehiclePlate ?? '';
    _vehicleModelController.text = user.vehicleModel ?? '';
    _selectedRole = user.role;
    _selectedStatus = user.status;
    _selectedGender = user.gender;
    _selectedDriverStatus = user.driverStatus;
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
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      bool success;
      if (widget.isEditing) {
        final result = await _apiService.updateUserSuperAdmin(
          userId: widget.user!.id,
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole.value,
          status: _selectedStatus.value,
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          region: _regionController.text.trim(),
          vehiclePlate: _vehiclePlateController.text.trim(),
          vehicleModel: _vehicleModelController.text.trim(),
          driverStatus: _selectedDriverStatus?.value,
        );
        success = result['success'] == true;
      } else {
        final result = await _apiService.createUserSuperAdmin(
          fullName: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole.value,
          status: _selectedStatus.value,
          address: _addressController.text.trim(),
          city: _cityController.text.trim(),
          region: _regionController.text.trim(),
          pin: _pinController.text.isEmpty ? '123456' : _pinController.text,
          gender: _selectedGender?.value,
          vehiclePlate: _vehiclePlateController.text.trim(),
          vehicleModel: _vehicleModelController.text.trim(),
          driverStatus: _selectedDriverStatus?.value,
        );
        success = result['success'] == true;
      }
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing ? 'Utilisateur modifié avec succès' : 'Utilisateur créé avec succès',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Changé
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.cardColor, // Changé
        foregroundColor: AppTheme.textPrimary,
        elevation: 0, // Changé
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Section informations personnelles
              _buildSectionTitle('Informations personnelles'),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _fullNameController,
                label: 'Nom complet',
                prefixIcon: Icons.person,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || !v.contains('@') ? 'Email valide requis' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _phoneController,
                label: 'Téléphone',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              _buildSectionTitle('Adresse'),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _addressController,
                label: 'Adresse',
                prefixIcon: Icons.location_on,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _cityController,
                      label: 'Ville',
                      prefixIcon: Icons.location_city,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _regionController,
                      label: 'Région',
                      prefixIcon: Icons.map,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionTitle('Paramètres du compte'),
              const SizedBox(height: 12),
              _buildDropdownField(
                value: _selectedRole,
                label: 'Rôle',
                icon: Icons.admin_panel_settings,
                items: UserRole.values.map((role) => DropdownMenuItem(
                  value: role,
                  child: Row(
                    children: [
                      Icon(role.icon, size: 18, color: role.color),
                      const SizedBox(width: 8),
                      Text(role.label),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => setState(() => _selectedRole = value!),
              ),
              const SizedBox(height: 12),
              _buildDropdownField(
                value: _selectedStatus,
                label: 'Statut',
                icon: Icons.badge,
                items: UserStatus.values.map((status) => DropdownMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: status.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(status.label),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
              const SizedBox(height: 12),
              _buildDropdownField(
                value: _selectedGender,
                label: 'Genre',
                icon: Icons.person_outline,
                items: Gender.values.map((gender) => DropdownMenuItem(
                  value: gender,
                  child: Row(
                    children: [
                      Icon(gender.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(gender.label),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              
              // Section chauffeur
              if (_selectedRole == UserRole.driver) ...[
                const SizedBox(height: 16),
                _buildSectionTitle('Informations du véhicule'),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _vehiclePlateController,
                  label: 'Plaque d\'immatriculation',
                  prefixIcon: Icons.local_taxi,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _vehicleModelController,
                  label: 'Modèle du véhicule',
                  prefixIcon: Icons.directions_car,
                ),
                const SizedBox(height: 12),
                _buildDropdownField(
                  value: _selectedDriverStatus,
                  label: 'Statut chauffeur',
                  icon: Icons.delivery_dining,
                  items: DriverStatus.values.map((status) => DropdownMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: status.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(status.label),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedDriverStatus = value),
                ),
              ],
              
              // Section PIN
              if (!widget.isEditing) ...[
                const SizedBox(height: 16),
                _buildSectionTitle('Sécurité'),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _pinController,
                  label: 'Code PIN (6 chiffres)',
                  prefixIcon: Icons.pin,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  helperText: 'Laisser vide pour utiliser le PIN par défaut (123456)',
                ),
              ],
              
              const SizedBox(height: 24),
              CustomButton(
                text: widget.isEditing ? 'Modifier' : 'Créer',
                onPressed: _save,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Widget helper pour les titres de section
  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Widget helper pour les dropdowns avec thème cohérent
  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryBlue.withOpacity( 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryBlue.withOpacity( 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.primaryBlue,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: AppTheme.cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
      dropdownColor: AppTheme.cardColor,
      style: const TextStyle(color: AppTheme.textPrimary),
      icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue),
      borderRadius: BorderRadius.circular(12),
    );
  }
}