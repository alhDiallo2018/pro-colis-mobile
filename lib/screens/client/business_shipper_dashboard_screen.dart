// lib/screens/client/business_shipper_dashboard_screen.dart
//
// Dashboard B2B pour l'expéditeur professionnel. Lit
// `GET /business-shipper/dashboard` et affiche le volume, le SLA, les
// destinations préférées et une sparkline de la cadence quotidienne.
//
// L'endpoint est agnostique du rôle : tout utilisateur authentifié voit son
// propre reporting (filtré par `senderId`). Côté routage, on l'expose sous
// `/business/dashboard` et on laisse la décision d'affichage (profile B2B
// ou pas) au point d'entrée.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api/business_shipper_api.dart';
import '../../services/api/client.dart';
import '../../theme/app_theme.dart';
import '../../theme/fonts.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';
import 'csv_bulk_import_sheet.dart';

class BusinessShipperDashboardScreen extends ConsumerStatefulWidget {
  const BusinessShipperDashboardScreen({super.key});

  @override
  ConsumerState<BusinessShipperDashboardScreen> createState() =>
      _BusinessShipperDashboardScreenState();
}

class _BusinessShipperDashboardScreenState
    extends ConsumerState<BusinessShipperDashboardScreen> {
  late final BusinessShipperApi _api = BusinessShipperApi(ApiClient());

  ShipperDashboard? _dashboard;
  bool _loading = true;
  String? _error;

  // Période sélectionnée. `null` → 30 derniers jours par défaut côté API.
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getDashboard(from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _dashboard = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (range == null) return;
    setState(() {
      _from = DateTime(range.start.year, range.start.month, range.start.day);
      _to = DateTime(
          range.end.year, range.end.month, range.end.day, 23, 59, 59);
    });
    await _load();
  }

  String _fcfa(double v) =>
      '${NumberFormat.decimalPattern('fr').format(v.round())} FCFA';

  @override
  Widget build(BuildContext context) {
    final period = _dashboard;
    final periodLabel = period == null || period.from == null || period.to == null
        ? '30 derniers jours'
        : '${DateFormat('d MMM', 'fr').format(period.from!)} — ${DateFormat('d MMM y', 'fr').format(period.to!)}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        // Fallback explicite : si la pile de navigation est vide (deep link
        // ou context.go), on retombe sur /dashboard plutôt que de bloquer.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Tableau de bord expéditeur'),
        actions: [
          IconButton(
            tooltip: 'Import CSV',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => CsvBulkImportSheet.show(context),
          ),
          IconButton(
            tooltip: 'Mes lots',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () => context.push('/shipment-batches'),
          ),
          IconButton(
            tooltip: 'Choisir la période',
            icon: const Icon(Icons.date_range_rounded),
            onPressed: _loading ? null : _pickPeriod,
          ),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  tone: AppTheme.red400,
                  title: 'Erreur de chargement',
                  message: _error,
                  action: PcButton('Réessayer', onPressed: _load),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      _header(periodLabel),
                      const SizedBox(height: 16),
                      _kpiGrid(period!.stats),
                      const SizedBox(height: 18),
                      _slaCard(period.stats),
                      const SizedBox(height: 14),
                      _destinationsCard(period.stats),
                      const SizedBox(height: 14),
                      _volumeTimelineCard(period.stats),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _header(String periodLabel) {
    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.business_center_rounded, color: AppTheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Période',
                  style: AppFonts.manrope(
                      fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(periodLabel,
                  style: AppFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _kpiGrid(ShipperStats stats) {
    final items = [
      _Kpi('Volume', Icons.inventory_2_rounded, AppTheme.primary,
          '${stats.volumeTotal}', 'colis créés'),
      _Kpi('Livrés', Icons.task_alt_rounded, AppTheme.successColor,
          '${stats.volumeDelivered}', 'remis à destination'),
      _Kpi('En cours', Icons.local_shipping_rounded, AppTheme.teal500,
          '${stats.volumeInProgress}', 'actifs'),
      _Kpi('Annulés', Icons.cancel_schedule_send_rounded, AppTheme.red400,
          '${stats.volumeCancelled}', 'sur la période'),
      _Kpi(
          'Facturé',
          Icons.payments_rounded,
          AppTheme.amber500,
          _fcfa(stats.totalBilled),
          stats.volumeDelivered == 0
              ? 'aucune livraison'
              : '${stats.volumeDelivered} livraisons'),
      _Kpi(
          'Coût moyen',
          Icons.pie_chart_rounded,
          AppTheme.teal400,
          stats.averageCost == null ? '—' : _fcfa(stats.averageCost!),
          'par colis'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map(_statBox).toList(),
    );
  }

  Widget _statBox(_Kpi item) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: PcCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: item.color),
            ),
            const SizedBox(height: 12),
            Text(item.value,
                style: AppFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(item.label,
                style: AppFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(item.hint,
                style: AppFonts.manrope(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _slaCard(ShipperStats stats) {
    final sla = stats.slaOnTimePercent;
    final tone = sla == null
        ? AppTheme.slate500
        : sla >= 85
            ? AppTheme.successColor
            : sla >= 60
                ? AppTheme.amber500
                : AppTheme.red400;
    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.speed_rounded, color: tone),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SLA respecté',
                  style: AppFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(
                  sla == null
                      ? 'En attente de livraisons avec engagement.'
                      : '$sla % livrés dans la fenêtre promise',
                  style: AppFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _destinationsCard(ShipperStats stats) {
    if (stats.topDestinations.isEmpty) return const SizedBox.shrink();
    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Destinations principales',
              style: AppFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...stats.topDestinations.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(Icons.place_outlined,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(d.name,
                          style: AppFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w600))),
                  Text('${d.count} colis',
                      style: AppFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _volumeTimelineCard(ShipperStats stats) {
    if (stats.byDay.isEmpty) {
      return PcCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.show_chart_rounded, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Pas encore de volume quotidien sur la période.',
                  style: AppFonts.manrope(
                      fontSize: 13, color: AppTheme.textSecondary))),
        ]),
      );
    }
    final maxCount = stats.byDay
        .map((e) => e.count)
        .fold<int>(1, (a, b) => a > b ? a : b);
    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cadence quotidienne',
              style: AppFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: stats.byDay
                  .map((d) => Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: (d.count / maxCount) * 92 + 2,
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      AppTheme.teal500,
                                      AppTheme.primary
                                    ], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(3))),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
              '${stats.byDay.first.date} → ${stats.byDay.last.date} · max $maxCount/jour',
              style: AppFonts.manrope(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _Kpi {
  final String label;
  final IconData icon;
  final Color color;
  final String value;
  final String hint;

  const _Kpi(this.label, this.icon, this.color, this.value, this.hint);
}
