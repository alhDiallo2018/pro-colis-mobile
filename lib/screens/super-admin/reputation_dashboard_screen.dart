import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class ReputationDashboardScreen extends ConsumerStatefulWidget {
  const ReputationDashboardScreen({super.key});

  @override
  ConsumerState<ReputationDashboardScreen> createState() => _ReputationDashboardScreenState();
}

class _ReputationDashboardScreenState extends ConsumerState<ReputationDashboardScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _dash;
  List<Map<String, dynamic>> _rankings = [];
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
      final dash = await _api.reputationDashboard();
      final ranks = await _api.adminDriverRanking();
      setState(() { _dash = dash; _rankings = ranks; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  int _num(dynamic v) => (v is num) ? v.toInt() : (int.tryParse('$v') ?? 0);

  @override
  Widget build(BuildContext context) {
    final top5 = _rankings.take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Réputation')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, tone: AppTheme.red400, title: 'Erreur', message: _error, action: PcButton('Réessayer', onPressed: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_dash != null) _statsGrid(),
                      const SizedBox(height: 20),
                      if (top5.isNotEmpty) ...[
                        Text('Top 5 · Classement réputation', style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 10),
                        ...List.generate(top5.length, (i) => _rankTile(top5[i], i)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _statsGrid() {
    final d = _dash!;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _statBox('Élite', Icons.emoji_events, AppTheme.primary, '${_num(d['eliteCount'])}'),
        _statBox('Premium', Icons.workspace_premium, AppTheme.amber500, '${_num(d['premiumCount'])}'),
        _statBox('Standard', Icons.verified, AppTheme.successColor, '${_num(d['standardCount'])}'),
        _statBox('Nouveaux', Icons.person_add, AppTheme.slate500, '${_num(d['newCount'])}'),
        _statBox('Note moy.', Icons.star, AppTheme.amber500, (d['averageRating'] as num?)?.toStringAsFixed(1) ?? '-'),
        _statBox('Total', Icons.group, AppTheme.teal500, '${_num(d['totalDrivers'])}'),
      ],
    );
  }

  Widget _statBox(String label, IconData icon, Color color, String value) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: PcCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value, style: AppFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            Text(label, style: AppFonts.manrope(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _rankTile(Map<String, dynamic> r, int index) {
    final level = r['level']?.toString() ?? 'NEW';
    final levelColors = {'ELITE': AppTheme.primary, 'PREMIUM': AppTheme.amber500, 'STANDARD': AppTheme.successColor, 'NEW': AppTheme.slate500};
    final colors = levelColors[level] ?? AppTheme.slate500;
    final rank = index + 1;
    final rankColor = rank == 1 ? AppTheme.amber600 : rank == 2 ? AppTheme.slate500 : rank == 3 ? AppTheme.amber700 : AppTheme.slate400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: PcCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('#$rank', style: AppFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: rankColor)),
            ),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(
                (r['fullName']?.toString() ?? '?')[0].toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['fullName']?.toString() ?? '', style: AppFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  Text(r['garageName']?.toString() ?? '—', style: AppFonts.manrope(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: colors.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
              child: Text(level, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors)),
            ),
            const SizedBox(width: 8),
            Text('${r['points'] ?? 0} pts', style: AppTheme.mono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}
