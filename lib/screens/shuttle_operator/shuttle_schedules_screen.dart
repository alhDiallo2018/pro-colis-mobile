// lib/screens/shuttle_operator/shuttle_schedules_screen.dart
//
// SCP-007 — CRUD horaires navette : jours de la semaine (multi-sélection)
// + heure de départ (HH:MM) + fenêtre active. Nécessite au moins une ligne
// pour le select transitLine.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shuttle_operator_provider.dart';
import '../../services/api/shuttle_operator_api.dart';

class ShuttleSchedulesScreen extends ConsumerWidget {
  const ShuttleSchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shuttleSchedulesProvider);
    final linesAsync = ref.watch(shuttleLinesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horaires'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(shuttleSchedulesProvider)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shuttleSchedulesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(err.toString())),
          data: (schedules) {
            if (schedules.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Aucun horaire configuré.')));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: schedules.length,
              itemBuilder: (_, i) {
                final s = schedules[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text('${s.departureTime} · ${s.transitLineName ?? 'Ligne ${s.transitLineId}'}'),
                    subtitle: Text('${formatDaysOfWeek(s.daysOfWeek)}' +
                        (s.transitLineNumber != null ? ' · ${s.transitLineNumber}' : '') +
                        (s.notes != null && s.notes!.isNotEmpty ? ' · ${s.notes}' : '')),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          final lines = linesAsync.asData?.value ?? [];
                          final res = await _edit(context, lines: lines, schedule: s);
                          if (res == true) {
                            ref.invalidate(shuttleSchedulesProvider);
                            ref.invalidate(shuttleOverviewProvider);
                          }
                        } else if (action == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Supprimer cet horaire ?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            try {
                              await ref.read(shuttleOperatorApiProvider).deleteSchedule(s.id);
                              ref.invalidate(shuttleSchedulesProvider);
                              ref.invalidate(shuttleOverviewProvider);
                            } catch (err) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec : $err')));
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final lines = linesAsync.asData?.value ?? [];
          if (lines.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Créez une ligne avant d\'ajouter un horaire.')));
            return;
          }
          final res = await _edit(context, lines: lines);
          if (res == true) {
            ref.invalidate(shuttleSchedulesProvider);
            ref.invalidate(shuttleOverviewProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool?> _edit(BuildContext context, {required List<ShuttleLine> lines, ShuttleSchedule? schedule}) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ScheduleEditor(lines: lines, schedule: schedule),
      ),
    );
  }
}

class _ScheduleEditor extends ConsumerStatefulWidget {
  final List<ShuttleLine> lines;
  final ShuttleSchedule? schedule;

  const _ScheduleEditor({required this.lines, this.schedule});

  @override
  ConsumerState<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends ConsumerState<_ScheduleEditor> {
  late String _lineId;
  late TimeOfDay _time;
  late Set<int> _days;
  late TextEditingController _notes;
  DateTime? _activeUntil;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.schedule;
    _lineId = s?.transitLineId ?? widget.lines.first.id;
    if (s != null && s.departureTime.contains(':')) {
      final parts = s.departureTime.split(':');
      _time = TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
    } else {
      _time = const TimeOfDay(hour: 8, minute: 0);
    }
    _days = Set.of(s?.daysOfWeek ?? const [1, 2, 3, 4, 5]);
    _notes = TextEditingController(text: s?.notes ?? '');
    _activeUntil = s?.activeUntil;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String get _timeString => '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.schedule != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(isEdit ? 'Modifier horaire' : 'Nouvel horaire', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _lineId,
              decoration: const InputDecoration(labelText: 'Ligne', border: OutlineInputBorder()),
              items: widget.lines.map((l) => DropdownMenuItem(value: l.id, child: Text('${l.number} · ${l.name}'))).toList(),
              onChanged: isEdit ? null : (v) => setState(() => _lineId = v!),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _time);
                      if (picked != null) setState(() => _time = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Heure de départ', border: OutlineInputBorder()),
                      child: Text(_timeString, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        initialDate: _activeUntil ?? DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) setState(() => _activeUntil = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fin (optionnel)',
                        border: const OutlineInputBorder(),
                        suffixIcon: _activeUntil != null
                            ? IconButton(onPressed: () => setState(() => _activeUntil = null), icon: const Icon(Icons.clear, size: 16))
                            : null,
                      ),
                      child: Text(
                        _activeUntil == null ? 'Aucune' : '${_activeUntil!.day}/${_activeUntil!.month}/${_activeUntil!.year}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Jours actifs', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: List.generate(7, (d) {
                final selected = _days.contains(d);
                return FilterChip(
                  label: Text(kDayLabelsFr[d]),
                  selected: selected,
                  onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                );
              }),
            ),
            const SizedBox(height: 14),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Enregistrer' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_days.isEmpty) {
      setState(() => _error = 'Sélectionnez au moins un jour');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(shuttleOperatorApiProvider);
      final notes = _notes.text.trim();
      if (widget.schedule == null) {
        await api.createSchedule(
          transitLineId: _lineId,
          daysOfWeek: _days.toList()..sort(),
          departureTime: _timeString,
          activeUntil: _activeUntil,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await api.updateSchedule(widget.schedule!.id, {
          'daysOfWeek': _days.toList()..sort(),
          'departureTime': _timeString,
          if (_activeUntil != null) 'activeUntil': _activeUntil!.toIso8601String() else 'activeUntil': null,
          'notes': notes.isEmpty ? '' : notes,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
