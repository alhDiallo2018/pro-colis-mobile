import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';
import 'score_detail_screen.dart';

class ScoresScreen extends ConsumerStatefulWidget {
  const ScoresScreen({super.key});

  @override
  ConsumerState<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends ConsumerState<ScoresScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _scores = [];
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
      final data = await _api.adminScores();
      setState(() { _scores = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _points(dynamic v) => '${v is int ? v : (int.tryParse('$v') ?? 0)} pts';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scores des chauffeurs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, tone: AppTheme.red400, title: 'Erreur', message: _error, action: PcButton('Réessayer', onPressed: _load))
              : _scores.isEmpty
                  ? const EmptyState(icon: Icons.emoji_events, title: 'Aucun score')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _scores.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = _scores[i];
                          final level = s['level']?.toString() ?? 'NEW';
                          final levelColors = {'ELITE': AppTheme.primary, 'PREMIUM': AppTheme.amber500, 'STANDARD': AppTheme.successColor, 'NEW': AppTheme.slate500};
                          final color = levelColors[level] ?? AppTheme.slate500;

                          return PcCard(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ScoreDetailScreen(
                                  userId: s['userId']?.toString() ?? '',
                                  driverName: s['driverName']?.toString() ?? s['fullName']?.toString() ?? '',
                                ),
                              ));
                            },
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(color: AppTheme.teal50, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.stars, color: AppTheme.primary, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['driverName']?.toString() ?? s['fullName']?.toString() ?? '', style: AppFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                      Text(s['garageName']?.toString() ?? '', style: AppFonts.manrope(fontSize: 12, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_points(s['points']), style: AppTheme.mono(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                                      child: Text(level, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
