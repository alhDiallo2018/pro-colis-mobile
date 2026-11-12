// lib/providers/manifest_provider.dart
//
// FutureProvider.family pour le manifeste navette d'une annonce donnée.
// Le screen consomme via `ref.watch(manifestProvider(advertisementId))`
// et obtient un `AsyncValue<AdvertisementManifest>` (loading / error / data
// unifiés sans setState local).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/client.dart';
import '../services/api/manifest_api.dart';

final _manifestApiProvider = Provider<ManifestApi>((ref) {
  return ManifestApi(ApiClient());
});

final manifestProvider = FutureProvider.family
    .autoDispose<AdvertisementManifest, String>((ref, advertisementId) async {
  final api = ref.read(_manifestApiProvider);
  return api.fetch(advertisementId);
});
