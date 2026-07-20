import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pc_components.dart';

class ScoreDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  final String driverName;

  const ScoreDetailScreen({super.key, required this.userId, this.driverName = ''});

  @override
  ConsumerState<ScoreDetailScreen> createState() => _ScoreDetailScreenState();
}

class _ScoreDetailScreenState extends ConsumerState<ScoreDetailScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _score;
  List<Map<String, dynamic>> _history = [];
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
      final s = await _api.adminScoreDetail(widget.userId);
      final h = await _api.adminScoreHistory(widget.userId);
      setState(() { _score = s; _history = h; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _points(dynamic v) => '${v is int ? v : (int.tryParse('$v') ?? 0)} pts';

  Future<void> _showPointsDialog(bool add) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(add ? 'Ajouter des points' : 'Retirer des points'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nombre de points'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) return;
              final data = {'amount': amount, 'description': descCtrl.text};
              final res = add
                  ? await _api.adminAddPoints(widget.userId, data)
                  : await _api.adminRemovePoints(widget.userId, data);
              if (res['success'] == true) {
                if (ctx.mounted) Navigator.pop(ctx, true);
              }
            },
            child: Text(add ? 'Ajouter' : 'Retirer'),
          ),
        ],
      ),
    );
    if (r == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.driverName.isNotEmpty
        ? widget.driverName
        : (_score?['driverName']?.toString() ?? _score?['fullName']?.toString() ?? 'Chauffeur');

    return Scaffold(
      appBar: AppBar(title: Text('Score de $name')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.error_outline, tone: AppTheme.red400, title: 'Erreur', message: _error, action: PcButton('Réessayer', onPressed: _load))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_score != null) _scoreHeader(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Ajouter'),
                              onPressed: () => _showPointsDialog(true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.remove, size: 18),
                              label: const Text('Retirer'),
                              onPressed: () => _showPointsDialog(false),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorColor, side: const BorderSide(color: AppTheme.errorColor)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Historique', style: AppFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 10),
                      if (_history.isEmpty)
                        const EmptyState(icon: Icons.history, title: 'Aucun historique')
                      else
                        ..._history.map(_txTile),
                    ],
                  ),
                ),
    );
  }

  Widget _scoreHeader() {
    final s = _score!;
    final level = s['level']?.toString() ?? 'NEW';
    final levelColors = {'ELITE': AppTheme.primary, 'PREMIUM': AppTheme.amber500, 'STANDARD': AppTheme.successColor, 'NEW': AppTheme.slate500};
    final color = levelColors[level] ?? AppTheme.slate500;

    return PcCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(99)),
            child: Text(level, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 12),
          Text(_points(s['points']), style: AppTheme.mono(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _miniStat('Total gagné', _points(s['totalEarned']), AppTheme.successColor),
              _miniStat('Total dépensé', _points(s['totalSpent']), AppTheme.amber500),
              if (s['rating'] != null) _miniStat('Note', (s['rating'] as num).toStringAsFixed(1), AppTheme.amber400),
              if (s['totalDeliveries'] != null) _miniStat('Livraisons', '${s['totalDeliveries']}', AppTheme.primary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: AppFonts.manrope(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _txTile(Map<String, dynamic> tx) {
    final amount = (tx['amount'] is int) ? tx['amount'] as int : (int.tryParse('${tx['amount']}') ?? 0);
    final isCredit = amount > 0 || tx['type'] == 'earn' || tx['type'] == 'add';
    final type = tx['type']?.toString() ?? 'ajustement';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PcCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                size: 18, color: isCredit ? AppTheme.green600 : AppTheme.red400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tx['description']?.toString() ?? type, style: AppFonts.manrope(fontSize: 13, color: AppTheme.textPrimary)),
            ),
            Text(
              '${isCredit ? '+' : '-'}${amount.abs()} pts',
              style: AppTheme.mono(fontSize: 14, fontWeight: FontWeight.w700,
                  color: isCredit ? AppTheme.green600 : AppTheme.red400),
            ),
          ],
        ),
      ),
    );
  }
}
