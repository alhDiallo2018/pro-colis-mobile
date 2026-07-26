import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';
import '../services/api/client.dart';
import '../services/api/stats_api.dart';

final statsApiProvider = Provider<StatsApi>((ref) => StatsApi(ApiClient()));

final userStatsProvider = FutureProvider<UserStats>(
  (ref) => ref.watch(statsApiProvider).userStats(),
);

final clientBidStatsProvider = FutureProvider<ClientBidStats>(
  (ref) => ref.watch(statsApiProvider).clientBidStats(),
);

final clientProfileStatsProvider =
    FutureProvider<ClientProfileStats>((ref) async {
  // Les deux requêtes sont indépendantes et peuvent partir simultanément.
  final results = await Future.wait([
    ref.watch(statsApiProvider).userStats(),
    ref.watch(statsApiProvider).clientBidStats(),
  ]);
  return ClientProfileStats(
    user: results[0] as UserStats,
    bids: results[1] as ClientBidStats,
  );
});

final driverStatsProvider = FutureProvider<DriverStats>(
  (ref) => ref.watch(statsApiProvider).driverStats(),
);

final garageStatsProvider = FutureProvider<GarageStats>(
  (ref) => ref.watch(statsApiProvider).garageStats(),
);

final globalStatsProvider = FutureProvider<GlobalStats>(
  (ref) => ref.watch(statsApiProvider).globalStats(),
);

final advertisementStatsProvider = FutureProvider<AdvertisementStats>(
  (ref) => ref.watch(statsApiProvider).advertisementStats(),
);
