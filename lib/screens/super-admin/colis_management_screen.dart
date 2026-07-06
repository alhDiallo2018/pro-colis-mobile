import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/parcel.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/parcel_card.dart';
import '../parcel/parcel_detail_screen.dart';

/// Liste globale des colis (super-admin), alignée sur ColisPage.tsx du web.
/// Filtre par groupe de statut + recherche (suivi / ville) + cartes ParcelCard.
class ColisManagementScreen extends ConsumerStatefulWidget {
  const ColisManagementScreen({super.key});

  @override
  ConsumerState<ColisManagementScreen> createState() =>
      _ColisManagementScreenState();
}

/// Regroupement de statuts pour le filtre, aligné sur FILTERS de ColisPage.tsx :
/// Tous / En attente / Annonces (libre service) / En transit / Livrés.
/// On conserve aussi « Annulés » côté mobile.
enum _ParcelFilter {
  all('Tous'),
  pending('En attente'),
  annonces('Annonces'),
  inTransit('En transit'),
  delivered('Livrés'),
  cancelled('Annulés');

  const _ParcelFilter(this.label);
  final String label;

  bool matches(Parcel p) {
    final s = p.status;
    switch (this) {
      case _ParcelFilter.all:
        return true;
      case _ParcelFilter.pending:
        return s == ParcelStatus.pending || s == ParcelStatus.confirmed;
      case _ParcelFilter.annonces:
        // Colis en libre service (annonce ouverte au marchandage).
        return s == ParcelStatus.free || p.isFreeForBidding;
      case _ParcelFilter.inTransit:
        return s == ParcelStatus.pickedUp ||
            s == ParcelStatus.inTransit ||
            s == ParcelStatus.arrived ||
            s == ParcelStatus.outForDelivery;
      case _ParcelFilter.delivered:
        return s == ParcelStatus.delivered;
      case _ParcelFilter.cancelled:
        return s == ParcelStatus.cancelled;
    }
  }

  PcTone get tone {
    switch (this) {
      case _ParcelFilter.all:
        return PcTone.primary;
      case _ParcelFilter.pending:
        return PcTone.amber;
      case _ParcelFilter.annonces:
        return PcTone.primary;
      case _ParcelFilter.inTransit:
        return PcTone.primary;
      case _ParcelFilter.delivered:
        return PcTone.green;
      case _ParcelFilter.cancelled:
        return PcTone.red;
    }
  }

  /// Accent dédié : les annonces (libre service) se distinguent en deep teal.
  Color? get accentOverride =>
      this == _ParcelFilter.annonces ? AppTheme.deep500 : null;
}

class _ColisManagementScreenState extends ConsumerState<ColisManagementScreen> {
  final ApiService _apiService = ApiService();
  List<Parcel> _parcels = [];
  bool _isLoading = true;
  String _searchQuery = '';
  _ParcelFilter _filter = _ParcelFilter.all;

  @override
  void initState() {
    super.initState();
    _loadParcels();
  }

  Future<void> _loadParcels() async {
    setState(() => _isLoading = true);
    try {
      final parcels = await _apiService.getAllParcelsSuperAdmin();
      if (mounted) {
        setState(() {
          _parcels = parcels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e',
                style: const TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  List<Parcel> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _parcels.where((p) {
      if (!_filter.matches(p)) return false;
      if (q.isEmpty) return true;
      return p.trackingNumber.toLowerCase().contains(q) ||
          p.departureGarageName.toLowerCase().contains(q) ||
          (p.arrivalGarageName ?? '').toLowerCase().contains(q) ||
          p.senderName.toLowerCase().contains(q) ||
          p.receiverName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total = _parcels.length;
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: Text(
          'Colis${total > 0 ? ' · $total' : ''}',
          style: GoogleFonts.plusJakartaSans(
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
                onPressed: _loadParcels,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Recherche + filtres par statut.
          Container(
            color: AppTheme.cardColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un colis (suivi, ville)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppTheme.slate50,
                  ),
                  style: GoogleFonts.manrope(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _ParcelFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: f.label,
                            selected: _filter == f,
                            tone: f.tone,
                            accentOverride: f.accentOverride,
                            onSelected: () => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const PcDivider(),

          // Liste des colis.
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? PcEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Aucun colis',
                        message:
                            'Aucun colis ne correspond à ce filtre ou à votre recherche.',
                        action: PcButton(
                          'Actualiser',
                          icon: Icons.refresh_rounded,
                          variant: PcButtonVariant.secondary,
                          size: PcButtonSize.sm,
                          onPressed: _loadParcels,
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: _loadParcels,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final p = filtered[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ParcelCard(
                                  parcel: p,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ParcelDetailScreen(parcel: p),
                                      ),
                                    );
                                  },
                                ),
                                // Chauffeur assigné (cf. colonne « Chauffeur » du web).
                                _DriverLine(driverName: p.driverName),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final PcTone tone;
  final Color? accentOverride;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.tone = PcTone.primary,
    this.accentOverride,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentOverride ??
        switch (tone) {
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
            style: GoogleFonts.plusJakartaSans(
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

/// Ligne « Chauffeur » sous la carte : nom du chauffeur assigné ou
/// « Non assigné » explicite (cf. ColisPage.tsx, colonne Chauffeur).
class _DriverLine extends StatelessWidget {
  final String? driverName;

  const _DriverLine({required this.driverName});

  @override
  Widget build(BuildContext context) {
    final assigned = driverName != null && driverName!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Row(
        children: [
          Icon(
            assigned ? Icons.local_shipping_rounded : Icons.person_off_rounded,
            size: 15,
            color: assigned ? AppTheme.slate500 : AppTheme.slate400,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              assigned ? driverName!.trim() : 'Non assigné',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: assigned ? FontWeight.w600 : FontWeight.w500,
                fontStyle: assigned ? FontStyle.normal : FontStyle.italic,
                color: assigned ? AppTheme.slate600 : AppTheme.slate400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
