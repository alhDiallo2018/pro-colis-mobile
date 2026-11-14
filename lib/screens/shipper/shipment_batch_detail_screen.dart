// lib/screens/shipper/shipment_batch_detail_screen.dart
//
// Phase 4 — Détail d'un lot : liste des colis, totaux, actions (attach,
// detach, close). L'ajout de colis attend un ID de colis en texte ; un
// picker depuis la liste des colis de l'utilisateur sera ajouté plus tard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/parcel.dart';
import '../../providers/shipment_batch_provider.dart';
import '../../services/api/shipment_batch_api.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ShipmentBatchDetailScreen extends ConsumerWidget {
  final String batchId;

  const ShipmentBatchDetailScreen({super.key, required this.batchId});

  Future<void> _addParcel(BuildContext context, WidgetRef ref) async {
    // Récupère les colis de l'utilisateur (envois). Filtre ceux déjà rattachés
    // à un autre batch (`batchId != null`) ou dans un statut incompatible.
    List<Parcel> parcels;
    try {
      parcels = await ApiService().getMyParcels();
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger vos colis : $err')),
      );
      return;
    }
    // Filtre côté client sur les statuts incompatibles ; le backend rejette
    // (409) les colis déjà rattachés à un autre lot, géré via SnackBar.
    final selectable = parcels
        .where((p) => !_terminalStatuses.contains(p.status))
        .toList();

    if (!context.mounted) return;
    final parcelIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ParcelPickerSheet(parcels: selectable),
    );
    if (parcelIds == null || parcelIds.isEmpty) return;
    final result = await ref
        .read(shipmentBatchControllerProvider.notifier)
        .attach(batchId, parcelIds);
    if (!context.mounted) return;
    if (result == null) {
      final err = ref.read(shipmentBatchControllerProvider).error ?? 'Erreur';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parcelIds.length == 1
                ? '1 colis ajouté au lot'
                : '${parcelIds.length} colis ajoutés au lot',
          ),
        ),
      );
    }
  }

  // Statuts dans lesquels un colis ne doit plus rejoindre un batch.
  static const _terminalStatuses = ['delivered', 'cancelled'];

  Future<void> _detach(BuildContext context, WidgetRef ref, String parcelId) async {
    final result = await ref
        .read(shipmentBatchControllerProvider.notifier)
        .detach(batchId, parcelId);
    if (!context.mounted) return;
    if (result == null) {
      final err = ref.read(shipmentBatchControllerProvider).error ?? 'Erreur';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _addStopEvent(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_StopEventFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _StopEventForm(),
    );
    if (result == null) return;
    final event = await ref
        .read(shipmentBatchControllerProvider.notifier)
        .createStopEvent(
          batchId,
          type: result.type,
          label: result.label,
          description: result.description,
          stopLabel: result.stopLabel,
        );
    if (!context.mounted) return;
    if (event == null) {
      final err = ref.read(shipmentBatchControllerProvider).error ?? 'Erreur';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Événement enregistré')),
      );
    }
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer ce lot ?'),
        content: const Text(
          'Après clôture, aucun colis ne pourra être ajouté ou retiré.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref
        .read(shipmentBatchControllerProvider.notifier)
        .close(batchId);
    if (!context.mounted) return;
    if (result == null) {
      final err = ref.read(shipmentBatchControllerProvider).error ?? 'Erreur';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lot clôturé')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(shipmentBatchDetailProvider(batchId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.shipmentBatchDetailTitle),
        actions: [
          IconButton(
            tooltip: l.errorRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(shipmentBatchDetailProvider(batchId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(err.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(shipmentBatchDetailProvider(batchId)),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (batch) => _BatchDetailView(
          batch: batch,
          batchId: batchId,
          onAddParcel: batch.isMutable ? () => _addParcel(context, ref) : null,
          onClose: batch.isMutable ? () => _close(context, ref) : null,
          onDetach:
              batch.isMutable ? (pid) => _detach(context, ref, pid) : null,
          onAddStopEvent: () => _addStopEvent(context, ref),
        ),
      ),
    );
  }
}

class _BatchDetailView extends ConsumerWidget {
  final ShipmentBatch batch;
  final String batchId;
  final VoidCallback? onAddParcel;
  final VoidCallback? onClose;
  final void Function(String parcelId)? onDetach;
  final VoidCallback? onAddStopEvent;

  const _BatchDetailView({
    required this.batch,
    required this.batchId,
    this.onAddParcel,
    this.onClose,
    this.onDetach,
    this.onAddStopEvent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final eventsAsync = ref.watch(shipmentBatchStopEventsProvider(batchId));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.label ?? batch.reference ?? 'Lot ${batch.id}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (batch.reference != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Référence : ${batch.reference}'),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Chip(label: 'Statut', value: batch.status),
                    _Chip(
                      label: 'Colis',
                      value: batch.totalParcels.toString(),
                    ),
                    _Chip(
                      label: 'Poids',
                      value: '${batch.totalWeightKg.toStringAsFixed(1)} kg',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAddParcel,
                icon: const Icon(Icons.add),
                label: const Text('Rattacher un colis'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Clôturer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Colis du lot (${batch.parcels.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (batch.parcels.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Aucun colis rattaché pour le moment.'),
          )
        else
          ...batch.parcels.map((p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(p.trackingNumber ?? p.id),
                  subtitle: Text(
                    [
                      if (p.receiverName != null) p.receiverName!,
                      '${p.weight.toStringAsFixed(1)} kg · ${p.status ?? ""}',
                    ].join('\n'),
                  ),
                  isThreeLine: p.receiverName != null,
                  trailing: onDetach == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Détacher',
                          onPressed: () => onDetach!(p.id),
                        ),
                ),
              )),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                l.batchStopEventsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (onAddStopEvent != null)
              TextButton.icon(
                onPressed: onAddStopEvent,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        eventsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.batchStopEventsEmpty),
          ),
          data: (events) => events.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.slate200),
                  ),
                  child: Row(children: [
                    Icon(Icons.timeline_rounded,
                        color: AppTheme.slate400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l.batchStopEventsEmpty,
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ]),
                )
              : Column(
                  children: events.map(_BatchStopEventTile.new).toList(),
                ),
        ),
      ],
    );
  }
}

