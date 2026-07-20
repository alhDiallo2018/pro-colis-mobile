// mobile/lib/screens/garage_admin/garage_colis_screen.dart
// Liste filtrable de TOUS les colis du garage - aligné Web (GarageColisPage.tsx)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/parcel.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/parcel_card.dart';
import '../parcel/parcel_detail_screen.dart';

/// Filtres de statut (groupés) — miroir du SegmentedControl Web.
enum _ColisFilter { tous, enAttente, confirmes, enTransit, livres, annules }

extension _ColisFilterX on _ColisFilter {
  String get label {
    switch (this) {
      case _ColisFilter.tous:
        return 'Tous';
      case _ColisFilter.enAttente:
        return 'En attente';
      case _ColisFilter.confirmes:
        return 'Confirmés';
      case _ColisFilter.enTransit:
        return 'En transit';
      case _ColisFilter.livres:
        return 'Livrés';
      case _ColisFilter.annules:
        return 'Annulés';
    }
  }

  bool matches(ParcelStatus status) {
    switch (this) {
      case _ColisFilter.tous:
        return true;
      case _ColisFilter.enAttente:
        return status == ParcelStatus.pending || status == ParcelStatus.free;
      case _ColisFilter.confirmes:
        return status == ParcelStatus.confirmed;
      case _ColisFilter.enTransit:
        return status == ParcelStatus.pickedUp ||
            status == ParcelStatus.inTransit ||
            status == ParcelStatus.arrived ||
            status == ParcelStatus.outForDelivery;
      case _ColisFilter.livres:
        return status == ParcelStatus.delivered;
      case _ColisFilter.annules:
        return status == ParcelStatus.cancelled;
    }
  }
}

class GarageColisScreen extends ConsumerStatefulWidget {
  const GarageColisScreen({super.key});

  @override
  ConsumerState<GarageColisScreen> createState() => _GarageColisScreenState();
}

class _GarageColisScreenState extends ConsumerState<GarageColisScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Parcel> _parcels = [];
  bool _isLoading = true;
  String? _error;
  _ColisFilter _filter = _ColisFilter.tous;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final parcels = await _apiService.getGarageParcels();
      if (mounted) {
        setState(() {
          _parcels = parcels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Parcel> get _filtered {
    final q = _search.trim().toLowerCase();
    return _parcels.where((p) {
      if (!_filter.matches(p.status)) return false;
      if (q.isEmpty) return true;
      final haystack = [
        p.trackingNumber,
        p.departureGarageName,
        p.arrivalGarageName ?? '',
        p.receiverName,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  int _countFor(_ColisFilter filter) =>
      _parcels.where((p) => filter.matches(p.status)).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: Text('Colis de la zone',
            style: AppFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: _buildBody(),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) {
      return PcEmptyState(
        icon: Icons.error_outline_rounded,
        tone: PcTone.red,
        title: 'Une erreur est survenue',
        message: _error,
        action: PcButton(
          'Réessayer',
          icon: Icons.refresh_rounded,
          onPressed: _loadData,
        ),
      );
    }

    final filtered = _filtered;

    return Column(
      children: [
        _buildFilters(),
        _buildSearch(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primary,
            child: filtered.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 60),
                      PcEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Aucun colis',
                        message: 'Aucun colis ne correspond à ce filtre.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final parcel = filtered[index];
                      return ParcelCard(
                        parcel: parcel,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ParcelDetailScreen(parcel: parcel),
                          ),
                        ).then((_) => _loadData()),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _ColisFilter.values) ...[
              _FilterChip(
                label: f.label,
                count: _countFor(f),
                selected: _filter == f,
                onTap: () => setState(() => _filter = f),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: AppTheme.cardColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _search = v),
        style: AppFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Rechercher (suivi, ville, destinataire)',
          hintStyle:
              AppFonts.manrope(fontSize: 13.5, color: AppTheme.slate400),
          prefixIcon:
              const Icon(Icons.search_rounded, size: 20, color: AppTheme.slate400),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.slate400),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: AppTheme.backgroundColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            borderSide: const BorderSide(color: AppTheme.slate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary : AppTheme.backgroundColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.slate200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppTheme.slate600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: AppTheme.mono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white.withOpacity(0.85)
                      : AppTheme.slate400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
