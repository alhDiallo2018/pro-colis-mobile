// lib/screens/driver/advertisement_manifest_screen.dart
//
// Écran driver : manifeste navette d'un trajet. Affiche l'ordre des arrêts
// avec, pour chacun, la liste des colis à embarquer (picked) et à remettre
// (dropOffs). Les colis non affectés à un arrêt (annonces libres) sont
// montrés dans une section séparée en bas.
//
// Consomme `manifestProvider(advertisementId)` (Riverpod AsyncValue).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers/manifest_provider.dart';
import '../../services/api/manifest_api.dart';

class AdvertisementManifestScreen extends ConsumerWidget {
  final String advertisementId;

  const AdvertisementManifestScreen({super.key, required this.advertisementId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(manifestProvider(advertisementId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.manifestTitle),
        actions: [
          IconButton(
            tooltip: l.errorRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(manifestProvider(advertisementId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(manifestProvider(advertisementId)),
        ),
        data: (manifest) => _ManifestView(manifest: manifest),
      ),
    );
  }
}

class _ManifestView extends StatelessWidget {
  final AdvertisementManifest manifest;

  const _ManifestView({required this.manifest});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (manifest.stops.isEmpty && manifest.unassigned.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.manifestEmpty,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(totalOffers: manifest.totalOffers, stopsCount: manifest.stops.length),
        const SizedBox(height: 12),
        ...manifest.stops.map((stop) => _StopCard(stop: stop)),
        if (manifest.unassigned.isNotEmpty) ...[
          const SizedBox(height: 16),
          _UnassignedSection(offers: manifest.unassigned),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final int totalOffers;
  final int stopsCount;

  const _Header({required this.totalOffers, required this.stopsCount});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Stat(label: l.manifestStopsCount, value: stopsCount.toString()),
            _Stat(label: l.manifestOffersCount, value: totalOffers.toString()),
          ],
        ),
      ),
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
        Text(value, style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _StopCard extends StatelessWidget {
  final ManifestStop stop;

  const _StopCard({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: stop.totalOffers > 0,
        leading: CircleAvatar(child: Text('${stop.order}')),
        title: Text(stop.label ?? 'Arrêt ${stop.order}'),
        subtitle: Text(
          '${stop.picked.length} à embarquer · ${stop.dropOffs.length} à remettre',
        ),
        children: [
          if (stop.picked.isNotEmpty)
            _OfferGroup(title: AppLocalizations.of(context).manifestPicked, offers: stop.picked, icon: Icons.upload_outlined),
          if (stop.dropOffs.isNotEmpty)
            _OfferGroup(title: AppLocalizations.of(context).manifestDropOffs, offers: stop.dropOffs, icon: Icons.download_outlined),
          if (stop.totalOffers == 0)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun colis à cet arrêt.'),
            ),
        ],
      ),
    );
  }
}

class _OfferGroup extends StatelessWidget {
  final String title;
  final List<ManifestOfferSummary> offers;
  final IconData icon;

  const _OfferGroup({required this.title, required this.offers, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 4),
          ...offers.map((offer) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(offer.trackingNumber ?? offer.id),
                subtitle: offer.receiverName != null ? Text(offer.receiverName!) : null,
                trailing: offer.price != null
                    ? Text('${offer.price!.toStringAsFixed(0)} FCFA')
                    : null,
              )),
        ],
      ),
    );
  }
}

class _UnassignedSection extends StatelessWidget {
  final List<ManifestOfferSummary> offers;

  const _UnassignedSection({required this.offers});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).manifestUnassigned(offers.length),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Ces offres ont été acceptées sans affectation d\'arrêt embarquement/descente.',
            ),
            const SizedBox(height: 8),
            ...offers.map((offer) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(offer.trackingNumber ?? offer.id),
                  subtitle: offer.receiverName != null ? Text(offer.receiverName!) : null,
                )),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
            Text(
              AppLocalizations.of(context).reachedStopsLoadFailed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).errorRetry)),
          ],
        ),
      ),
    );
  }
}
