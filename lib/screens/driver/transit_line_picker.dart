// Bottom sheet Citymapper-style : opérateur → ligne → direction.
// Résultat : une TransitLineSummary à injecter dans l'écran parent pour
// pré-remplir un départ via l'endpoint /transit/lines/:id/draft.
import 'package:flutter/material.dart';
import '../../services/api/client.dart';
import '../../services/api/transit_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/transit/line_badge.dart' as ui;

class TransitLinePickerSheet extends StatefulWidget {
  final TransitLineSummary? initial;
  const TransitLinePickerSheet({super.key, this.initial});

  static Future<TransitLineSummary?> show(BuildContext context, {TransitLineSummary? initial}) {
    return showModalBottomSheet<TransitLineSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.6, expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: TransitLinePickerSheet(initial: initial),
        ),
      ),
    );
  }

  @override
  State<TransitLinePickerSheet> createState() => _TransitLinePickerSheetState();
}

class _TransitLinePickerSheetState extends State<TransitLinePickerSheet> {
  late final TransitApi _api = TransitApi(ApiClient());
  TransitOperator? _operator;
  String _search = '';
  late Future<List<TransitLineSummary>> _future;
  List<TransitLineSummary> _lines = const [];

  @override
  void initState() {
    super.initState();
    _operator = widget.initial?.operator;
    _refresh();
  }

  void _refresh() {
    _future = _operator == null ? Future.value(const []) : _api.listLines(operator: _operator);
    _future.then((v) { if (mounted) setState(() => _lines = v); });
  }

  List<TransitLineSummary> get _filtered {
    if (_search.trim().isEmpty) return _lines;
    final q = _search.trim().toLowerCase();
    return _lines.where((l) =>
        l.number.toLowerCase().contains(q) ||
        l.origin.toLowerCase().contains(q) ||
        l.destination.toLowerCase().contains(q)).toList();
  }

  // Regroupe aller + retour par numéro pour un affichage côte à côte.
  Map<String, List<TransitLineSummary>> get _grouped {
    final map = <String, List<TransitLineSummary>>{};
    for (final l in _filtered) {
      map.putIfAbsent('${operatorToString(l.operator)}-${l.number}', () => []).add(l);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(
            width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Text('Choisir une ligne', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text('Catalogue officiel DDD / AFTU · 96 lignes',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),

          _operatorStep(),
          if (_operator != null) ...[
            const SizedBox(height: 16),
            _lineStep(),
          ],
        ],
      ),
    );
  }

  Widget _operatorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepLabel('1 · Opérateur'),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final op in TransitOperator.values)
            InkWell(
              onTap: () { setState(() => _operator = op); _refresh(); },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 1.5,
                    color: _operator == op ? Colors.black : AppTheme.slate300),
                  color: _operator == op ? AppTheme.backgroundColor : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ui.LineBadge(
                    operator: op == TransitOperator.ddd ? ui.TransitOperator.ddd : ui.TransitOperator.aftu,
                    number: op == TransitOperator.ddd ? 'DDD' : 'AFTU',
                  ),
                  const SizedBox(width: 10),
                  Text(
                    op == TransitOperator.ddd ? 'Dakar Dem Dikk' : 'AFTU — Tata',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ]),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _lineStep() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepLabel('2 · Ligne'),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Rechercher par numéro ou terminus…',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.slate300)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<TransitLineSummary>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Catalogue indisponible. Utilise un trajet habituel ou le CSV.',
                      style: TextStyle(color: Colors.red.shade700)));
                }
                final grouped = _grouped;
                if (grouped.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Aucune ligne trouvée.',
                      style: TextStyle(color: AppTheme.textSecondary)));
                }
                return ListView(
                  controller: PrimaryScrollController.maybeOf(context),
                  children: [
                    for (final entry in grouped.entries)
                      _lineGroupCard(entry.value),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineGroupCard(List<TransitLineSummary> group) {
    final first = group.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border.all(color: AppTheme.slate300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ui.LineBadge(
            operator: first.operator == TransitOperator.ddd ? ui.TransitOperator.ddd : ui.TransitOperator.aftu,
            number: first.number,
            size: ui.LineBadgeSize.lg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${first.origin} → ${first.destination}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textBody)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  for (final l in group)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(l),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: BorderSide(color: AppTheme.slate300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        l.direction == TransitDirection.aller ? 'Aller' : 'Retour',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  if (group.length == 1)
                    Text('1 sens connu',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLabel(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontWeight: FontWeight.w700, fontSize: 12,
      letterSpacing: 0.08, color: AppTheme.textSecondary),
  );
}
