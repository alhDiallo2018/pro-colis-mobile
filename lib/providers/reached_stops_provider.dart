// lib/providers/reached_stops_provider.dart
//
// FutureProvider.family pour les arrêts atteints d'un trajet navette.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/advertisement_extra_api.dart';
import '../services/api/client.dart';

final _advertisementExtraApiProvider = Provider<AdvertisementExtraApi>((ref) {
  return AdvertisementExtraApi(ApiClient());
});

final reachedStopsProvider = FutureProvider.family
    .autoDispose<ReachedStopsResult, String>((ref, advertisementId) async {
  final api = ref.read(_advertisementExtraApiProvider);
  return api.fetchReachedStops(advertisementId);
});

final optimizeRouteProvider = FutureProvider.family
    .autoDispose<OptimizedRoute, String>((ref, advertisementId) async {
  final api = ref.read(_advertisementExtraApiProvider);
  return api.optimizeRoute(advertisementId);
});

// Phase 2 — Confirmations chauffeur par colis à l'arrêt. On expose l'API
// extra_api côté providers pour permettre à l'UI de POSTer une confirmation
// et d'invalider la liste ensuite.
final advertisementExtraApiProvider =
    Provider<AdvertisementExtraApi>((ref) => AdvertisementExtraApi(ApiClient()));

final stopConfirmationsProvider = FutureProvider.family
    .autoDispose<List<ShuttleStopConfirmation>, String>(
        (ref, advertisementId) async {
  final api = ref.read(advertisementExtraApiProvider);
  return api.fetchStopConfirmations(advertisementId);
});
