// mobile/lib/screens/driver/revenus_screen.dart
// Écran Revenus du chauffeur - aligné Web (StatBox · Panel · BarChart · Badge)

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

class DriverRevenusScreen extends ConsumerStatefulWidget {
  const DriverRevenusScreen({super.key});

  @override
  ConsumerState<DriverRevenusScreen> createState() =>
      _DriverRevenusScreenState();
}

class _DriverRevenusScreenState extends ConsumerState<DriverRevenusScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _payments = [];
  double _totalRevenue = 0;
  double _lastWeekRevenue = 0;
  double _currentWeekRevenue = 0;
  bool _isLoading = true;
  String _paymentFilter = 'all';
  int _visiblePaymentsCount = 10;

  static const List<double> _dailyRevenue = [
    12500,
    8700,
    15600,
    5200,
    18200,
    22300,
    9400,
  ];

  static const List<String> _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final payments = await _apiService.getPaymentHistory();
      double total = 0;

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final lastWeekStart = weekStart.subtract(const Duration(days: 7));
      double currentWeek = 0;
      double lastWeek = 0;

      for (final p in payments) {
        final amount = (p['amount'] ?? 0).toDouble();
        total += amount;

        try {
          final date = DateTime.parse(p['createdAt']?.toString() ?? '');
          if (date.isAfter(weekStart)) {
            currentWeek += amount;
          } else if (date.isAfter(lastWeekStart) && date.isBefore(weekStart)) {
            lastWeek += amount;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _payments = payments;
          _totalRevenue = total;
          _currentWeekRevenue = currentWeek;
          _lastWeekRevenue = lastWeek;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _weekComparison {
    if (_lastWeekRevenue == 0) return '+100%';
    final diff =
        ((_currentWeekRevenue - _lastWeekRevenue) / _lastWeekRevenue * 100)
            .round();
    return '${diff >= 0 ? '+' : ''}$diff%';
  }

  List<Map<String, dynamic>> get _filteredPayments {
    if (_paymentFilter == 'all') return _payments;
    return _payments
        .where((p) => p['status']?.toString() == _paymentFilter)
        .toList();
  }

  List<Map<String, dynamic>> get _visiblePayments {
    return _filteredPayments.take(_visiblePaymentsCount).toList();
  }

  String _fcfa(num value) => '${value.toStringAsFixed(0)} FCFA';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Mes revenus'),
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatGrid(),
                  const SizedBox(height: 20),
                  _buildRevenuePanel(),
                  const SizedBox(height: 20),
                  _buildHistoryPanel(),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------
  // Bandeau statistiques (3 tuiles)
  // ---------------------------------------------------------------
  Widget _buildStatGrid() {
    final isPositive = _weekComparison.startsWith('+');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.payments_outlined,
            value: _fcfa(_totalRevenue),
            label: 'Revenus encaissés',
            bg: AppTheme.green50,
            fg: AppTheme.green700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(
            icon: Icons.receipt_long_outlined,
            value: '${_payments.length}',
            label: 'Paiements',
            bg: AppTheme.teal50,
            fg: AppTheme.teal500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(
            icon: isPositive ? Icons.trending_up : Icons.trending_down,
            value: _weekComparison,
            label: 'vs semaine dern.',
            bg: AppTheme.amber50,
            fg: AppTheme.amber600,
          ),
        ),
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
                fontSize: 16,
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
            style: GoogleFonts.manrope(
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
  // Panneau revenus (total + graphique 7 jours)
  // ---------------------------------------------------------------
  Widget _buildRevenuePanel() {
    return _panel(
      title: 'Revenus · 7 jours',
      action: PcBadge(_weekComparison, tone: PcTone.green),
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
          _buildBarChart(),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final maxRevenue = _dailyRevenue.reduce(max);
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_dailyRevenue.length, (i) {
              final isLast = i == _dailyRevenue.length - 1;
              final fraction =
                  maxRevenue > 0 ? _dailyRevenue[i] / maxRevenue : 0.0;
              final opacity = isLast
                  ? 1.0
                  : (0.55 + (i / _dailyRevenue.length) * 0.45).clamp(0.0, 1.0);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 4,
                      right: isLast ? 0 : 4),
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: fraction.clamp(0.04, 1.0),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isLast
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [AppTheme.teal400, AppTheme.teal600],
                                ),
                          color: isLast ? AppTheme.amber400 : null,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5)),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_dayLabels.length, (i) {
            return Expanded(
              child: Text(
                _dayLabels[i],
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
  // Panneau historique des paiements (flush)
  // ---------------------------------------------------------------
  Widget _buildHistoryPanel() {
    return _panel(
      title: 'Historique des paiements',
      flush: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: _buildPaymentFilter(),
          ),
          if (_payments.isEmpty)
            const PcEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Aucun paiement',
              message:
                  'Vos paiements apparaîtront ici une fois vos livraisons réglées.',
            )
          else ...[
            for (int i = 0; i < _visiblePayments.length; i++) ...[
              if (i > 0) const PcDivider(),
              _buildPaymentRow(_visiblePayments[i]),
            ],
            if (_filteredPayments.length > _visiblePaymentsCount)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _visiblePaymentsCount += 10),
                  icon: const Icon(Icons.expand_more, size: 20),
                  label: Text(
                      'Voir plus (${_filteredPayments.length - _visiblePaymentsCount} restants)'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentFilter() {
    final filters = [
      {'key': 'all', 'label': 'Tous'},
      {'key': 'completed', 'label': 'Réglés'},
      {'key': 'pending', 'label': 'En attente'},
    ];

    return Row(
      children: filters.map((f) {
        final key = f['key']!;
        final label = f['label']!;
        final isActive = _paymentFilter == key;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() {
              _paymentFilter = key;
              _visiblePaymentsCount = 10;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary : AppTheme.cardColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? AppTheme.primary : AppTheme.slate200,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.slate500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPaymentRow(Map<String, dynamic> payment) {
    final amount = (payment['amount'] ?? 0).toDouble();
    final date = payment['createdAt']?.toString() ?? '';
    final method = payment['method']?.toString() ?? '';
    final status = payment['status']?.toString() ?? 'pending';
    final tracking = payment['trackingNumber']?.toString() ?? '';
    final isCompleted = status == 'completed' || status == 'confirmed';
    final subtitle =
        [_formatDate(date), if (method.isNotEmpty) method].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCompleted ? AppTheme.green50 : AppTheme.amber50,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              isCompleted ? Icons.payments_outlined : Icons.schedule_outlined,
              color: isCompleted ? AppTheme.green700 : AppTheme.amber600,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracking.isNotEmpty ? tracking : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.slate500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _fcfa(amount),
            style: AppTheme.mono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.teal600,
            ),
          ),
          const SizedBox(width: 10),
          PcBadge(
            isCompleted ? 'Réglé' : 'En attente',
            tone: isCompleted ? PcTone.green : PcTone.amber,
          ),
        ],
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
          if (flush)
            body
          else
            Padding(padding: const EdgeInsets.all(16), child: body),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }
}
