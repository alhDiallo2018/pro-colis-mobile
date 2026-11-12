import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';
import 'score_detail_screen.dart';

/// Les 4 niveaux acceptés par `/super-admin/scores?level=` côté serveur.
/// Un filtre sans valeur (`null`) signifie « tous niveaux ».
const _levels = <String>['ELITE', 'PREMIUM', 'STANDARD', 'NEW'];

class ScoresScreen extends ConsumerStatefulWidget {
  const ScoresScreen({super.key});

  @override
  ConsumerState<ScoresScreen> createState() => _ScoresScreenState();
}

class _ScoresScreenState extends ConsumerState<ScoresScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _scores = [];
  bool _loading = true;
  String? _error;
  String? _level;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.adminScoresPage(
        page: _page,
        limit: _pageSize,
        level: _level,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _scores = result.scores;
        _total = result.total;
        _totalPages = result.totalPages;
        _page = result.page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _load();
    });
  }

  void _setLevel(String? level) {
    setState(() {
      _level = level;
      _page = 1;
    });
    _load();
  }

  String _points(dynamic v) =>
      '${v is int ? v : (int.tryParse('$v') ?? 0)} pts';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scores des chauffeurs')),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildList()),
          if (_scores.isNotEmpty && _totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppTheme.cardColor,
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Rechercher un chauffeur (nom, téléphone)',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _page = 1;
                        _load();
                      },
                    ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Tous', _level == null, () => _setLevel(null)),
                for (final l in _levels) ...[
                  const SizedBox(width: 6),
                  _chip(l, _level == l, () => _setLevel(l)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        tone: AppTheme.red400,
        title: 'Erreur',
        message: _error,
        action: PcButton('Réessayer', onPressed: _load),
      );
    }
    if (_scores.isEmpty) {
      return const EmptyState(
        icon: Icons.emoji_events,
        title: 'Aucun score',
        message: 'Aucun chauffeur ne correspond à ce filtre.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _scores.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildTile(_scores[i]),
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> s) {
    final level = s['level']?.toString() ?? 'NEW';
    final levelColors = {
      'ELITE': AppTheme.primary,
      'PREMIUM': AppTheme.amber500,
      'STANDARD': AppTheme.successColor,
      'NEW': AppTheme.slate500,
    };
    final color = levelColors[level] ?? AppTheme.slate500;

    return PcCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScoreDetailScreen(
              userId: s['userId']?.toString() ?? '',
              driverName: s['driverName']?.toString() ??
                  s['fullName']?.toString() ??
                  '',
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.teal50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.stars, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['driverName']?.toString() ??
                      s['fullName']?.toString() ??
                      '',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  s['garageName']?.toString() ??
                      s['zoneName']?.toString() ??
                      '',
                  style: AppFonts.manrope(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _points(s['points']),
                style: AppTheme.mono(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Page précédente',
            onPressed: _page > 1 && !_loading
                ? () {
                    _page -= 1;
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Page $_page / $_totalPages · $_total chauffeurs',
                style: AppFonts.manrope(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Page suivante',
            onPressed: _page < _totalPages && !_loading
                ? () {
                    _page += 1;
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
