// lib/screens/shipper/shipment_batches_screen.dart
//
// Phase 4 — Dashboard B2B : liste des lots d'expédition du créateur.
// Permet de créer un nouveau lot et d'ouvrir le détail.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers/shipment_batch_provider.dart';
import '../../services/api/shipment_batch_api.dart';

class ShipmentBatchesScreen extends ConsumerWidget {
  const ShipmentBatchesScreen({super.key});

  Future<void> _createBatch(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _CreateBatchDialog(),
    );
    if (result == null) return;
    final batch = await ref
        .read(shipmentBatchControllerProvider.notifier)
        .create(reference: result['reference'], label: result['label']);
    if (!context.mounted) return;
    if (batch != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lot créé : ${batch.label ?? batch.id}')),
      );
    } else {
      final err = ref.read(shipmentBatchControllerProvider).error ?? 'Erreur';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(shipmentBatchesListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.shipmentBatchesTitle),
        actions: [
          IconButton(
            tooltip: l.errorRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(shipmentBatchesListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createBatch(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.shipmentBatchesCreate),
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
                      ref.invalidate(shipmentBatchesListProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (batches) {
          if (batches.isEmpty) {
            return Builder(
              builder: (context) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppLocalizations.of(context).shipmentBatchesEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _BatchTile(batch: batches[i]),
          );
        },
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  final ShipmentBatch batch;

  const _BatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final color = switch (batch.status) {
      'draft' => Colors.grey,
      'open' => Colors.blue,
      'closed' => Colors.green,
      'cancelled' => Colors.red,
      _ => Colors.grey,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: const Icon(Icons.inventory_2, color: Colors.white),
        ),
        title: Text(batch.label ?? batch.reference ?? 'Lot #${batch.id.substring(0, 8)}'),
        subtitle: Text(
          '${batch.totalParcels} colis · ${batch.totalWeightKg.toStringAsFixed(1)} kg'
          '\nStatut : ${batch.status}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/shipment-batches/${batch.id}'),
      ),
    );
  }
}

class _CreateBatchDialog extends StatefulWidget {
  const _CreateBatchDialog();

  @override
  State<_CreateBatchDialog> createState() => _CreateBatchDialogState();
}

class _CreateBatchDialogState extends State<_CreateBatchDialog> {
  final _label = TextEditingController();
  final _reference = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau lot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Nom (optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Référence commerciale (optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'label': _label.text.trim(),
            'reference': _reference.text.trim(),
          }),
          child: const Text('Créer'),
        ),
      ],
    );
  }
}
