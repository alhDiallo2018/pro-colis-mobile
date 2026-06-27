// lib/screens/super_admin/garage_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/widgets/app_logo.dart';

import '../../models/garage.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class GarageFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final Garage? garage;
  
  const GarageFormScreen({
    super.key,
    required this.isEditing,
    this.garage,
  });

  @override
  ConsumerState<GarageFormScreen> createState() => _GarageFormScreenState();
}

class _GarageFormScreenState extends ConsumerState<GarageFormScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.garage != null) {
      _populateForm();
    }
  }

  void _populateForm() {
    final garage = widget.garage!;
    _nameController.text = garage.name;
    _cityController.text = garage.city;
    _regionController.text = garage.region;
    _addressController.text = garage.address ?? '';
    _phoneController.text = garage.phone ?? '';
    _latitudeController.text = garage.latitude?.toString() ?? '';
    _longitudeController.text = garage.longitude?.toString() ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      double? latitude;
      if (_latitudeController.text.trim().isNotEmpty) {
        latitude = double.parse(_latitudeController.text.trim());
      }
      
      double? longitude;
      if (_longitudeController.text.trim().isNotEmpty) {
        longitude = double.parse(_longitudeController.text.trim());
      }
      
      if (widget.isEditing && widget.garage != null) {
        // Modification du garage
        final result = await _apiService.updateGarageSuperAdmin(
          garageId: widget.garage!.id,
          name: _nameController.text.trim(),
          city: _cityController.text.trim(),
          region: _regionController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          latitude: latitude,
          longitude: longitude,
        );
        
        if (result['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Garage modifié avec succès'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context, true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Erreur lors de la modification'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        // Création d'un nouveau garage
        final result = await _apiService.createGarageSuperAdmin(
          name: _nameController.text.trim(),
          city: _cityController.text.trim(),
          region: _regionController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          latitude: latitude,
          longitude: longitude,
        );
        
        if (result['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Garage créé avec succès'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context, true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Erreur lors de la création'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24, isWhite: false),
            const SizedBox(width: 8),
            Text(
              widget.isEditing ? 'Modifier le garage' : 'Nouveau garage',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0.5,
        shadowColor: Colors.grey.shade200,
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
              // En-tête
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryBlue, secondaryBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const AppLogo(size: 40, isWhite: true),
                    const SizedBox(height: 8),
                    Text(
                      widget.isEditing ? 'MODIFIER LE GARAGE' : 'NOUVEAU GARAGE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isEditing 
                          ? 'Mettez à jour les informations du garage' 
                          : 'Ajoutez un nouveau garage à la plateforme',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section Informations générales
              _buildSectionCard(
                title: 'Informations générales',
                icon: Icons.business,
                color: primaryBlue,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      label: 'Nom du garage *',
                      prefixIcon: Icons.business,
                      hint: 'Ex: Garage Dakar Centre',
                      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _cityController,
                      label: 'Ville *',
                      prefixIcon: Icons.location_city,
                      hint: 'Ex: Dakar',
                      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _regionController,
                      label: 'Région *',
                      prefixIcon: Icons.map,
                      hint: 'Ex: Dakar',
                      validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _addressController,
                      label: 'Adresse',
                      prefixIcon: Icons.location_on,
                      hint: 'Ex: 123 Avenue Cheikh Anta Diop',
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _phoneController,
                      label: 'Téléphone',
                      prefixIcon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      hint: 'Ex: +221 33 123 45 67',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Section Localisation
              _buildSectionCard(
                title: 'Coordonnées GPS (optionnel)',
                icon: Icons.gps_fixed,
                color: Colors.green,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _latitudeController,
                            label: 'Latitude',
                            prefixIcon: Icons.gps_fixed,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            hint: 'Ex: 14.7167',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            controller: _longitudeController,
                            label: 'Longitude',
                            prefixIcon: Icons.gps_fixed,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            hint: 'Ex: -17.4677',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Utilisez le format décimal (ex: 14.7167, -17.4677)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bouton
              CustomButton(
                text: widget.isEditing ? 'Modifier le garage' : 'Créer le garage',
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}