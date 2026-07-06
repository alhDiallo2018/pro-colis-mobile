import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:procolis/screens/super-admin/garage_drivers_screen.dart';

import '../../models/garage.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/pc_components.dart';

class GaragesManagementScreen extends ConsumerStatefulWidget {
  const GaragesManagementScreen({super.key});

  @override
  ConsumerState<GaragesManagementScreen> createState() => _GaragesManagementScreenState();
}

class _GaragesManagementScreenState extends ConsumerState<GaragesManagementScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Garage> _garages = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGarages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Garage> get _filteredGarages {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _garages;
    return _garages.where((g) {
      return g.name.toLowerCase().contains(q) ||
          g.city.toLowerCase().contains(q) ||
          g.region.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _loadGarages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final garages = await _apiService.getAllGaragesSuperAdmin();
      setState(() {
        _garages = garages;
        _isLoading = false;
      });
      debugPrint('📦 ${garages.length} garages chargés depuis la base de données');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      debugPrint('❌ Erreur chargement garages: $e');
    }
  }

  Future<void> _refreshData() async {
    await _loadGarages();
  }

  Future<void> _addGarage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const _GarageFormScreen(isEditing: false),
      ),
    );
    
    if (result == true && mounted) {
      await _loadGarages();
      if (mounted) {
        _showSnack('Zone ajoutée avec succès', AppTheme.successColor);
      }
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  Future<void> _editGarage(Garage garage) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _GarageFormScreen(isEditing: true, garage: garage),
      ),
    );
    
    if (result == true && mounted) {
      await _loadGarages();
      if (mounted) {
        _showSnack('Zone modifiée avec succès', AppTheme.successColor);
      }
    }
  }

  Future<void> _viewDrivers(Garage garage) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GarageDriversScreen(garage: garage),
      ),
    );
  }

  Future<void> _deleteGarage(Garage garage) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.red400, size: 28),
            const SizedBox(width: 12),
            Text('Supprimer la zone',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTheme.textPrimary,
                )),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer la zone "${garage.name}" ?',
          style: GoogleFonts.manrope(color: AppTheme.slate600),
        ),
        actions: [
          PcButton(
            'Annuler',
            variant: PcButtonVariant.secondary,
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
      setState(() => _isProcessing = true);
      try {
        final result = await _apiService.deleteGarageSuperAdmin(garage.id);
        if (result['success'] == true) {
          await _loadGarages();
          if (mounted) {
            _showSnack('Zone supprimée avec succès', AppTheme.successColor);
          }
        } else {
          if (mounted) {
            _showSnack(result['message'] ?? 'Erreur lors de la suppression',
                AppTheme.errorColor);
          }
        }
      } catch (e) {
        if (mounted) {
          _showSnack('Erreur: $e', AppTheme.errorColor);
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Gestion des zones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PcIconButton(
            Icons.refresh_rounded,
            variant: PcIconButtonVariant.ghost,
            tooltip: 'Rafraîchir',
            onPressed: _loadGarages,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 2),
            child: PcIconButton(
              Icons.add_rounded,
              variant: PcIconButtonVariant.soft,
              tooltip: 'Ajouter une zone',
              onPressed: _addGarage,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final filtered = _filteredGarages;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: _buildSearchField(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
          child: Row(
            children: [
              Text(
                'Zones',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '·  ${filtered.length}',
                style: AppTheme.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _garages.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 40),
                    PcEmptyState(
                      icon: Icons.garage_rounded,
                      tone: PcTone.primary,
                      title: 'Aucune zone',
                      message: 'Aucune zone enregistrée pour le moment.',
                      action: PcButton(
                        'Ajouter une zone',
                        icon: Icons.add_rounded,
                        size: PcButtonSize.sm,
                        onPressed: _addGarage,
                      ),
                    ),
                  ],
                )
              : filtered.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 40),
                        PcEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Aucun résultat',
                          message: 'Aucune zone ne correspond à votre recherche.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final garage = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GarageCard(
                            garage: garage,
                            isProcessing: _isProcessing,
                            onEdit: () => _editGarage(garage),
                            onDrivers: () => _viewDrivers(garage),
                            onDelete: () => _deleteGarage(garage),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.shadowXs(),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Rechercher une zone, une ville…',
          hintStyle: GoogleFonts.manrope(
            fontSize: 14,
            color: AppTheme.slate400,
          ),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.slate400, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.slate400, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      children: [
        const SizedBox(height: 40),
        PcEmptyState(
          icon: Icons.error_outline_rounded,
          tone: PcTone.red,
          title: 'Erreur de chargement',
          message: _error,
          action: PcButton(
            'Réessayer',
            icon: Icons.refresh_rounded,
            size: PcButtonSize.sm,
            onPressed: _loadGarages,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Carte garage extensible (design system ProColis)
// ============================================================

class _GarageCard extends StatefulWidget {
  final Garage garage;
  final bool isProcessing;
  final VoidCallback onEdit;
  final VoidCallback onDrivers;
  final VoidCallback onDelete;

  const _GarageCard({
    required this.garage,
    required this.isProcessing,
    required this.onEdit,
    required this.onDrivers,
    required this.onDelete,
  });

  @override
  State<_GarageCard> createState() => _GarageCardState();
}

class _GarageCardState extends State<_GarageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final garage = widget.garage;
    final location = [garage.city, garage.region]
        .where((s) => s.trim().isNotEmpty)
        .join(', ');

    return PcCard(
      padding: EdgeInsets.zero,
      shadow: AppTheme.shadowXs(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête cliquable
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.teal50,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(Icons.garage_rounded,
                          color: AppTheme.primary, size: 23),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            garage.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            location.isEmpty ? '—' : location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PcBadge(
                      garage.isActive ? 'Actif' : 'Inactif',
                      tone: garage.isActive ? PcTone.green : PcTone.neutral,
                    ),
                    const SizedBox(width: 6),
                    PcBadge(
                      '${garage.driversCount} chauffeurs',
                      tone: PcTone.green,
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.expand_more_rounded,
                          color: AppTheme.slate400, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Détails
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildDetails(garage),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(Garage garage) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        children: [
          const PcDivider(),
          const SizedBox(height: 10),
          _InfoRow(label: 'Région', value: garage.region),
          if (garage.address != null && garage.address!.isNotEmpty)
            _InfoRow(label: 'Adresse', value: garage.address!),
          if (garage.phone != null && garage.phone!.isNotEmpty)
            _InfoRow(label: 'Téléphone', value: garage.phone!, mono: true),
          if (garage.latitude != null && garage.longitude != null)
            _InfoRow(
              label: 'Coordonnées',
              value:
                  '${garage.latitude!.toStringAsFixed(4)}, ${garage.longitude!.toStringAsFixed(4)}',
              mono: true,
            ),
          const SizedBox(height: 6),
          const PcDivider(),
          const SizedBox(height: 6),
          _InfoRow(
            label: 'Chauffeurs',
            value: garage.driversCount.toString(),
            valueColor: AppTheme.green700,
            mono: true,
          ),
          _InfoRow(
            label: 'Colis traités',
            value: garage.parcelsCount.toString(),
            valueColor: AppTheme.amber600,
            mono: true,
          ),
          _InfoRow(
            label: 'Chiffre d\'affaires',
            value: '${garage.revenue.toInt()} FCFA',
            valueColor: AppTheme.primary,
            mono: true,
            isBold: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PcButton(
                  'Modifier',
                  icon: Icons.edit_rounded,
                  variant: PcButtonVariant.secondary,
                  size: PcButtonSize.sm,
                  block: true,
                  onPressed: widget.onEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PcButton(
                  'Chauffeurs',
                  icon: Icons.people_alt_rounded,
                  size: PcButtonSize.sm,
                  block: true,
                  onPressed: widget.onDrivers,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PcButton(
            'Supprimer',
            icon: Icons.delete_outline_rounded,
            variant: PcButtonVariant.danger,
            size: PcButtonSize.sm,
            block: true,
            loading: widget.isProcessing,
            onPressed: widget.isProcessing ? null : widget.onDelete,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  final bool mono;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                color: AppTheme.slate500,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? AppTheme.mono(
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                      color: valueColor ?? AppTheme.textPrimary,
                    )
                  : GoogleFonts.manrope(
                      fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                      color: valueColor ?? AppTheme.textPrimary,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Formulaire de garage pour ajout/modification (privé à ce fichier)
class _GarageFormScreen extends StatefulWidget {
  final bool isEditing;
  final Garage? garage;
  
  const _GarageFormScreen({
    required this.isEditing,
    this.garage,
  });

  @override
  State<_GarageFormScreen> createState() => _GarageFormScreenState();
}

class _GarageFormScreenState extends State<_GarageFormScreen> {
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
              content: const Text('Zone modifiée avec succès'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context, true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Erreur lors de la modification'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else {
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
              content: const Text('Zone créée avec succès'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          Navigator.pop(context, true);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Erreur lors de la création'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Modifier la zone' : 'Nouvelle zone',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CustomTextField(
                controller: _nameController,
                label: 'Nom de la zone',
                prefixIcon: Icons.business,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _cityController,
                label: 'Ville',
                prefixIcon: Icons.location_city,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _regionController,
                label: 'Région',
                prefixIcon: Icons.map,
                validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _addressController,
                label: 'Adresse',
                prefixIcon: Icons.location_on,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _phoneController,
                label: 'Téléphone',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _latitudeController,
                      label: 'Latitude',
                      prefixIcon: Icons.gps_fixed,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _longitudeController,
                      label: 'Longitude',
                      prefixIcon: Icons.gps_fixed,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
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
}