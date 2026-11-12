// lib/providers/handover_provider.dart
//
// Providers Riverpod pour les correspondances inter-véhicules (ParcelHandover).
// - `handoverApiProvider` : l'API client, injectable pour les tests.
// - `parcelHandoversProvider.family(parcelId)` : liste des handovers d'un colis.
//
// Les mutations (initiate/confirm/cancel) passent par `HandoverController`
// (StateNotifier) qui stocke les secrets révélés (PIN + QR) UNIQUEMENT en
// mémoire, jamais persistés.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/client.dart';
import '../services/api/handover_api.dart';

final handoverApiProvider = Provider<HandoverApi>((ref) {
  return HandoverApi(ApiClient());
});

final parcelHandoversProvider = FutureProvider.family
    .autoDispose<List<ParcelHandover>, String>((ref, parcelId) async {
  final api = ref.read(handoverApiProvider);
  return api.list(parcelId);
});

class HandoverMutationState {
  final bool busy;
  final String? error;
  final ParcelHandover? lastInitiated;
  final ParcelHandover? lastConfirmed;
  final ParcelHandover? lastCancelled;

  const HandoverMutationState({
    this.busy = false,
    this.error,
    this.lastInitiated,
    this.lastConfirmed,
    this.lastCancelled,
  });

  HandoverMutationState copyWith({
    bool? busy,
    String? error,
    ParcelHandover? lastInitiated,
    ParcelHandover? lastConfirmed,
    ParcelHandover? lastCancelled,
  }) =>
      HandoverMutationState(
        busy: busy ?? this.busy,
        error: error,
        lastInitiated: lastInitiated ?? this.lastInitiated,
        lastConfirmed: lastConfirmed ?? this.lastConfirmed,
        lastCancelled: lastCancelled ?? this.lastCancelled,
      );
}

class HandoverController extends StateNotifier<HandoverMutationState> {
  HandoverController(this._ref) : super(const HandoverMutationState());

  final Ref _ref;
  HandoverApi get _api => _ref.read(handoverApiProvider);

  Future<ParcelHandover?> initiate({
    required String parcelId,
    required String toDriverId,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final h = await _api.initiate(parcelId,
          toDriverId: toDriverId, latitude: latitude, longitude: longitude);
      state = HandoverMutationState(lastInitiated: h);
      _ref.invalidate(parcelHandoversProvider(parcelId));
      return h;
    } catch (err, st) {
      debugPrint('[Handover] initiate failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }

  Future<ParcelHandover?> confirm({
    required String parcelId,
    required String handoverId,
    required String pin,
    required String qrToken,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final h = await _api.confirm(parcelId, handoverId,
          pin: pin, qrToken: qrToken);
      state = HandoverMutationState(lastConfirmed: h);
      _ref.invalidate(parcelHandoversProvider(parcelId));
      return h;
    } catch (err, st) {
      debugPrint('[Handover] confirm failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }

  Future<ParcelHandover?> cancel({
    required String parcelId,
    required String handoverId,
    String? reason,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final h =
          await _api.cancel(parcelId, handoverId, reason: reason);
      state = HandoverMutationState(lastCancelled: h);
      _ref.invalidate(parcelHandoversProvider(parcelId));
      return h;
    } catch (err, st) {
      debugPrint('[Handover] cancel failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }
}

final handoverControllerProvider =
    StateNotifierProvider<HandoverController, HandoverMutationState>((ref) {
  return HandoverController(ref);
});
