// mobile/lib/screens/garage_admin/garage_rapports_screen.dart
// Rapports / Statistiques pour Admin Garage
// Aligné Web (StatBox · Panel · BarChart · Badge)
//
// Les chiffres viennent de `/garage-admin/reports/{daily,monthly}`, dont le
// périmètre est limité à la zone côté API. L'écran ne recalcule plus rien à
// partir d'une page de colis : `getGarageParcels()` est paginé, si bien que
// « colis traités », le taux de livraison et la série d'activité ne décrivaient
// que la première page — pas la période. Même correction que le web
// (`ProColis-Web/src/components/PeriodReportView.tsx`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import 'package:intl/intl.dart';

import '../../models/parcel.dart';
import '../../models/report.dart';
import '../../services/api/client.dart';
import '../../services/api/reports_api.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/pc_components.dart';

/// Fenêtre du rapport : le jour (série horaire) ou le mois (série par jour).
enum _ReportPeriod { day, month }

class GarageRapportsScreen extends ConsumerStatefulWidget {
  const GarageRapportsScreen({super.key});

  @override
  ConsumerState<GarageRapportsScreen> createState() =>
      _GarageRapportsScreenState();
}

class _GarageRapportsScreenState extends ConsumerState<GarageRapportsScreen> {
  final ReportsApi _reportsApi = ReportsApi(ApiClient());
  PeriodReport? _report;
  _ReportPeriod _period = _ReportPeriod.day;
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
      final now = DateTime.now();
      final report = _period == _ReportPeriod.day
          ? await _reportsApi.garageDaily(
              date: DateFormat('yyyy-MM-dd').format(now),
            )
          : await _reportsApi.garageMonthly(year: now.year, month: now.month);
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ReportsApiException ? e.message : e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _selectPeriod(_ReportPeriod period) {
    if (_period == period) return;
    setState(() => _period = period);
    _loadData();
  }

  /// La série du serveur est déjà complète et ordonnée (24 heures, ou tous les
  /// jours du mois) : il n'y a rien à recalculer, seulement à étiqueter.
  List<Map<String, dynamic>> get _activity {
    final series = _report?.series ?? const <ReportPoint>[];
    // Un mois entier ne tient pas en barres lisibles sur un téléphone : on
    // montre la fin de la série, c'est-à-dire la période la plus récente.
    final visible = series.length > 14
        ? series.sublist(series.length - 14)
        : series;
    return visible
        .map((point) => {
              'label': _pointLabel(point.key),
              'count': point.created,
            })
        .toList();
  }

  /// `bucket: hour` donne « 08 », `bucket: day` donne « 2026-08-03 ».
  String _pointLabel(String key) {
    if (_report?.bucket == 'hour') return key;
    final parsed = DateTime.tryParse(key);
    return parsed == null ? key : DateFormat('d/M').format(parsed);
  }

  /// Répartition renvoyée par le serveur, retraduite en `ParcelStatus` pour
  /// réutiliser les libellés et couleurs de statut de l'application.
  Map<ParcelStatus, int> get _statusDistribution {
    final map = <ParcelStatus, int>{};
    (_report?.parcelsByStatus ?? const <String, int>{}).forEach((key, value) {
      final status = ParcelStatus.fromString(key);
      map[status] = (map[status] ?? 0) + value;
    });
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
                      _buildPeriodSelector(),
                      const SizedBox(height: 16),
                      _buildStatGrid(),
                      const SizedBox(height: 20),
                      _buildActivityPanel(),
                      const SizedBox(height: 20),
                      _buildStatusDistributionPanel(),
                      if (_report?.topDrivers.isNotEmpty ?? false) ...[
                        const SizedBox(height: 20),
                        _buildTopDriversPanel(),
                      ],
                    ],
                  ),
                ),
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

  // ---- Sélecteur de période (aligné SegmentedControl du web) ----

  Widget _buildPeriodSelector() {
    Widget segment(_ReportPeriod period, String label, IconData icon) {
      final selected = _period == period;
      return Expanded(
        child: GestureDetector(
          onTap: () => _selectPeriod(period),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppTheme.cardColor : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: selected ? AppTheme.shadowXs() : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? AppTheme.primary : AppTheme.slate500),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.primary : AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          segment(_ReportPeriod.day, 'Jour', Icons.today_rounded),
          segment(_ReportPeriod.month, 'Mois', Icons.calendar_month_rounded),
        ],
      ),
    );
  }

  // ---- Stat Boxes ----

  Widget _buildStatGrid() {
    final totals = _report?.totals ?? const ReportTotals();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PcStatBox(
                icon: Icons.inventory_2_outlined,
                value: totals.created.toString(),
                label: 'Colis créés',
                tone: PcTone.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PcStatBox(
                icon: Icons.task_alt_rounded,
                value: totals.delivered.toString(),
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
                value: totals.cancelled.toString(),
                label: 'Annulés',
                tone: PcTone.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PcStatBox(
                icon: Icons.verified_outlined,
                value: '${totals.deliveryRate}%',
                label: 'Taux de livraison',
                tone: PcTone.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PcStatBox(
          icon: Icons.payments_rounded,
          value: formatFcfa(totals.revenue),
          label: 'Encaissé sur la période',
          tone: PcTone.primary,
        ),
      ],
    );
  }

  // ---- Activité (série du serveur) ----

  Widget _buildActivityPanel() {
    final days = _activity;
    final total = days.fold<int>(0, (s, d) => s + (d['count'] as int));

    return _panel(
      title: _period == _ReportPeriod.day
          ? 'Colis créés · par heure'
          : 'Colis créés · par jour',
      action: PcBadge('$total colis', tone: PcTone.green),
      body: days.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aucune donnée sur la période.',
                style:
                    AppFonts.manrope(fontSize: 13.5, color: AppTheme.slate500),
              ),
            )
          : _buildBarChart(days),
    );
  }

  // ---- Meilleurs chauffeurs de la période ----

  Widget _buildTopDriversPanel() {
    final drivers = _report?.topDrivers ?? const <TopDriver>[];
    return _panel(
      title: 'Meilleurs chauffeurs de la période',
      body: Column(
        children: [
          for (int i = 0; i < drivers.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              children: [
                PcBadge('${i + 1}',
                    tone: i == 0 ? PcTone.amber : PcTone.neutral),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    drivers[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slate700,
                    ),
                  ),
                ),
                Text(
                  '${drivers[i].delivered} livrés',
                  style: AppTheme.mono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
                                  : LinearGradient(
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
                style: AppFonts.manrope(
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
            style: AppFonts.plusJakartaSans(
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
                    style: AppFonts.plusJakartaSans(
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
          Divider(height: 1, thickness: 1, color: AppTheme.slate200),
          Padding(padding: const EdgeInsets.all(16), child: body),
        ],
      ),
    );
  }
}
