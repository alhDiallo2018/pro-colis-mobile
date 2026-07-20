import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class DriverDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const DriverDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends ConsumerState<DriverDetailScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await _api.adminDriverDetail(widget.userId);
      setState(() { _detail = d; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fcfa(dynamic v) {
    final n = (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
    return '${n.toStringAsFixed(0)} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final user = _detail?['user'];
    final name = user?['fullName']?.toString() ?? 'Chauffeur';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        bottom: _detail != null ? TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.slate500,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'Réputation'), Tab(text: 'Finance')],
        ) : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, tone: AppTheme.red400, title: 'Erreur', message: _error, action: PcButton('Réessayer', onPressed: _load))
              : TabBarView(
                  controller: _tabController,
                  children: [_reputationTab(), _financeTab()],
                ),
    );
  }

  Widget _reputationTab() {
    final user = _detail?['user'] ?? {};
    final score = _detail?['score'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (user.isNotEmpty) ...[
          PcCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Text(
                    (user['fullName']?.toString() ?? '?')[0].toUpperCase(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user['fullName']?.toString() ?? '', style: AppFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                Text(user['phone']?.toString() ?? '', style: AppFonts.manrope(fontSize: 14, color: AppTheme.textSecondary)),
                if (user['garageName'] != null) Text(user['garageName'].toString(), style: AppFonts.manrope(fontSize: 13, color: AppTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (score != null) ...[
          Text('Score', style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          PcCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('${score['points'] ?? 0} pts', style: AppTheme.mono(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniStat('Total gagné', '${score['totalEarned'] ?? 0}', AppTheme.successColor),
                    _miniStat('Total dépensé', '${score['totalSpent'] ?? 0}', AppTheme.amber500),
                  ],
                ),
                if (score['level'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.teal50, borderRadius: BorderRadius.circular(99)),
                    child: Text(score['level'].toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.teal700)),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (user['rating'] != null) ...[
          const SizedBox(height: 16),
          PcCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.star, color: AppTheme.amber500, size: 22),
                const SizedBox(width: 10),
                Text('${(user['rating'] as num).toStringAsFixed(1)} / 5', style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const Spacer(),
                Text('${user['totalDeliveries'] ?? 0} livraisons', style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _financeTab() {
    final wallet = _detail?['wallet'];
    if (wallet == null) return const EmptyState(icon: Icons.wallet, title: 'Aucun wallet');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PcCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('Solde wallet', style: AppFonts.manrope(fontSize: 13, color: AppTheme.textSecondary)),
              Text(_fcfa(wallet['balance']), style: AppTheme.mono(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.successColor)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _miniStat('Total rechargé', _fcfa(wallet['totalDeposited']), AppTheme.primary),
                  _miniStat('Total dépensé', _fcfa(wallet['totalSpent']), AppTheme.amber500),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: wallet['status'] == 'active' ? AppTheme.green50 : AppTheme.slate100,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(wallet['status']?.toString() ?? 'inconnu',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: wallet['status'] == 'active' ? AppTheme.green600 : AppTheme.slate500)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: AppFonts.manrope(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
