import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class FinanceDashboardScreen extends ConsumerStatefulWidget {
  const FinanceDashboardScreen({super.key});

  @override
  ConsumerState<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends ConsumerState<FinanceDashboardScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.financeDashboard();
      setState(() { _dashboard = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int _num(dynamic v) => (v is num) ? v.toInt() : (int.tryParse('$v') ?? 0);
  double _d(dynamic v) => (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);

  String _fcfa(dynamic v) {
    final n = _d(v);
    return '${n.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord financier')),
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
              : _dashboard == null || _dashboard!.isEmpty
                  ? const EmptyState(
                      icon: Icons.account_balance_wallet,
                      title: 'Aucune donnée',
                      message: 'Les données financières ne sont pas disponibles.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(18),
                        children: [
                          _statGrid(_dashboard!),
                        ],
                      ),
                    ),
    );
  }

  Widget _statGrid(Map<String, dynamic> d) {
    final stats = <_StatItem>[
      _StatItem('Wallets', Icons.wallet, AppTheme.primary, '${_num(d['totalWallets'])}', 'Total Wallets'),
      _StatItem('Solde Total', Icons.account_balance_wallet, AppTheme.successColor, _fcfa(d['totalBalance']), ''),
      _StatItem('Total Rechargé', Icons.trending_up, AppTheme.teal400, _fcfa(d['totalDeposited']), ''),
      _StatItem('Commissions Mois', Icons.percent, AppTheme.amber500, _fcfa(d['commissionsMonth']), 'Ce mois'),
      _StatItem('Recharges Mois', Icons.add_card, AppTheme.primary, _fcfa(d['depositsMonth']), 'Ce mois'),
      _StatItem('Wallets Faibles', Icons.warning_amber, AppTheme.red400, '${_num(d['walletsLow'])}', '<500 FCFA'),
      _StatItem('Wallets Inactifs', Icons.hourglass_disabled, AppTheme.slate500, '${_num(d['walletsInactive'])}', 'Inactifs'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats.map(_statBox).toList(),
    );
  }

  Widget _statBox(_StatItem item) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: PcCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 18, color: item.color),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.value,
              style: AppFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final IconData icon;
  final Color color;
  final String value;
  final String sublabel;
  const _StatItem(this.label, this.icon, this.color, this.value, this.sublabel);
}
