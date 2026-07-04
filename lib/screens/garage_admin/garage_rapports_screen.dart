// mobile/lib/screens/garage_admin/garage_rapports_screen.dart
// Rapports / Statistiques pour Admin Garage

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/parcel.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

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
  double get _successRate => _totalParcels > 0
      ? (_deliveredCount / _totalParcels) * 100
      : 0;

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
        title: const Text('Rapports',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildStatBoxes(),
                        const SizedBox(height: 24),
                        _buildSevenDayChart(),
                        const SizedBox(height: 24),
                        _buildStatusDistributionChart(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
          const SizedBox(height: 16),
          Text('Erreur: $_error',
              style: const TextStyle(color: AppTheme.slate500),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // ---- 2x2 Stat Boxes ----

  Widget _buildStatBoxes() {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      children: [
        _StatBox(
          icon: Icons.inventory,
          value: _totalParcels.toString(),
          label: 'Colis traités',
          accent: AppTheme.teal500,
        ),
        _StatBox(
          icon: Icons.check_circle,
          value: _deliveredCount.toString(),
          label: 'Colis livrés',
          accent: AppTheme.green600,
        ),
        _StatBox(
          icon: Icons.cancel,
          value: _cancelledCount.toString(),
          label: 'Colis annulés',
          accent: AppTheme.red400,
        ),
        _StatBox(
          icon: Icons.trending_up,
          value: '${_successRate.toStringAsFixed(1)}%',
          label: 'Taux de réussite',
          accent: AppTheme.amber400,
        ),
      ],
    );
  }

  // ---- 7-Day Activity Bar Chart ----

  Widget _buildSevenDayChart() {
    final days = _sevenDayActivity;
    final maxCount =
        days.fold<int>(0, (max, d) => (d['count'] as int) > max ? d['count'] as int : max);
    final effectiveMax = maxCount > 0 ? maxCount : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activité des 7 derniers jours',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...days.map((day) {
            final count = day['count'] as int;
            final fraction = count / effectiveMax;
            final label = day['label'] as String;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.slate600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusXs),
                        gradient: const LinearGradient(
                          colors: [AppTheme.teal500, AppTheme.green600],
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXs),
                            gradient: const LinearGradient(
                              colors: [AppTheme.teal500, AppTheme.green600],
                            ),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 8),
                          child: count > 0
                              ? Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---- Status Distribution Chart ----

  Widget _buildStatusDistributionChart() {
    final distribution = _statusDistribution;
    final entries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue =
        entries.fold<int>(0, (max, e) => e.value > max ? e.value : max);
    final effectiveMax = maxValue > 0 ? maxValue : 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition par statut',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            final status = entry.key;
            final count = entry.value;
            final fraction = count / effectiveMax;
            final statusColors = AppTheme.statusColors(status);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColors.dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.slate600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXs),
                      color: AppTheme.slate100,
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusXs),
                          color: statusColors.dot,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==================== STAT BOX WIDGET ====================

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity( 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: accent.withOpacity( 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity( 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.slate500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