class _BatchStopEventTile extends StatelessWidget {
  final ShipmentBatchStopEvent event;
  const _BatchStopEventTile(this.event);

  IconData get _icon {
    switch (event.type) {
      case 'arrival':
        return Icons.place_outlined;
      case 'departure':
        return Icons.directions_car_filled_outlined;
      case 'incident':
        return Icons.warning_amber_rounded;
      case 'delay':
        return Icons.schedule_rounded;
      case 'delivered':
        return Icons.check_circle_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (event.stopLabel != null) event.stopLabel!,
      if (event.description != null) event.description!,
      if (event.occurredAt != null) event.occurredAt!.toLocal().toString(),
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: Icon(_icon),
        title: Text(event.label ?? event.type),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
      ),
    );
  }
}

// Sélecteur de colis à rattacher au lot.
class _ParcelPickerSheet extends StatefulWidget {
  final List<Parcel> parcels;

  const _ParcelPickerSheet({required this.parcels});

  @override
  State<_ParcelPickerSheet> createState() => _ParcelPickerSheetState();
}

class _ParcelPickerSheetState extends State<_ParcelPickerSheet> {
  String _query = '';
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.parcels
        : widget.parcels.where((p) {
            final q = _query.toLowerCase();
            return p.trackingNumber.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q) ||
                p.receiverName.toLowerCase().contains(q);
          }).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Choisir des colis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_selected.isNotEmpty)
                  Text(
                    '${_selected.length} sélectionné${_selected.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tracking, description ou destinataire',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
            const SizedBox(height: 12),
            if (widget.parcels.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun colis disponible pour un rattachement.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final checked = _selected.contains(p.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(p.id);
                          } else {
                            _selected.remove(p.id);
                          }
                        });
                      },
                      secondary:
                          const Icon(Icons.local_shipping_outlined),
                      title: Text(
                        p.trackingNumber.isEmpty
                            ? p.id
                            : p.trackingNumber,
                      ),
                      subtitle: Text(
                        [
                          if (p.receiverName.isNotEmpty) p.receiverName,
                          if (p.description.isNotEmpty) p.description,
                          '${p.weight.toStringAsFixed(1)} kg · ${p.status}',
                        ].join(' · '),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context)
                        .pop(_selected.toList(growable: false)),
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: Text(
                  _selected.isEmpty
                      ? 'Rattacher au lot'
                      : 'Rattacher ${_selected.length} colis',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StopEventFormResult {
  final String type;
  final String? label;
  final String? description;
  final String? stopLabel;

  const _StopEventFormResult({
    required this.type,
    this.label,
    this.description,
    this.stopLabel,
  });
}

class _StopEventForm extends StatefulWidget {
  const _StopEventForm();

  @override
  State<_StopEventForm> createState() => _StopEventFormState();
}

class _StopEventFormState extends State<_StopEventForm> {
  static const _types = <(String, String, IconData)>[
    ('arrival', 'Arrivée à l\'arrêt', Icons.place_outlined),
    ('departure', 'Départ de l\'arrêt', Icons.directions_car_filled_outlined),
    ('incident', 'Incident', Icons.warning_amber_rounded),
    ('delay', 'Retard', Icons.schedule_rounded),
    ('delivered', 'Livraison effectuée', Icons.check_circle_outline),
    ('event', 'Autre', Icons.circle_outlined),
  ];

  String _type = 'arrival';
  final _labelCtrl = TextEditingController();
  final _stopLabelCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    _stopLabelCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nouvel événement de tournée',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: _types
                    .map((t) => DropdownMenuItem(
                          value: t.$1,
                          child: Row(children: [
                            Icon(t.$3, size: 18),
                            const SizedBox(width: 8),
                            Text(t.$2),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'arrival'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Titre (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
              ),
              TextField(
                controller: _stopLabelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Arrêt / Lieu (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 200,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                maxLength: 2000,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  _StopEventFormResult(
                    type: _type,
                    label: _labelCtrl.text.trim().isEmpty
                        ? null
                        : _labelCtrl.text.trim(),
                    stopLabel: _stopLabelCtrl.text.trim().isEmpty
                        ? null
                        : _stopLabelCtrl.text.trim(),
                    description: _descriptionCtrl.text.trim().isEmpty
                        ? null
                        : _descriptionCtrl.text.trim(),
                  ),
                ),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer l\'événement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;

  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      padding: EdgeInsets.zero,
    );
  }
}
