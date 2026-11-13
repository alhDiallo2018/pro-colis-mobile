// lib/screens/driver/advertisement_reached_stops_screen.dart
//
// Phase 1 — Affiche les arrêts d'un trajet navette qui ont été atteints
// (détection GPS géofence). Consomme `GET /advertisements/:id/reached-stops`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers/reached_stops_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api/advertisement_extra_api.dart';

class AdvertisementReachedStopsScreen extends ConsumerWidget {
  final String advertisementId;

  const AdvertisementReachedStopsScreen({
    super.key,
    required this.advertisementId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(reachedStopsProvider(advertisementId));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.reachedStopsTitle),
        actions: [
          IconButton(
            tooltip: l.errorRetry,
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(reachedStopsProvider(advertisementId)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(
          message: err.toString(),
          onRetry: () =>
              ref.invalidate(reachedStopsProvider(advertisementId)),
        ),
        data: (result) => _ReachedList(result: result),
      ),
    );
  }
}

class _ReachedList extends StatelessWidget {
  final ReachedStopsResult result;

  const _ReachedList({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.reachedStops.isEmpty) {
      return Builder(
        builder: (context) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              AppLocalizations.of(context).reachedStopsEmpty,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: result.reachedStops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final s = result.reachedStops[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${s.stopOrder}')),
            title: Text(s.stopLabel ?? 'Arrêt ${s.stopOrder}'),
            subtitle: Text(
              '${s.distanceMeters} m du centre · rayon ${s.radiusMeters} m'
              '${s.reachedAt != null ? "\n${_formatDate(s.reachedAt!)}" : ""}',
            ),
            isThreeLine: s.reachedAt != null,
            trailing: Icon(Icons.check_circle, color: AppTheme.successColor),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} à $h:$m';
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
            Text(
              AppLocalizations.of(context).reachedStopsLoadFailed,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).errorRetry)),
          ],
        ),
      ),
    );
  }
}
