// lib/providers/shipment_batch_provider.dart
//
// Providers Riverpod pour les lots d'expédition (ShipmentBatch).
// - Liste des lots du créateur authentifié.
// - Détail d'un lot (rafraîchi après mutation).
// - Controller pour create/attach/detach/close.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/client.dart';
import '../services/api/shipment_batch_api.dart';

final shipmentBatchApiProvider = Provider<ShipmentBatchApi>((ref) {
  return ShipmentBatchApi(ApiClient());
});

final shipmentBatchesListProvider =
    FutureProvider.autoDispose<List<ShipmentBatch>>((ref) async {
  final api = ref.read(shipmentBatchApiProvider);
  return api.list();
});

final shipmentBatchDetailProvider = FutureProvider.family
    .autoDispose<ShipmentBatch, String>((ref, batchId) async {
  final api = ref.read(shipmentBatchApiProvider);
  return api.get(batchId);
});

final shipmentBatchStopEventsProvider = FutureProvider.family
    .autoDispose<List<ShipmentBatchStopEvent>, String>((ref, batchId) async {
  final api = ref.read(shipmentBatchApiProvider);
  return api.stopEvents(batchId);
});

class ShipmentBatchMutationState {
  final bool busy;
  final String? error;
  final ShipmentBatch? lastResult;

  const ShipmentBatchMutationState({this.busy = false, this.error, this.lastResult});

  ShipmentBatchMutationState copyWith(
          {bool? busy, String? error, ShipmentBatch? lastResult}) =>
      ShipmentBatchMutationState(
        busy: busy ?? this.busy,
        error: error,
        lastResult: lastResult ?? this.lastResult,
      );
}

class ShipmentBatchController
    extends StateNotifier<ShipmentBatchMutationState> {
  ShipmentBatchController(this._ref)
      : super(const ShipmentBatchMutationState());

  final Ref _ref;
  ShipmentBatchApi get _api => _ref.read(shipmentBatchApiProvider);

  Future<ShipmentBatch?> create({String? reference, String? label}) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final b = await _api.create(reference: reference, label: label);
      state = ShipmentBatchMutationState(lastResult: b);
      _ref.invalidate(shipmentBatchesListProvider);
      return b;
    } catch (err, st) {
      debugPrint('[ShipmentBatch] create failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }

  Future<ShipmentBatch?> attach(String batchId, List<String> parcelIds) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final b = await _api.attach(batchId, parcelIds);
      state = ShipmentBatchMutationState(lastResult: b);
      _ref.invalidate(shipmentBatchesListProvider);
      _ref.invalidate(shipmentBatchDetailProvider(batchId));
      return b;
    } catch (err, st) {
      debugPrint('[ShipmentBatch] attach failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }

  Future<ShipmentBatch?> detach(String batchId, String parcelId) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final b = await _api.detach(batchId, parcelId);
      state = ShipmentBatchMutationState(lastResult: b);
      _ref.invalidate(shipmentBatchesListProvider);
      _ref.invalidate(shipmentBatchDetailProvider(batchId));
      return b;
    } catch (err, st) {
      debugPrint('[ShipmentBatch] detach failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }

  Future<ShipmentBatch?> close(String batchId) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final b = await _api.close(batchId);
      state = ShipmentBatchMutationState(lastResult: b);
      _ref.invalidate(shipmentBatchesListProvider);
      _ref.invalidate(shipmentBatchDetailProvider(batchId));
      return b;
    } catch (err, st) {
      debugPrint('[ShipmentBatch] close failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }

  Future<ShipmentBatchStopEvent?> createStopEvent(
    String batchId, {
    required String type,
    String? label,
    String? description,
    String? parcelId,
    String? stopLabel,
  }) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final event = await _api.createStopEvent(
        batchId,
        type: type,
        label: label,
        description: description,
        parcelId: parcelId,
        stopLabel: stopLabel,
      );
      state = state.copyWith(busy: false);
      _ref.invalidate(shipmentBatchStopEventsProvider(batchId));
      return event;
    } catch (err, st) {
      debugPrint('[ShipmentBatch] createStopEvent failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }
}

final shipmentBatchControllerProvider = StateNotifierProvider<
    ShipmentBatchController, ShipmentBatchMutationState>((ref) {
  return ShipmentBatchController(ref);
});
