import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:procolis/screens/super-admin/garage_drivers_screen.dart';

import '../../data/country_data.dart';
import '../../models/garage.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/pc_components.dart';

String _flagOfCountry(String country) {
  final match = allCountries.where(
    (c) => c.name.toLowerCase() == country.toLowerCase(),
  );
  return match.isEmpty ? '🌍' : match.first.flag;
}

class GaragesManagementScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const GaragesManagementScreen({super.key, this.embedded = false});

  @override
  ConsumerState<GaragesManagementScreen> createState() => _GaragesManagementScreenState();
}

class _GaragesManagementScreenState extends ConsumerState<GaragesManagementScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Garage> _garages = [];
  String _searchQuery = '';
  String _countryFilter = '';
  String _statusFilter = '';
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

  List<String> get _countries {
    final set = <String>{};
    for (final g in _garages) {
      if (g.country.trim().isNotEmpty) set.add(g.country);
    }
    final list = set.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  List<Garage> get _filteredGarages {
    final q = _searchQuery.trim().toLowerCase();
    return _garages.where((g) {
      if (_countryFilter.isNotEmpty && g.country != _countryFilter) return false;
      if (_statusFilter == 'active' && !g.isActive) return false;
      if (_statusFilter == 'inactive' && g.isActive) return false;
      if (q.isEmpty) return true;
      return g.name.toLowerCase().contains(q) ||
          g.country.toLowerCase().contains(q) ||
          g.city.toLowerCase().contains(q) ||
          g.region.toLowerCase().contains(q) ||
          (g.address ?? '').toLowerCase().contains(q) ||
          (g.phone ?? '').toLowerCase().contains(q);
    }).toList();
  }

  /// Zones groupées par pays, pays triés alphabétiquement.
  List<MapEntry<String, List<Garage>>> get _groupedGarages {
    final map = <String, List<Garage>>{};
    for (final g in _filteredGarages) {
      final key = g.country.trim().isEmpty ? 'Autre' : g.country;
      map.putIfAbsent(key, () => []).add(g);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
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

  Future<void> _toggleActive(Garage garage) async {
    setState(() => _isProcessing = true);
    try {
      final result = await _apiService.updateGarageSuperAdmin(
        garageId: garage.id,
        isActive: !garage.isActive,
      );
      if (result['success'] == true) {
        await _loadGarages();
        if (mounted) {
          _showSnack(
            garage.isActive ? 'Zone désactivée' : 'Zone activée',
            AppTheme.successColor,
          );
        }
      } else {
        if (mounted) {
          _showSnack(result['message'] ?? 'Erreur lors du changement de statut',
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
          'Voulez-vous vraiment supprimer la zone "${garage.name}" ? Elle ne sera plus proposée dans les trajets.',
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
      bottomNavigationBar: widget.embedded ? null : const AppBottomNav(),
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
              Icons.add_location_alt_rounded,
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
    final grouped = _groupedGarages;
    final filteredCount = _filteredGarages.length;
    final countries = _countries;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: _buildSearchField(),
        ),
        _buildFilters(countries),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
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
                '·  $filteredCount',
                style: AppTheme.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate500,
                ),
              ),
              if (countries.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '·  ${countries.length} pays',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
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
                      message:
                          'Aucune zone enregistrée pour le moment. Créez la première zone, n\'importe où dans le monde.',
                      action: PcButton(
                        'Ajouter une zone',
                        icon: Icons.add_rounded,
                        size: PcButtonSize.sm,
                        onPressed: _addGarage,
                      ),
                    ),
                  ],
                )
              : grouped.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 40),
                        PcEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Aucun résultat',
                          message: 'Aucune zone ne correspond à ces filtres.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final entry = grouped[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CountryHeader(
                              country: entry.key,
                              count: entry.value.length,
                            ),
                            ...entry.value.map((garage) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _GarageCard(
                                    garage: garage,
                                    isProcessing: _isProcessing,
                                    onEdit: () => _editGarage(garage),
                                    onDrivers: () => _viewDrivers(garage),
                                    onDelete: () => _deleteGarage(garage),
                                    onToggleActive: () => _toggleActive(garage),
                                  ),
                                )),
                          ],
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilters(List<String> countries) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: 'Tous les pays',
            emoji: '🌍',
            selected: _countryFilter.isEmpty,
            onTap: () => setState(() => _countryFilter = ''),
          ),
          ...countries.map((c) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _FilterChip(
                  label: c,
                  emoji: _flagOfCountry(c),
                  selected: _countryFilter == c,
                  onTap: () => setState(
                      () => _countryFilter = _countryFilter == c ? '' : c),
                ),
              )),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: VerticalDivider(width: 1, color: AppTheme.slate200),
          ),
          _FilterChip(
            label: 'Actives',
            selected: _statusFilter == 'active',
            onTap: () => setState(() =>
                _statusFilter = _statusFilter == 'active' ? '' : 'active'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Inactives',
            selected: _statusFilter == 'inactive',
            onTap: () => setState(() =>
                _statusFilter = _statusFilter == 'inactive' ? '' : 'inactive'),
          ),
        ],
      ),
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
          hintText: 'Rechercher une zone, ville, pays…',
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
// Chip de filtre (pays / statut)
// ============================================================

