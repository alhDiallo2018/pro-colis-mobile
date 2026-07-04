// mobile/lib/screens/driver/revenus_screen.dart
// Écran Revenus du chauffeur - aligné Web

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
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

  static const List<double> _dailyRevenue = [
    12500, // Lundi
    8700,  // Mardi
    15600, // Mercredi
    5200,  // Jeudi
    18200, // Vendredi
    22300, // Samedi
    9400,  // Dimanche
  ];

  static const List<String> _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const List<String> _dayFullLabels = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
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
                  _buildRevenueChart(),
                  const SizedBox(height: 24),

                  // Stats card
                  _buildStatsCard(),
                  const SizedBox(height: 24),

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
                  else
                    ..._payments.map((payment) {
                      final amount = (payment['amount'] ?? 0).toDouble();
                      final date = payment['createdAt']?.toString() ?? '';
                      final method = payment['method']?.toString() ?? 'N/A';
                      final status =
                          payment['status']?.toString() ?? 'pending';
                      final tracking =
                          payment['trackingNumber']?.toString() ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.slate200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.green50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.payments_outlined,
                                  color: AppTheme.green600, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$amount FCFA',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tracking.isNotEmpty
                                        ? 'Colis #$tracking'
                                        : method,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.slate500),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'completed'
                                        ? AppTheme.green50
                                        : AppTheme.amber50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status == 'completed' ? 'Payé' : 'En cours',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: status == 'completed'
                                            ? AppTheme.green600
                                            : AppTheme.amber700),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(_formatDate(date),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.slate400)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildRevenueChart() {
    final maxRevenue = _dailyRevenue.reduce(max);
    final maxHeight = 160.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0FA958), Color(0xFF018982), Color(0xFF0C6E7D)],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenus',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_totalRevenue.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Cette semaine',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: maxHeight + 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final height =
                    (_dailyRevenue[index] / maxRevenue) * maxHeight;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.01),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _dayLabels[index],
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _revenueStatBox(
                '${_currentWeekRevenue.toStringAsFixed(0)} FCFA',
                'Revenus encaissés',
              ),
              const SizedBox(width: 10),
              _revenueStatBox(
                '${_payments.length}',
                'Paiements',
              ),
              const SizedBox(width: 10),
              _revenueStatBox(
                _weekComparison,
                'vs semaine dernière',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _revenueStatBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final user = ref.watch(authProvider).user;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            '${_totalRevenue.toStringAsFixed(0)} FCFA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Revenus totaux',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statCard('${_payments.length}', 'Paiements'),
              const SizedBox(width: 12),
              _statCard(
                  '${user?.completedDeliveries ?? 0}', 'Livraisons'),
              const SizedBox(width: 12),
              _statCard(
                  '${user?.rating?.toStringAsFixed(1) ?? 0}', 'Note'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
          ],
        ),
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
