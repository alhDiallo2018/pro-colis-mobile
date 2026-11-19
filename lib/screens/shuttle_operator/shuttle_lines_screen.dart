// lib/screens/shuttle_operator/shuttle_lines_screen.dart
//
// SCP-007 — CRUD des lignes de transit de l'opérateur. Chaque ligne est
// créée avec au moins deux arrêts. Les zones référencées doivent exister
// côté backend : le payload stop demande `zoneId` (UUID connu). Pour éviter
// un picker zone complet ici (qui exigerait un autre endpoint zones), on
// laisse l'opérateur saisir l'UUID zone — le dashboard Web reste l'outil
// principal d'édition.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shuttle_operator_provider.dart';
import '../../services/api/shuttle_operator_api.dart';

class ShuttleLinesScreen extends ConsumerWidget {
  const ShuttleLinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shuttleLinesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lignes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(shuttleLinesProvider)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shuttleLinesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(err.toString())),
          data: (lines) {
            if (lines.isEmpty) {
              return const _Empty(
                icon: Icons.route,
                title: 'Aucune ligne',
                message: 'Créez votre première ligne de transit.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lines.length,
              itemBuilder: (_, i) => _LineCard(
                line: lines[i],
                onEdit: () => _openEditor(context, ref, line: lines[i]),
                onDelete: () => _confirmDelete(context, ref, lines[i]),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ShuttleLine line) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la ligne ?'),
        content: Text('« ${line.name} » et ses horaires seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(shuttleOperatorApiProvider).deleteLine(line.id);
      ref.invalidate(shuttleLinesProvider);
      ref.invalidate(shuttleOverviewProvider);
    } catch (err) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec : $err')));
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {ShuttleLine? line}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _LineEditor(line: line),
      ),
    );
    if (result == true) {
      ref.invalidate(shuttleLinesProvider);
      ref.invalidate(shuttleOverviewProvider);
    }
  }
}

class _LineCard extends StatelessWidget {
  final ShuttleLine line;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LineCard({required this.line, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(line.number)),
        title: Text(line.name),
        subtitle: Text('${line.operator.toUpperCase()} · ${line.origin} → ${line.destination} · ${line.direction}'),
        children: [
          ...line.stops.map((s) => ListTile(
                dense: true,
                leading: Text('${s.order}', style: const TextStyle(fontWeight: FontWeight.bold)),
                title: Text(s.label),
                subtitle: Text(s.zoneId, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              )),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit), label: const Text('Modifier')),
              TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline), label: const Text('Supprimer')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineEditor extends ConsumerStatefulWidget {
  final ShuttleLine? line;

  const _LineEditor({this.line});

  @override
  ConsumerState<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends ConsumerState<_LineEditor> {
  late final TextEditingController _number;
  late final TextEditingController _name;
  late final TextEditingController _origin;
  late final TextEditingController _destination;
  late String _operator;
  late String _direction;
  late List<_StopDraft> _stops;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final l = widget.line;
    _number = TextEditingController(text: l?.number ?? '');
    _name = TextEditingController(text: l?.name ?? '');
    _origin = TextEditingController(text: l?.origin ?? '');
    _destination = TextEditingController(text: l?.destination ?? '');
    _operator = l?.operator ?? kTransitOperators.first;
    _direction = l?.direction ?? kTransitDirections.first;
    _stops = l?.stops
            .map((s) => _StopDraft(order: s.order, label: s.label, zoneId: s.zoneId))
            .toList() ??
        [_StopDraft.empty(1), _StopDraft.empty(2)];
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _origin.dispose();
    _destination.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.line != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(_isEdit ? 'Modifier ligne' : 'Nouvelle ligne', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 10),
            _dropdown('Opérateur', _operator, kTransitOperators, (v) => setState(() => _operator = v!)),
            const SizedBox(height: 10),
            _dropdown('Direction', _direction, kTransitDirections, (v) => setState(() => _direction = v!)),
            const SizedBox(height: 10),
            TextField(controller: _number, decoration: const InputDecoration(labelText: 'Numéro', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _origin, decoration: const InputDecoration(labelText: 'Origine', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _destination, decoration: const InputDecoration(labelText: 'Destination', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Arrêts (${_stops.length})', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(onPressed: _addStop, icon: const Icon(Icons.add_circle_outline)),
              ],
            ),
            ...List.generate(_stops.length, (i) => _buildStop(i)),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Enregistrer' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.toUpperCase()))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildStop(int i) {
    final draft = _stops[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: TextField(
              controller: draft.orderCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '#', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: TextField(
              controller: draft.labelCtrl,
              decoration: const InputDecoration(labelText: 'Nom arrêt', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: TextField(
              controller: draft.zoneIdCtrl,
              decoration: const InputDecoration(labelText: 'Zone UUID', border: OutlineInputBorder()),
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
          IconButton(onPressed: _stops.length > 2 ? () => setState(() => _stops.removeAt(i)) : null, icon: const Icon(Icons.remove_circle_outline)),
        ],
      ),
    );
  }

  void _addStop() {
    setState(() => _stops.add(_StopDraft.empty(_stops.length + 1)));
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final parsed = <ShuttleLineStop>[];
      for (final d in _stops) {
        final order = int.tryParse(d.orderCtrl.text.trim());
        if (order == null || order < 1) {
          throw 'Ordre invalide (entier >=1)';
        }
        final label = d.labelCtrl.text.trim();
        final zone = d.zoneIdCtrl.text.trim();
        if (label.isEmpty || zone.isEmpty) throw 'Nom et zone requis sur chaque arrêt';
        parsed.add(ShuttleLineStop(order: order, label: label, zoneId: zone));
      }
      final api = ref.read(shuttleOperatorApiProvider);
      if (_isEdit) {
        await api.updateLine(widget.line!.id, {
          'name': _name.text.trim(),
          'number': _number.text.trim(),
          'direction': _direction,
          'origin': _origin.text.trim(),
          'destination': _destination.text.trim(),
          'stops': parsed.map((s) => s.toJson()).toList(),
        });
      } else {
        await api.createLine(
          operator: _operator,
          number: _number.text.trim(),
          direction: _direction,
          name: _name.text.trim(),
          origin: _origin.text.trim(),
          destination: _destination.text.trim(),
          stops: parsed,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StopDraft {
  final TextEditingController orderCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController zoneIdCtrl;

  _StopDraft({required int order, required String label, required String zoneId})
      : orderCtrl = TextEditingController(text: '$order'),
        labelCtrl = TextEditingController(text: label),
        zoneIdCtrl = TextEditingController(text: zoneId);

  factory _StopDraft.empty(int order) => _StopDraft(order: order, label: '', zoneId: '');
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _Empty({required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        Icon(icon, size: 60, color: Theme.of(context).disabledColor),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
