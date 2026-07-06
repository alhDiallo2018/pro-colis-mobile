// mobile/lib/screens/garage_admin/garage_rapports_screen.dart
// Rapports / Statistiques pour Admin Garage
// Aligné Web (StatBox · Panel · BarChart · Badge)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/parcel.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

class GarageRapportsScreen extends ConsumerStatefulWidget {
  const GarageRapportsScreen({super.key});

  @override
  ConsumerState<GarageRapportsScreen> createState() =>
      _GarageRapportsScreenState();
}

class _GarageRapportsScreenState extends ConsumerState<GarageRapportsScreen> {
  final ApiService _apiService = ApiService();
  List<Parcel> _parcels = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  // ---- Computed stats ----

  int get _totalParcels => _parcels.length;
  int get _deliveredCount =>
      _parcels.where((p) => p.status == ParcelStatus.delivered).length;
  int get _cancelledCount =>
      _parcels.where((p) => p.status == ParcelStatus.cancelled).length;
  double get _successRate =>
      _totalParcels > 0 ? (_deliveredCount / _totalParcels) * 100 : 0;

  // 7-day activity
  List<Map<String, dynamic>> get _sevenDayActivity {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    return days.map((day) {
      final count = _parcels.where((p) {
        final created = p.createdAt;
        return created.year == day.year &&
            created.month == day.month &&
            created.day == day.day;
      }).length;
      final label = DateFormat('EEE', 'fr').format(day);
      return {'label': label, 'count': count, 'date': day};
    }).toList();
  }

  // Status distribution
  Map<ParcelStatus, int> get _statusDistribution {
    final map = <ParcelStatus, int>{};
    for (final p in _parcels) {
      map[p.status] = (map[p.status] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Rapports'),
        actions: [
          PcIconButton(
            Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: _loadData,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatGrid(),
                      const SizedBox(height: 20),
                      _buildSevenDayPanel(),
                      const SizedBox(height: 20),
                      _buildStatusDistributionPanel(),
                    ],
                  ),
                ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  Widget _buildErrorView() {
    return PcEmptyState(
      icon: Icons.error_outline_rounded,
      tone: PcTone.red,
      title: 'Impossible de charger',
      message: _error,
      action: PcButton(
        'Réessayer',
        icon: Icons.refresh_rounded,
        onPressed: _loadData,
      ),
    );
  }

  // ---- Stat Boxes (2x2) ----

  Widget _buildStatGrid() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PcStatBox(
                icon: Icons.inventory_2_outlined,
                value: _totalParcels.toString(),
                label: 'Colis traités',
                tone: PcTone.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PcStatBox(
                icon: Icons.task_alt_rounded,
                value: _deliveredCount.toString(),
                label: 'Livrés',
                tone: PcTone.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PcStatBox(
                icon: Icons.cancel_outlined,
                value: _cancelledCount.toString(),
                label: 'Annulés',
                tone: PcTone.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PcStatBox(
                icon: Icons.verified_outlined,
                value: '${_successRate.toStringAsFixed(0)}%',
                label: 'Taux de livraison',
                tone: PcTone.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- 7-Day Activity Vertical Bar Chart ----

  Widget _buildSevenDayPanel() {
    final days = _sevenDayActivity;
    final total = days.fold<int>(0, (s, d) => s + (d['count'] as int));

    return _panel(
      title: 'Activité · 7 jours',
      action: PcBadge('$total colis', tone: PcTone.green),
      body: _buildBarChart(days),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> days) {
    final maxCount =
        days.fold<int>(0, (m, d) => (d['count'] as int) > m ? d['count'] as int : m);
    final effectiveMax = maxCount > 0 ? maxCount : 1;

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(days.length, (i) {
              final count = days[i]['count'] as int;
              final isLast = i == days.length - 1;
              final fraction = count / effectiveMax;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 4,
                    right: isLast ? 0 : 4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (count > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '$count',
                            style: AppTheme.mono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isLast
                                  ? AppTheme.amber600
                                  : AppTheme.teal600,
                            ),
                          ),
                        ),
                      Expanded(
                        child: FractionallySizedBox(
                          alignment: Alignment.bottomCenter,
                          heightFactor: fraction.clamp(0.04, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: isLast
                                  ? null
                                  : const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppTheme.teal400,
                                        AppTheme.teal600
                                      ],
                                    ),
                              color: isLast ? AppTheme.amber400 : null,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(days.length, (i) {
            return Expanded(
              child: Text(
                (days[i]['label'] as String).toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTheme.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate400,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ---- Status Distribution ----

  Widget _buildStatusDistributionPanel() {
    final distribution = _statusDistribution;
    final entries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue =
        entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    final effectiveMax = maxValue > 0 ? maxValue : 1;

    return _panel(
      title: 'Répartition par statut',
      body: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aucune donnée.',
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  color: AppTheme.slate500,
                ),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _buildStatusRow(entries[i], effectiveMax),
                ],
              ],
            ),
    );
  }

  Widget _buildStatusRow(MapEntry<ParcelStatus, int> entry, int effectiveMax) {
    final status = entry.key;
    final count = entry.value;
    final fraction = count / effectiveMax;
    final colors = AppTheme.statusColors(status);

    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: colors.dot,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: AppTheme.mono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ---- Panel générique (surface + entête titre/action, aligné Web) ----

  Widget _panel({
    required String title,
    Widget? action,
    required Widget body,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.shadowXs(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppTheme.slate200),
          Padding(padding: const EdgeInsets.all(16), child: body),
        ],
      ),
    );
  }
}