class _FilterChip extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.teal50 : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.slate200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppTheme.primary : AppTheme.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// En-tête de groupe pays
// ============================================================

class _CountryHeader extends StatelessWidget {
  final String country;
  final int count;

  const _CountryHeader({required this.country, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: [
          Text(_flagOfCountry(country), style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 8),
          Text(
            country.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppTheme.slate500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· $count',
            style: AppTheme.mono(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate400,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: PcDivider()),
        ],
      ),
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
  final VoidCallback onToggleActive;

  const _GarageCard({
    required this.garage,
    required this.isProcessing,
    required this.onEdit,
    required this.onDrivers,
    required this.onDelete,
    required this.onToggleActive,
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
                      garage.isActive ? 'Active' : 'Inactive',
                      tone: garage.isActive ? PcTone.green : PcTone.neutral,
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
          _InfoRow(
            label: 'Pays',
            value: '${_flagOfCountry(garage.country)}  ${garage.country}',
          ),
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
          const SizedBox(height: 6),
          const PcDivider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  garage.isActive ? 'Zone active' : 'Zone inactive',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate600,
                  ),
                ),
              ),
              Switch(
                value: garage.isActive,
                activeColor: AppTheme.primary,
                onChanged: widget.isProcessing
                    ? null
                    : (_) => widget.onToggleActive(),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
  String _country = 'Sénégal';
  bool _isActive = true;

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
    _country = garage.country;
    _cityController.text = garage.city;
    _regionController.text = garage.region;
    _addressController.text = garage.address ?? '';
    _phoneController.text = garage.phone ?? '';
    _latitudeController.text = garage.latitude?.toString() ?? '';
    _longitudeController.text = garage.longitude?.toString() ?? '';
    _isActive = garage.isActive;
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

  void _showCountryPicker() {
    String searchQuery = '';
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = searchCountries(searchQuery);
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un pays...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    setModalState(() => searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.slate100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) => setModalState(() => searchQuery = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final country = filtered[index];
                          final isSelected = _country.toLowerCase() ==
                              country.name.toLowerCase();
                          return ListTile(
                            leading: Text(country.flag,
                                style: const TextStyle(fontSize: 24)),
                            title: Text(country.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            selected: isSelected,
                            selectedTileColor: AppTheme.teal50,
                            onTap: () {
                              setState(() => _country = country.name);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCountryField() {
    return GestureDetector(
      onTap: _showCountryPicker,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: [
            Text(_flagOfCountry(_country),
                style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pays',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate400,
                    ),
                  ),
                  Text(
                    _country,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                color: AppTheme.slate400, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_country.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un pays')),
      );
      return;
    }
    
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
          country: _country,
          city: _cityController.text.trim(),
          region: _regionController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          latitude: latitude,
          longitude: longitude,
          isActive: _isActive,
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
          country: _country,
          city: _cityController.text.trim(),
          region: _regionController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          latitude: latitude,
          longitude: longitude,
          isActive: _isActive,
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
              _buildCountryField(),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _regionController,
                label: 'Région / État',
                prefixIcon: Icons.map,
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zone active',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Les zones inactives n\'apparaissent plus dans les sélecteurs de trajet.',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
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
