import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';
import 'driver_detail_screen.dart';

class ClassementScreen extends ConsumerStatefulWidget {
  const ClassementScreen({super.key});

  @override
  ConsumerState<ClassementScreen> createState() => _ClassementScreenState();
}

class _ClassementScreenState extends ConsumerState<ClassementScreen> {
  final ApiService _api = ApiService();
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
      final data = await _api.adminDriverRanking();
      setState(() { _rankings = data; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _points(dynamic v) => '${v is int ? v : (int.tryParse('$v') ?? 0)} pts';

  @override
  Widget build(BuildContext context) {
    final top3 = _rankings.take(3).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Classement chauffeurs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, tone: AppTheme.red400, title: 'Erreur', message: _error, action: PcButton('Réessayer', onPressed: _load))
              : _rankings.isEmpty
                  ? const EmptyState(icon: Icons.emoji_events, title: 'Aucun classement')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (top3.length >= 3) _podium(top3),
                          if (top3.length >= 3) const SizedBox(height: 20),
                          Text('Classement complet', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const SizedBox(height: 10),
                          ..._rankings.map((r) {
                            final rank = r['rank'] as int? ?? 1;
                            final level = r['level']?.toString() ?? 'NEW';
                            final levelColors = {'ELITE': AppTheme.primary, 'PREMIUM': AppTheme.amber500, 'STANDARD': AppTheme.successColor, 'NEW': AppTheme.slate500};
                            final color = levelColors[level] ?? AppTheme.slate500;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: PcCard(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => DriverDetailScreen(userId: r['userId']?.toString() ?? ''),
                                  ));
                                },
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      child: Text('#$rank', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.slate500)),
                                    ),
                                    CircleAvatar(radius: 14, backgroundColor: AppTheme.primary.withOpacity(0.1),
                                        child: Text((r['fullName']?.toString() ?? '?')[0].toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary))),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(r['fullName']?.toString() ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
                                      child: Text(level, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_points(r['points']), style: AppTheme.mono(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }

  Widget _podium(List<Map<String, dynamic>> top3) {
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _podiumCard(top3[1], 2, 140), // 2nd
          _podiumCard(top3[0], 1, 180), // 1st
          _podiumCard(top3[2], 3, 120), // 3rd
        ].map((w) => Expanded(child: w)).toList(),
      ),
    );
  }

  Widget _podiumCard(Map<String, dynamic> r, int rank, double height) {
    final colors = [AppTheme.amber500, AppTheme.slate400, AppTheme.amber700];
    final color = colors[rank - 1];
    final name = r['fullName']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(name.split(' ').first, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(_points(r['points']), style: AppTheme.mono(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(0.6), color]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Center(
              child: Text('#$rank', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
