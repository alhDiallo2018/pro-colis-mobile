// mobile/lib/screens/driver/revenus_screen.dart
// Écran Revenus du chauffeur - aligné Web

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Mes revenus',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStatRow(),
                  const SizedBox(height: 20),
                  _buildBarChart(),
                  const SizedBox(height: 24),
                  _buildPaymentFilter(),
                  const SizedBox(height: 16),
                  const Text('Historique des paiements',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  if (_payments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: AppTheme.slate300),
                          const SizedBox(height: 8),
                          Text('Aucun paiement',
                              style: TextStyle(color: AppTheme.slate500)),
                        ],
                      ),
                    )
                  else ...[
                    ..._visiblePayments.map((payment) => _buildPaymentCard(payment)),
                    if (_filteredPayments.length > _visiblePaymentsCount)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: () => setState(
                              () => _visiblePaymentsCount += 10),
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
            ),
    );
  }

  Widget _buildStatRow() {
    final isPositive = _weekComparison.startsWith('+');
    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            '${_totalRevenue.toStringAsFixed(0)} FCFA',
            'Total encaissé',
            AppTheme.successColor,
            Icons.account_balance_wallet_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatBox(
            '${_payments.length}',
            'Nb de paiements',
            AppTheme.primary,
            Icons.receipt_long_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatBox(
            _weekComparison,
            'Évolution hebdo',
            AppTheme.warningColor,
            isPositive ? Icons.trending_up : Icons.trending_down,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String value, String label, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity( 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.mono(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final maxRevenue = _dailyRevenue.reduce(max);
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenus des 7 derniers jours',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(7, (index) {
            final isToday = index == 6;
            final fraction = maxRevenue > 0 ? _dailyRevenue[index] / maxRevenue : 0.0;
            final barColor = isToday
                ? AppTheme.warningColor
                : Color.lerp(AppTheme.teal500, AppTheme.successColor, index / 6.0)!;

            return Padding(
              padding: EdgeInsets.only(bottom: index < 6 ? 6 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          days[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                            color: isToday ? AppTheme.warningColor : AppTheme.slate500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.slate100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: fraction.clamp(0.02, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isToday
                                      ? [AppTheme.amber400, AppTheme.warningColor]
                                      : [barColor, barColor.withOpacity( 0.7)],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text(
                          '${_dailyRevenue[index].toStringAsFixed(0)} FCFA',
                          textAlign: TextAlign.right,
                          style: AppTheme.mono(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isToday ? AppTheme.warningColor : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
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
                style: TextStyle(
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

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final amount = (payment['amount'] ?? 0).toDouble();
    final date = payment['createdAt']?.toString() ?? '';
    final method = payment['method']?.toString() ?? 'N/A';
    final status = payment['status']?.toString() ?? 'pending';
    final tracking = payment['trackingNumber']?.toString() ?? '';
    final isCompleted = status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.softShadow(alpha: 0.04),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCompleted ? AppTheme.green50 : AppTheme.amber50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_outline : Icons.schedule_outlined,
              color: isCompleted ? AppTheme.successColor : AppTheme.warningColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$amount FCFA',
                        style: AppTheme.mono(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (tracking.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '#$tracking',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.slate400,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.slate400),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(date),
                      style: TextStyle(fontSize: 12, color: AppTheme.slate400),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.payment_outlined, size: 12, color: AppTheme.slate400),
                    const SizedBox(width: 4),
                    Text(
                      method,
                      style: TextStyle(fontSize: 12, color: AppTheme.slate400),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCompleted ? AppTheme.green50 : AppTheme.amber50,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.successColor : AppTheme.warningColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isCompleted ? 'Réglé' : 'En attente',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
              ],
            ),
          ),
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
