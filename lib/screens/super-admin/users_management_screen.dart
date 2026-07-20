// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/pc_components.dart';

class UsersManagementScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const UsersManagementScreen({super.key, this.embedded = false});

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
            PcButton(
              'Annuler',
              variant: PcButtonVariant.ghost,
              size: PcButtonSize.sm,
              onPressed: _isProcessing ? null : () => Navigator.pop(dialogContext),
            ),
            PcButton(
              isEditing ? 'Modifier' : 'Créer',
              size: PcButtonSize.sm,
              loading: _isProcessing,
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
          PcButton(
            'Annuler',
            variant: PcButtonVariant.ghost,
            size: PcButtonSize.sm,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          PcButton(
            'Supprimer',
            variant: PcButtonVariant.danger,
            size: PcButtonSize.sm,
            onPressed: () => Navigator.pop(dialogContext, true),
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

  // Correspondance rôle -> ton du design system.
  PcTone _roleTone(UserRole role) => switch (role) {
        UserRole.client => PcTone.green,
        UserRole.driver => PcTone.primary,
        UserRole.admin => PcTone.amber,
        UserRole.superAdmin => PcTone.red,
      };

  // Correspondance statut -> ton du design system.
  PcTone _statusTone(UserStatus status) => switch (status) {
        UserStatus.active => PcTone.green,
        UserStatus.suspended => PcTone.amber,
        UserStatus.deleted => PcTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final total = _users.length;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: widget.embedded ? null : const AppBottomNav(),
      appBar: AppBar(
        title: Text(
          'Utilisateurs${total > 0 ? ' · $total' : ''}',
          style: AppFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Center(
              child: PcIconButton(
                Icons.refresh_rounded,
                variant: PcIconButtonVariant.soft,
                size: PcButtonSize.sm,
                tooltip: 'Rafraîchir',
                onPressed: _loadUsers,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: PcFab(
        icon: Icons.person_add_alt_1_rounded,
        label: 'Nouvel utilisateur',
        onPressed: _openCreateDialog,
      ),
      body: Column(
        children: [
          // Barre de recherche et filtres
          Container(
            color: AppTheme.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un utilisateur...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppTheme.slate50,
                  ),
                  style: AppFonts.manrope(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
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
                      ...UserRole.values.map((role) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: role.label,
                          selected: _selectedRole == role,
                          tone: _roleTone(role),
                          onSelected: () {
                            setState(() {
                              _selectedRole = _selectedRole == role ? null : role;
                              _selectedStatus = null;
                              _applyFilters();
                            });
                          },
                        ),
                      )),
                      ...UserStatus.values.map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: status.label,
                          selected: _selectedStatus == status,
                          tone: _statusTone(status),
                          onSelected: () {
                            setState(() {
                              _selectedStatus = _selectedStatus == status ? null : status;
                              _selectedRole = null;
                              _applyFilters();
                            });
                          },
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const PcDivider(),

          // Liste des utilisateurs
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? PcEmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'Aucun utilisateur',
                        message: 'Aucun utilisateur ne correspond à votre recherche.',
                        action: PcButton(
                          'Ajouter un utilisateur',
                          icon: Icons.person_add_alt_1_rounded,
                          size: PcButtonSize.sm,
                          onPressed: _openCreateDialog,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PcCard(
                              padding: EdgeInsets.zero,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  childrenPadding: EdgeInsets.zero,
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  leading: PcAvatar(user.fullName, size: 44),
                                  title: Text(
                                    user.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.email.isNotEmpty ? user.email : user.phone,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppFonts.manrope(
                                            fontSize: 12,
                                            color: AppTheme.slate500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            PcBadge(user.role.label,
                                                tone: _roleTone(user.role)),
                                            PcBadge(user.status.label,
                                                tone: _statusTone(user.status)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Parité sécurité avec le web : on masque les
                                  // actions destructives (et la modification) pour
                                  // les comptes super_admin.
                                  trailing: user.role == UserRole.superAdmin
                                      ? null
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PcIconButton(
                                              Icons.edit_outlined,
                                              variant: PcIconButtonVariant.soft,
                                              size: PcButtonSize.sm,
                                              tooltip: 'Modifier',
                                              onPressed: () => _openEditDialog(user),
                                            ),
                                            const SizedBox(width: 6),
                                            PcIconButton(
                                              user.status == UserStatus.active
                                                  ? Icons.block_rounded
                                                  : Icons.check_circle_outline_rounded,
                                              variant: user.status == UserStatus.active
                                                  ? PcIconButtonVariant.danger
                                                  : PcIconButtonVariant.soft,
                                              size: PcButtonSize.sm,
                                              tooltip: user.status == UserStatus.active
                                                  ? 'Suspendre'
                                                  : 'Réactiver',
                                              onPressed: () => _toggleUserStatus(user),
                                            ),
                                            const SizedBox(width: 6),
                                            PcIconButton(
                                              Icons.delete_outline_rounded,
                                              variant: PcIconButtonVariant.danger,
                                              size: PcButtonSize.sm,
                                              tooltip: 'Supprimer',
                                              onPressed: () => _deleteUser(user),
                                            ),
                                          ],
                                        ),
                                  children: [
                                    const PcDivider(),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          _InfoRow(label: 'Téléphone', value: user.phone, mono: true),
                                          if (user.address != null && user.address!.isNotEmpty)
                                            _InfoRow(label: 'Adresse', value: user.address!),
                                          if (user.city != null && user.city!.isNotEmpty)
                                            _InfoRow(label: 'Ville', value: user.city!),
                                          if (user.region != null && user.region!.isNotEmpty)
                                            _InfoRow(label: 'Région', value: user.region!),
                                          if (user.garageId != null && user.garageId!.isNotEmpty)
                                            _InfoRow(label: 'ID zone', value: user.garageId!, mono: true),
                                          if (user.vehiclePlate != null && user.vehiclePlate!.isNotEmpty)
                                            _InfoRow(label: 'Plaque', value: user.vehiclePlate!, mono: true),
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
                                                child: PcButton(
                                                  'Réinitialiser PIN',
                                                  variant: PcButtonVariant.secondary,
                                                  size: PcButtonSize.sm,
                                                  icon: Icons.lock_reset_rounded,
                                                  block: true,
                                                  onPressed: () => _resetUserPin(user),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: PcButton(
                                                  'Historique',
                                                  variant: PcButtonVariant.ghost,
                                                  size: PcButtonSize.sm,
                                                  icon: Icons.history_rounded,
                                                  block: true,
                                                  onPressed: () {},
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
  final PcTone tone;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.tone = PcTone.primary,
  });

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      PcTone.primary => AppTheme.primary,
      PcTone.green => AppTheme.green600,
      PcTone.amber => AppTheme.amber600,
      PcTone.red => AppTheme.red400,
      PcTone.neutral => AppTheme.slate600,
    };
    return Material(
      color: selected ? accent : AppTheme.cardColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? accent : AppTheme.slate200,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppFonts.plusJakartaSans(
              color: selected ? Colors.white : AppTheme.slate600,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({required this.label, required this.value, this.mono = false});

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
              style: AppFonts.manrope(
                color: AppTheme.slate500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w600)
                  : AppFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}