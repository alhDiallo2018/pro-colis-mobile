// lib/screens/parcel/international_offers_screen.dart
//
// SCP-041 — Affiche les devis des carriers internationaux pour un colis
// dont la déclaration douanière est signée.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/customs_provider.dart';
import '../../services/api/international_carriers_api.dart';

class InternationalOffersScreen extends ConsumerWidget {
  final String parcelId;

  const InternationalOffersScreen({super.key, required this.parcelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(internationalOffersProvider(parcelId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devis internationaux'),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(internationalOffersProvider(parcelId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(internationalOffersProvider(parcelId)),
        ),
        data: (r) => _OffersView(result: r),
      ),
    );
  }
}

class _OffersView extends StatelessWidget {
  final InternationalOffersResult result;

  const _OffersView({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.offers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucun carrier n\'a retourné d\'offre pour cette destination.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(label: 'Origine', value: result.origin),
                _Stat(label: 'Destination', value: result.destination),
                _Stat(label: 'Offres', value: result.offers.length.toString()),
              ],
            ),
          ),
        ),
        if (!result.isCustomsSigned)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Card(
              color: Colors.amber.shade50,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Déclaration non signée : les devis restent indicatifs tant que la déclaration n\'est pas verrouillée.',
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        for (final o in result.offers)
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping, size: 32),
              title: Text('${o.carrier.toUpperCase()} · ${o.service}'),
              subtitle: Text(
                '${o.etaDays} jour${o.etaDays > 1 ? "s" : ""}'
                '${o.destinationZone != null ? ' · zone ${o.destinationZone}' : ''}'
                '\n${o.confidence == 'stub' ? '⚠️ tarif indicatif (stub)' : 'tarif négocié'}',
              ),
              isThreeLine: true,
              trailing: Text(
                '${o.priceXof} FCFA',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            const Text('Chargement impossible',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
