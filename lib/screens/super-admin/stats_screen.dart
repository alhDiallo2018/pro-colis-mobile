// lib/screens/super-admin/stats_screen.dart
// Tableau de bord super-admin — aligné Web (StatBox · Panel · BarChart · breakdown)

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

class AdminStatsScreen extends ConsumerStatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  ConsumerState<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends ConsumerState<AdminStatsScreen> {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  List<Parcel> _parcels = [];
  List<Garage> _garages = [];
  // Indicateurs scalaires renvoyés par le backend (GET /super-admin/stats).
  Map<String, dynamic> _backendStats = {};
  bool _isLoading = true;
  String? _error;

  // Libellés des mois (initiales) — aligné Web StatistiquesPage (MONTHS).
  static const List<String> _monthLabels = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
  ];

  // Traductions FR des indicateurs backend (fallback: clé « jolifiée »).
  static const Map<String, String> _indicatorLabels = {
    'totalUsers': 'Utilisateurs',
    'totalDrivers': 'Chauffeurs actifs',
    'totalClients': 'Clients actifs',
    'totalGarages': 'Zones',
    'totalVehicles': 'Véhicules',
    'totalParcels': 'Colis au total',
    'parcelsInTransit': 'En transit',
    'parcelsDeliveredToday': "Livrés aujourd'hui",
    'parcelsPending': 'En attente',
    'totalRevenue': 'Revenus totaux',
    'revenueThisMonth': 'Revenus ce mois',
    'revenueLastMonth': 'Revenus mois dernier',
  };

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
      final results = await Future.wait([
        _apiService.getAllUsersSuperAdmin(),
        _apiService.getAllParcelsSuperAdmin(),
        _apiService.getAllGaragesSuperAdmin(),
        _apiService.getAdminStats(),
      ]);

      final users = results[0] as List<User>;
      final parcels = results[1] as List<Parcel>;
      final garages = results[2] as List<Garage>;
      final statsResponse = results[3] as Map<String, dynamic>;
      // ok() aplatit `data` : les scalaires sont sous la clé `stats`.
      final stats = (statsResponse['stats'] is Map)
          ? Map<String, dynamic>.from(statsResponse['stats'] as Map)
          : <String, dynamic>{};

      setState(() {
        _users = users;
        _parcels = parcels;
        _garages = garages;
        _backendStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  int get _totalUsers => _users.length;
  int get _totalDrivers => _users.where((u) => u.role == UserRole.driver).length;
  int get _totalParcels => _parcels.length;
  int get _parcelsInTransit => _parcels.where((p) =>
      p.status == ParcelStatus.inTransit ||
      p.status == ParcelStatus.outForDelivery ||
      p.status == ParcelStatus.pickedUp).length;
  int get _parcelsDelivered =>
      _parcels.where((p) => p.status == ParcelStatus.delivered).length;
  double get _totalRevenue => _parcels
      .where((p) => p.status == ParcelStatus.delivered)
      .fold(0.0, (sum, p) => sum + (p.price ?? 0));

  int get _totalGarages => _garages.length;

  // Volume de colis agrégé par mois calendaire (Jan..Déc), toutes années
  // confondues — dérivé de createdAt (le backend ne fournit pas de série prête).
  List<int> get _volumeByMonth {
    final buckets = List<int>.filled(12, 0);
    for (final p in _parcels) {
      final m = p.createdAt.month; // 1..12
      if (m >= 1 && m <= 12) buckets[m - 1]++;
    }
    return buckets;
  }

  // Revenus agrégés par mois calendaire (colis livrés × prix).
  List<double> get _revenueByMonth {
    final buckets = List<double>.filled(12, 0);
    for (final p in _parcels.where((p) => p.status == ParcelStatus.delivered)) {
      final m = p.createdAt.month;
      if (m >= 1 && m <= 12) buckets[m - 1] += (p.price ?? 0);
    }
    return buckets;
  }

  // Indicateurs scalaires (num/String) exposés par le backend — aligné Web
  // (StatistiquesPage: Object.entries(stats).filter num|string).
  List<MapEntry<String, dynamic>> get _indicators {
    return _backendStats.entries
        .where((e) => e.value is num || e.value is String)
        .toList();
  }

  String _prettyKey(String k) {
    final label = _indicatorLabels[k];
    if (label != null) return label;
    // Fallback : snake/camel → mots capitalisés (aligné Web prettyKey).
    final spaced = k
        .replaceAll(RegExp(r'[_-]'), ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  String _formatIndicator(String key, dynamic value) {
    if (value is num && key.toLowerCase().contains('revenue')) {
      return _fcfa(value);
    }
    return value.toString();
  }

  List<Map<String, dynamic>> get _recentActivities {
    final activities = <Map<String, dynamic>>[];

    // Ajouter les 5 derniers utilisateurs
    for (var user in _users.reversed.take(5)) {
      activities.add({
        'type': 'user',
        'title': 'Nouvel utilisateur',
        'description': 'Inscription de ${user.fullName}',
        'time': user.createdAt,
        'icon': Icons.person_add,
        'tone': PcTone.primary,
      });
    }

    // Ajouter les 5 derniers colis
    for (var parcel in _parcels.reversed.take(5)) {
      final statusText = parcel.status.label;
      activities.add({
        'type': 'parcel',
        'title': 'Colis $statusText',
        'description': '${parcel.trackingNumber} - ${parcel.receiverName}',
        'time': parcel.createdAt,
        'icon': parcel.status == ParcelStatus.delivered
            ? Icons.check_circle
            : Icons.local_shipping,
        'tone': parcel.status == ParcelStatus.delivered
            ? PcTone.green
            : PcTone.amber,
      });
    }

    // Trier par date décroissante
    activities
        .sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));

    // Retourner les 10 plus récentes
    return activities.take(10).toList();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  String _fcfa(num value) => '${value.toInt()} FCFA';

  // Répartition des colis par statut (source des graphiques + détails).
  List<_StatusStat> get _statusStats {
    const config = <MapEntry<ParcelStatus, String>>[
      MapEntry(ParcelStatus.pending, 'Att'),
      MapEntry(ParcelStatus.confirmed, 'Cnf'),
      MapEntry(ParcelStatus.pickedUp, 'Ram'),
      MapEntry(ParcelStatus.inTransit, 'Trn'),
      MapEntry(ParcelStatus.arrived, 'Arr'),
      MapEntry(ParcelStatus.outForDelivery, 'Liv'),
      MapEntry(ParcelStatus.delivered, 'Lvr'),
      MapEntry(ParcelStatus.cancelled, 'Ann'),
    ];
    return config
        .map((e) => _StatusStat(
              status: e.key,
              label: e.key.label,
              shortLabel: e.value,
              count: _parcels.where((p) => p.status == e.key).length,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        backgroundColor: AppTheme.cardColor,
        actions: [
          PcIconButton(
            Icons.refresh_rounded,
            variant: PcIconButtonVariant.soft,
            onPressed: _refreshData,
            tooltip: 'Rafraîchir',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatGrid(),
                      const SizedBox(height: 20),
                      _buildMonthlyVolumePanel(),
                      const SizedBox(height: 20),
                      _buildMonthlyRevenuePanel(),
                      const SizedBox(height: 20),
                      _buildVolumePanel(),
                      const SizedBox(height: 20),
                      if (_indicators.isNotEmpty) ...[
                        _buildIndicatorsPanel(),
                        const SizedBox(height: 20),
                      ],
                      _buildBreakdownPanel(),
                      const SizedBox(height: 20),
                      _buildActivitiesPanel(),
                    ],
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------
  // Grille de tuiles KPI (2 par ligne)
  // ---------------------------------------------------------------
  Widget _buildStatGrid() {
    final tiles = <Widget>[
      _statTile(
        icon: Icons.people_alt_outlined,
        value: '$_totalUsers',
        label: 'Utilisateurs',
        bg: AppTheme.teal50,
        fg: AppTheme.teal500,
      ),
      _statTile(
        icon: Icons.local_shipping_outlined,
        value: '$_totalDrivers',
        label: 'Chauffeurs',
        bg: AppTheme.green50,
        fg: AppTheme.green700,
      ),
      _statTile(
        icon: Icons.inventory_2_outlined,
        value: '$_totalParcels',
        label: 'Colis au total',
        bg: AppTheme.amber50,
        fg: AppTheme.amber600,
      ),
      _statTile(
        icon: Icons.garage_outlined,
        value: '$_totalGarages',
        label: 'Zones',
        bg: AppTheme.amber50,
        fg: AppTheme.amber600,
      ),
      _statTile(
        icon: Icons.task_alt_outlined,
        value: '$_parcelsDelivered',
        label: 'Colis livrés',
        bg: AppTheme.green50,
        fg: AppTheme.green700,
      ),
      _statTile(
        icon: Icons.route_outlined,
        value: '$_parcelsInTransit',
        label: 'En transit',
        bg: AppTheme.infoSoft,
        fg: AppTheme.deep700,
      ),
      _statTile(
        icon: Icons.payments_outlined,
        value: _fcfa(_totalRevenue),
        label: 'Revenus',
        bg: AppTheme.teal50,
        fg: AppTheme.teal600,
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 12),
              if (i + 1 < tiles.length)
                Expanded(child: tiles[i + 1])
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required String value,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.shadowXs(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTheme.mono(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Panneau — Volume de colis · 12 mois (barres mensuelles Jan..Déc)
  // ---------------------------------------------------------------
  Widget _buildMonthlyVolumePanel() {
    final values = _volumeByMonth.map((v) => v.toDouble()).toList();
    return _panel(
      title: 'Volume de colis · 12 mois',
      action: PcBadge('$_totalParcels', tone: PcTone.primary),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_totalParcels',
            style: AppTheme.mono(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildMonthlyBarChart(values),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Panneau — Revenus · 12 mois (barres mensuelles, dernier mis en avant)
  // ---------------------------------------------------------------
  Widget _buildMonthlyRevenuePanel() {
    final values = _revenueByMonth;
    return _panel(
      title: 'Revenus · 12 mois',
      action: PcBadge(_fcfa(_totalRevenue), tone: PcTone.green),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fcfa(_totalRevenue),
            style: AppTheme.mono(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildMonthlyBarChart(values, highlightLast: true),
        ],
      ),
    );
  }

  // Graphique à barres 12 mois (réutilise le motif « dessiné main » du projet).
  Widget _buildMonthlyBarChart(
    List<double> values, {
    bool highlightLast = false,
  }) {
    final maxValue = values.fold<double>(0, max);

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (i) {
              final isLast = i == values.length - 1;
              final highlight = highlightLast && isLast;
              final fraction = maxValue > 0 ? values[i] / maxValue : 0.0;
              final opacity = highlight
                  ? 1.0
                  : (0.55 + (i / values.length) * 0.45).clamp(0.0, 1.0);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 3,
                    right: isLast ? 0 : 3,
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: fraction.clamp(0.04, 1.0),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: highlight
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [AppTheme.teal400, AppTheme.teal600],
                                ),
                          color: highlight ? AppTheme.amber400 : null,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(_monthLabels.length, (i) {
            return Expanded(
              child: Text(
                _monthLabels[i],
                textAlign: TextAlign.center,
                style: AppTheme.mono(
                  fontSize: 10.5,
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

  // ---------------------------------------------------------------
  // Panneau — Indicateurs détaillés (scalaires backend, aligné Web)
  // ---------------------------------------------------------------
  Widget _buildIndicatorsPanel() {
    final indicators = _indicators;
    return _panel(
      title: 'Indicateurs détaillés',
      action: PcBadge('${indicators.length}', tone: PcTone.neutral),
      body: Column(
        children: [
          for (int i = 0; i < indicators.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _indicatorTile(indicators[i])),
                const SizedBox(width: 12),
                if (i + 1 < indicators.length)
                  Expanded(child: _indicatorTile(indicators[i + 1]))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _indicatorTile(MapEntry<String, dynamic> entry) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.slate50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatIndicator(entry.key, entry.value),
              maxLines: 1,
              style: AppTheme.mono(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _prettyKey(entry.key),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Panneau graphique — volume par statut (barres verticales)
  // ---------------------------------------------------------------
  Widget _buildVolumePanel() {
    return _panel(
      title: 'Volume de colis · par statut',
      action: PcBadge('$_totalParcels', tone: PcTone.primary),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_totalParcels',
            style: AppTheme.mono(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildBarChart(),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final stats = _statusStats;
    final maxCount = stats.map((s) => s.count).fold<int>(0, max);

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(stats.length, (i) {
              final isLast = i == stats.length - 1;
              final fraction = maxCount > 0 ? stats[i].count / maxCount : 0.0;
              final opacity = (0.55 + (i / stats.length) * 0.45).clamp(0.0, 1.0);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 4,
                    right: isLast ? 0 : 4,
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: fraction.clamp(0.04, 1.0),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppTheme.teal400, AppTheme.teal600],
                          ),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(stats.length, (i) {
            return Expanded(
              child: Text(
                stats[i].shortLabel,
                textAlign: TextAlign.center,
                style: AppTheme.mono(
                  fontSize: 10.5,
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

  // ---------------------------------------------------------------
  // Panneau détails — répartition par statut (breakdown)
  // ---------------------------------------------------------------
  Widget _buildBreakdownPanel() {
    final stats = _statusStats.where((s) => s.count > 0).toList();

    return _panel(
      title: 'Répartition des colis',
      body: stats.isEmpty
          ? const PcEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Aucun colis',
              message: 'Les colis enregistrés apparaîtront ici.',
            )
          : Column(
              children: [
                for (int i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _buildBreakdownRow(stats[i]),
                ],
              ],
            ),
    );
  }

  Widget _buildBreakdownRow(_StatusStat stat) {
    final colors = AppTheme.statusColors(stat.status);
    final percentage = _totalParcels > 0 ? stat.count / _totalParcels : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.dot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  stat.label,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              '${stat.count} · ${(percentage * 100).toStringAsFixed(1)}%',
              style: AppTheme.mono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppTheme.slate100,
            color: colors.dot,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // Panneau dernières activités (flush)
  // ---------------------------------------------------------------
  Widget _buildActivitiesPanel() {
    final activities = _recentActivities;
    return _panel(
      title: 'Dernières activités',
      flush: true,
      body: activities.isEmpty
          ? const PcEmptyState(
              icon: Icons.history_rounded,
              title: 'Aucune activité récente',
              message: 'Les inscriptions et colis récents apparaîtront ici.',
            )
          : Column(
              children: [
                for (int i = 0; i < activities.length; i++) ...[
                  if (i > 0) const PcDivider(),
                  PcListRow(
                    icon: activities[i]['icon'] as IconData,
                    iconTone: activities[i]['tone'] as PcTone,
                    title: activities[i]['title'] as String,
                    subtitle: activities[i]['description'] as String,
                    trailing: Text(
                      _formatDate(activities[i]['time'] as DateTime),
                      style: AppFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.slate400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  // ---------------------------------------------------------------
  // État d'erreur
  // ---------------------------------------------------------------
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PcEmptyState(
          icon: Icons.error_outline_rounded,
          tone: PcTone.red,
          title: 'Erreur de chargement',
          message: _error,
          action: PcButton(
            'Réessayer',
            icon: Icons.refresh_rounded,
            onPressed: _loadData,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Panel générique (surface + entête titre/action, aligné Web)
  // ---------------------------------------------------------------
  Widget _panel({
    required String title,
    Widget? action,
    required Widget body,
    bool flush = false,
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
          const Divider(height: 1, thickness: 1, color: AppTheme.slate200),
          if (flush)
            body
          else
            Padding(padding: const EdgeInsets.all(16), child: body),
        ],
      ),
    );
  }
}

class _StatusStat {
  final ParcelStatus status;
  final String label;
  final String shortLabel;
  final int count;

  const _StatusStat({
    required this.status,
    required this.label,
    required this.shortLabel,
    required this.count,
  });
}
