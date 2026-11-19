// lib/providers/shuttle_operator_provider.dart
//
// SCP-007 — Providers Riverpod pour l'espace opérateur de navette.
// Les écrans invalident les queries après chaque mutation.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/client.dart';
import '../services/api/shuttle_operator_api.dart';

final shuttleOperatorApiProvider = Provider<ShuttleOperatorApi>((ref) {
  return ShuttleOperatorApi(ApiClient());
});

final shuttleOverviewProvider =
    FutureProvider.autoDispose<ShuttleOverview>((ref) async {
  return ref.read(shuttleOperatorApiProvider).getOverview();
});

final shuttleLinesProvider =
    FutureProvider.autoDispose<List<ShuttleLine>>((ref) async {
  return ref.read(shuttleOperatorApiProvider).listLines();
});

final shuttleVehiclesProvider =
    FutureProvider.autoDispose<List<ShuttleVehicle>>((ref) async {
  return ref.read(shuttleOperatorApiProvider).listVehicles();
});

final shuttleSchedulesProvider =
    FutureProvider.autoDispose<List<ShuttleSchedule>>((ref) async {
  return ref.read(shuttleOperatorApiProvider).listSchedules();
});

final shuttleLiveProvider =
    FutureProvider.autoDispose<ShuttleLiveSnapshot>((ref) async {
  return ref.read(shuttleOperatorApiProvider).getLive();
});
