// lib/providers/customs_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/client.dart';
import '../services/api/customs_api.dart';
import '../services/api/international_carriers_api.dart';

final customsApiProvider = Provider<CustomsApi>((ref) => CustomsApi(ApiClient()));
final internationalCarriersApiProvider =
    Provider<InternationalCarriersApi>((ref) => InternationalCarriersApi(ApiClient()));

final parcelCustomsProvider = FutureProvider.family
    .autoDispose<ParcelCustoms?, String>((ref, parcelId) async {
  return ref.read(customsApiProvider).get(parcelId);
});

final internationalOffersProvider = FutureProvider.family
    .autoDispose<InternationalOffersResult, String>((ref, parcelId) async {
  return ref.read(internationalCarriersApiProvider).fetch(parcelId);
});

class CustomsMutationState {
  final bool busy;
  final String? error;
  final ParcelCustoms? lastResult;

  const CustomsMutationState({this.busy = false, this.error, this.lastResult});

  CustomsMutationState copyWith(
          {bool? busy, String? error, ParcelCustoms? lastResult}) =>
      CustomsMutationState(
        busy: busy ?? this.busy,
        error: error,
        lastResult: lastResult ?? this.lastResult,
      );
}

class CustomsController extends StateNotifier<CustomsMutationState> {
  CustomsController(this._ref) : super(const CustomsMutationState());

  final Ref _ref;
  CustomsApi get _api => _ref.read(customsApiProvider);

  Future<ParcelCustoms?> save(
      String parcelId, Map<String, dynamic> body,
      {required bool existing}) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final r = await _api.createOrUpdate(parcelId, body, existing: existing);
      state = CustomsMutationState(lastResult: r);
      _ref.invalidate(parcelCustomsProvider(parcelId));
      _ref.invalidate(internationalOffersProvider(parcelId));
      return r;
    } catch (err, st) {
      debugPrint('[Customs] save failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }

  Future<ParcelCustoms?> sign(String parcelId) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final r = await _api.sign(parcelId);
      state = CustomsMutationState(lastResult: r);
      _ref.invalidate(parcelCustomsProvider(parcelId));
      _ref.invalidate(internationalOffersProvider(parcelId));
      return r;
    } catch (err) {
      state = state.copyWith(busy: false, error: err.toString());
      return null;
    }
  }
}

final customsControllerProvider =
    StateNotifierProvider<CustomsController, CustomsMutationState>((ref) {
  return CustomsController(ref);
});
