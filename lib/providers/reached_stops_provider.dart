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
