// lib/screens/shuttle_operator/shuttle_vehicles_screen.dart
//
// SCP-007 — CRUD flotte navette (soft delete sur `retired`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shuttle_operator_provider.dart';
import '../../services/api/shuttle_operator_api.dart';

const _statusLabels = {
  'available': ('Disponible', Colors.green),
  'maintenance': ('Maintenance', Colors.orange),
  'retired': ('Retiré', Colors.red),
};

class ShuttleVehiclesScreen extends ConsumerWidget {
  const ShuttleVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shuttleVehiclesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flotte'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(shuttleVehiclesProvider)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shuttleVehiclesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text(err.toString())),
          data: (vehicles) {
            if (vehicles.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Aucun véhicule. Ajoutez-en un.')));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: vehicles.length,
              itemBuilder: (_, i) {
                final v = vehicles[i];
                final meta = _statusLabels[v.status] ?? ('Inconnu', Colors.grey);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: Icon(Icons.directions_bus, color: meta.$2),
                    title: Text(v.plateNumber),
                    subtitle: Text('${v.model} · ${v.type} · ${v.capacity} pl. · ${meta.$1}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          final res = await _edit(context, vehicle: v);
                          if (res == true) {
                            ref.invalidate(shuttleVehiclesProvider);
                            ref.invalidate(shuttleOverviewProvider);
                          }
                        } else if (action == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Retirer ce véhicule ?'),
                              content: Text('Plaque ${v.plateNumber} sera marquée retirée.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirer')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            try {
                              await ref.read(shuttleOperatorApiProvider).deleteVehicle(v.id);
                              ref.invalidate(shuttleVehiclesProvider);
                              ref.invalidate(shuttleOverviewProvider);
                            } catch (err) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec : $err')));
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(value: 'delete', child: Text('Retirer')),
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
          final res = await _edit(context);
          if (res == true) {
            ref.invalidate(shuttleVehiclesProvider);
            ref.invalidate(shuttleOverviewProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool?> _edit(BuildContext context, {ShuttleVehicle? vehicle}) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _VehicleEditor(vehicle: vehicle),
      ),
    );
  }
}

class _VehicleEditor extends ConsumerStatefulWidget {
  final ShuttleVehicle? vehicle;

  const _VehicleEditor({this.vehicle});

  @override
  ConsumerState<_VehicleEditor> createState() => _VehicleEditorState();
}

class _VehicleEditorState extends ConsumerState<_VehicleEditor> {
  late final TextEditingController _plate;
  late final TextEditingController _model;
  late final TextEditingController _capacity;
  late final TextEditingController _notes;
  late String _type;
  late String _status;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _plate = TextEditingController(text: v?.plateNumber ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _capacity = TextEditingController(text: v?.capacity.toString() ?? '16');
    _notes = TextEditingController(text: v?.notes ?? '');
    _type = v?.type ?? 'minibus';
    _status = v?.status ?? 'available';
  }

  @override
  void dispose() {
    _plate.dispose();
    _model.dispose();
    _capacity.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehicle != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(isEdit ? 'Modifier véhicule' : 'Nouveau véhicule', style: Theme.of(context).textTheme.titleLarge)),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: _plate, decoration: const InputDecoration(labelText: 'Plaque', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _model, decoration: const InputDecoration(labelText: 'Modèle', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: kShuttleVehicleTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 10),
            TextField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacité', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Statut', border: OutlineInputBorder()),
              items: kShuttleVehicleStatuses.map((s) => DropdownMenuItem(value: s, child: Text(_statusLabels[s]?.$1 ?? s))).toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 10),
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final capacity = int.tryParse(_capacity.text.trim());
      if (capacity == null || capacity < 1 || capacity > 200) throw 'Capacité 1..200';
      final api = ref.read(shuttleOperatorApiProvider);
      if (widget.vehicle == null) {
        await api.createVehicle(
          plateNumber: _plate.text.trim(),
          model: _model.text.trim(),
          type: _type,
          capacity: capacity,
          status: _status,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      } else {
        await api.updateVehicle(widget.vehicle!.id, {
          'plateNumber': _plate.text.trim(),
          'model': _model.text.trim(),
          'type': _type,
          'capacity': capacity,
          'status': _status,
          'notes': _notes.text.trim().isEmpty ? '' : _notes.text.trim(),
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
