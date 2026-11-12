// lib/screens/driver/advertisement_optimize_route_screen.dart
//
// Phase 6 — Affiche l'ordre de visite optimal pour un trajet navette.
// Consomme `POST /advertisements/:id/optimize-route`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers/reached_stops_provider.dart';
import '../../services/api/advertisement_extra_api.dart';

class AdvertisementOptimizeRouteScreen extends ConsumerWidget {
  final String advertisementId;

  const AdvertisementOptimizeRouteScreen({
    super.key,
    required this.advertisementId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(optimizeRouteProvider(advertisementId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.optimizeRouteTitle),
        actions: [
          IconButton(
            tooltip: l.errorRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(optimizeRouteProvider(advertisementId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(
          message: err.toString(),
          onRetry: () =>
              ref.invalidate(optimizeRouteProvider(advertisementId)),
        ),
        data: (route) => _RouteView(route: route),
      ),
    );
  }
}

class _RouteView extends StatelessWidget {
  final OptimizedRoute route;

  const _RouteView({required this.route});

  @override
  Widget build(BuildContext context) {
    if (route.ordered.isEmpty) {
      return Builder(
        builder: (context) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppLocalizations.of(context).optimizeRouteEmpty,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(route: route),
        const SizedBox(height: 12),
        for (var i = 0; i < route.ordered.length; i++)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(
                route.ordered[i].receiverName ??
                    route.ordered[i].trackingNumber ??
                    'Étape ${i + 1}',
              ),
              subtitle: Text(
                [
                  if (route.ordered[i].trackingNumber != null)
                    route.ordered[i].trackingNumber!,
                  '${route.ordered[i].latitude.toStringAsFixed(4)}, '
                      '${route.ordered[i].longitude.toStringAsFixed(4)}',
                ].join('\n'),
              ),
              isThreeLine: route.ordered[i].trackingNumber != null,
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final OptimizedRoute route;

  const _Header({required this.route});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(
              label: l.optimizeRouteSteps,
              value: route.ordered.length.toString(),
            ),
            _Stat(
              label: l.optimizeRouteDistance,
              value: '${route.distanceKm.toStringAsFixed(1)} km',
            ),
            if (route.improvedBy > 0.01)
              _Stat(
                label: l.optimizeRouteImprovement,
                value: '-${route.improvedBy.toStringAsFixed(1)} km',
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(color: color ?? theme.textTheme.titleLarge?.color)),
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
            const Text('Calcul impossible',
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
