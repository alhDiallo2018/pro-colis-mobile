// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_text_field.dart';

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen> {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  String _searchQuery = '';
  UserRole? _selectedRole;
  UserStatus? _selectedStatus;
  
  // Dialog controllers
  User? _editingUser;
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _pinController = TextEditingController();
  UserRole _selectedRoleForm = UserRole.client;
  UserStatus _selectedStatusForm = UserStatus.active;
  Gender? _selectedGender;
  DriverStatus? _selectedDriverStatus;

  @override
  void initState() {
    super.initState();
    _loadUsers();
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

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      _users = await _apiService.getAllUsersSuperAdmin();
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    var filtered = List<User>.from(_users);
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((u) =>
        u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        u.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        u.phone.contains(_searchQuery)
      ).toList();
    }
    
    if (_selectedRole != null) {
      filtered = filtered.where((u) => u.role == _selectedRole).toList();
    }
    
    if (_selectedStatus != null) {
      filtered = filtered.where((u) => u.status == _selectedStatus).toList();
    }
    
    setState(() => _filteredUsers = filtered);
  }

  void _openCreateDialog() {
    _editingUser = null;
    _fullNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _cityController.clear();
    _regionController.clear();
    _vehiclePlateController.clear();
    _vehicleModelController.clear();
    _pinController.clear();
    _selectedRoleForm = UserRole.client;
    _selectedStatusForm = UserStatus.active;
    _selectedGender = null;
    _selectedDriverStatus = null;
    _showUserDialog(isEditing: false);
  }

  void _openEditDialog(User user) {
    _editingUser = user;
    _fullNameController.text = user.fullName;
    _emailController.text = user.email;
    _phoneController.text = user.phone;
    _addressController.text = user.address ?? '';
    _cityController.text = user.city ?? '';
    _regionController.text = user.region ?? '';
    _vehiclePlateController.text = user.vehiclePlate ?? '';
    _vehicleModelController.text = user.vehicleModel ?? '';
    _selectedRoleForm = user.role;
    _selectedStatusForm = user.status;
    _selectedGender = user.gender;
    _selectedDriverStatus = user.driverStatus;
    _showUserDialog(isEditing: true);
  }

  void _showUserDialog({required bool isEditing}) {
    showDialog(
      context: context,
      barrierDismissible: !_isProcessing,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isEditing ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          backgroundColor: AppTheme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogSectionTitle('Informations personnelles'),
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
                  _buildDialogSectionTitle('Adresse'),
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
                  _buildDialogSectionTitle('Paramètres du compte'),
                  const SizedBox(height: 12),
                  _buildDialogDropdown(
                    value: _selectedRoleForm,
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
                    onChanged: (value) => setDialogState(() => _selectedRoleForm = value!),
                  ),
                  const SizedBox(height: 12),
                  _buildDialogDropdown(
                    value: _selectedStatusForm,
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
                    onChanged: (value) => setDialogState(() => _selectedStatusForm = value!),
                  ),
                  const SizedBox(height: 12),
                  _buildDialogDropdown(
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
                    onChanged: (value) => setDialogState(() => _selectedGender = value),
                  ),
                  if (_selectedRoleForm == UserRole.driver) ...[
                    const SizedBox(height: 16),
                    _buildDialogSectionTitle('Informations du véhicule'),
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
                    _buildDialogDropdown(
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
                      onChanged: (value) => setDialogState(() => _selectedDriverStatus = value),
                    ),
                  ],
                  if (!isEditing) ...[
                    const SizedBox(height: 16),
                    _buildDialogSectionTitle('Sécurité'),
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isProcessing ? null : () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
              ),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: _isProcessing ? null : () async {
                if (_formKey.currentState!.validate()) {
                  setDialogState(() => _isProcessing = true);
                  if (isEditing) {
                    await _updateUser();
                  } else {
                    await _createUser();
                  }
                  setDialogState(() => _isProcessing = false);
                  if (mounted && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isEditing ? 'Modifier' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }

  // Widget helper pour les titres de section dans le dialog
  Widget _buildDialogSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Widget helper pour les dropdowns dans le dialog
  Widget _buildDialogDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
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
      dropdownColor: AppTheme.cardColor,
      style: const TextStyle(color: AppTheme.textPrimary),
      icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue),
      borderRadius: BorderRadius.circular(12),
    );
  }

  Future<void> _createUser() async {
    final pin = _pinController.text.isEmpty ? '123456' : _pinController.text;
    final result = await _apiService.createUserSuperAdmin(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _selectedRoleForm.value,
      status: _selectedStatusForm.value,
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      region: _regionController.text.trim(),
      pin: pin,
      gender: _selectedGender?.value,
      vehiclePlate: _vehiclePlateController.text.trim(),
      vehicleModel: _vehicleModelController.text.trim(),
      driverStatus: _selectedDriverStatus?.value,
    );
    
    if (result['success'] == true && mounted) {
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Utilisateur créé avec succès', style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur lors de la création', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _updateUser() async {
    if (_editingUser == null) return;
    
    final result = await _apiService.updateUserSuperAdmin(
      userId: _editingUser!.id,
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _selectedRoleForm.value,
      status: _selectedStatusForm.value,
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      region: _regionController.text.trim(),
      vehiclePlate: _vehiclePlateController.text.trim(),
      vehicleModel: _vehicleModelController.text.trim(),
      driverStatus: _selectedDriverStatus?.value,
    );
    
    if (result['success'] == true && mounted) {
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Utilisateur modifié avec succès', style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur lors de la modification', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _toggleUserStatus(User user) async {
    final newStatus = user.status == UserStatus.active ? UserStatus.suspended : UserStatus.active;
    final result = await _apiService.updateUserStatusSuperAdmin(user.id, newStatus.value);
    
    if (result['success'] == true && mounted) {
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Utilisateur ${newStatus.label}', style: const TextStyle(color: Colors.white)),
            backgroundColor: newStatus == UserStatus.active ? AppTheme.successColor : AppTheme.warningColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Confirmation',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer ${user.fullName} ?',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirm == true && mounted) {
      final result = await _apiService.deleteUserSuperAdmin(user.id);
      if (result['success'] == true && mounted) {
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Utilisateur supprimé', style: TextStyle(color: Colors.white)),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Erreur lors de la suppression', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _resetUserPin(User user) async {
    final result = await _apiService.resetUserPinAdmin(user.id);
    if (result['success'] == true && mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PIN réinitialisé à 123456', style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur lors de la réinitialisation', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Gestion des utilisateurs',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppTheme.primaryBlue),
            onPressed: _openCreateDialog,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.primaryBlue),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres
          Container(
            color: AppTheme.cardColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un utilisateur...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity( 0.7)),
                    prefixIcon: Icon(Icons.search, color: AppTheme.primaryBlue),
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
                    fillColor: AppTheme.backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tous',
                        selected: _selectedRole == null && _selectedStatus == null,
                        onSelected: () {
                          setState(() {
                            _selectedRole = null;
                            _selectedStatus = null;
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...UserRole.values.map((role) => _FilterChip(
                        label: role.label,
                        selected: _selectedRole == role,
                        color: role.color,
                        onSelected: () {
                          setState(() {
                            _selectedRole = _selectedRole == role ? null : role;
                            _selectedStatus = null;
                            _applyFilters();
                          });
                        },
                      )),
                      const SizedBox(width: 8),
                      ...UserStatus.values.map((status) => _FilterChip(
                        label: status.label,
                        selected: _selectedStatus == status,
                        color: status.color,
                        onSelected: () {
                          setState(() {
                            _selectedStatus = _selectedStatus == status ? null : status;
                            _selectedRole = null;
                            _applyFilters();
                          });
                        },
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Liste des utilisateurs
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: AppTheme.textSecondary.withOpacity( 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun utilisateur trouvé',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _openCreateDialog,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryBlue,
                              ),
                              child: const Text('Ajouter un utilisateur'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: AppTheme.cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: AppTheme.primaryBlue.withOpacity( 0.1),
                                width: 1,
                              ),
                            ),
                            elevation: 2,
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: user.role.color.withOpacity( 0.15),
                                child: Icon(user.role.icon, color: user.role.color, size: 20),
                              ),
                              title: Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: user.status.color,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        user.status.label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: user.status.color,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: user.role.color.withOpacity( 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          user.role.label,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: user.role.color,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: AppTheme.primaryBlue,
                                      size: 20,
                                    ),
                                    onPressed: () => _openEditDialog(user),
                                    splashRadius: 20,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      user.status == UserStatus.active ? Icons.block : Icons.check_circle,
                                      color: user.status == UserStatus.active ? AppTheme.warningColor : AppTheme.successColor,
                                      size: 20,
                                    ),
                                    onPressed: () => _toggleUserStatus(user),
                                    splashRadius: 20,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: AppTheme.errorColor,
                                      size: 20,
                                    ),
                                    onPressed: () => _deleteUser(user),
                                    splashRadius: 20,
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      _InfoRow(label: 'Téléphone', value: user.phone),
                                      if (user.address != null && user.address!.isNotEmpty) 
                                        _InfoRow(label: 'Adresse', value: user.address!),
                                      if (user.city != null && user.city!.isNotEmpty) 
                                        _InfoRow(label: 'Ville', value: user.city!),
                                      if (user.region != null && user.region!.isNotEmpty) 
                                        _InfoRow(label: 'Région', value: user.region!),
                                      if (user.garageId != null && user.garageId!.isNotEmpty) 
                                        _InfoRow(label: 'Garage ID', value: user.garageId!),
                                      if (user.vehiclePlate != null && user.vehiclePlate!.isNotEmpty) 
                                        _InfoRow(label: 'Plaque', value: user.vehiclePlate!),
                                      if (user.vehicleModel != null && user.vehicleModel!.isNotEmpty) 
                                        _InfoRow(label: 'Modèle', value: user.vehicleModel!),
                                      if (user.driverStatus != null) 
                                        _InfoRow(label: 'Statut chauffeur', value: user.driverStatus!.label),
                                      _InfoRow(label: 'Email vérifié', value: user.isEmailVerified ? 'Oui' : 'Non'),
                                      _InfoRow(label: 'Téléphone vérifié', value: user.isPhoneVerified ? 'Oui' : 'Non'),
                                      _InfoRow(label: 'Inscription', value: _formatDate(user.createdAt)),
                                      if (user.lastLogin != null) 
                                        _InfoRow(label: 'Dernière connexion', value: _formatDate(user.lastLogin!)),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _resetUserPin(user),
                                              icon: Icon(Icons.refresh, size: 18, color: AppTheme.primaryBlue),
                                              label: Text(
                                                'Réinitialiser PIN',
                                                style: TextStyle(color: AppTheme.primaryBlue),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: AppTheme.primaryBlue),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () {},
                                              icon: Icon(Icons.history, size: 18, color: AppTheme.textSecondary),
                                              label: Text(
                                                'Historique',
                                                style: TextStyle(color: AppTheme.textSecondary),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: AppTheme.textSecondary.withOpacity( 0.3)),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
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
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppTheme.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: AppTheme.cardColor,
      selectedColor: color ?? AppTheme.primaryBlue,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected 
              ? (color ?? AppTheme.primaryBlue) 
              : AppTheme.textSecondary.withOpacity( 0.2),
          width: 1,
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, 
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}