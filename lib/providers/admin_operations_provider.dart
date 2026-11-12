// lib/providers/admin_operations_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api/admin_operations_api.dart';
import '../services/api/client.dart';

final adminOperationsApiProvider = Provider<AdminOperationsApi>((ref) {
  return AdminOperationsApi(ApiClient());
});

final adminRecentWebhooksProvider =
    FutureProvider.autoDispose<List<WebhookDeliveryRow>>((ref) async {
  return ref.read(adminOperationsApiProvider).recentWebhooks();
});

final adminRecentStopEventsProvider =
    FutureProvider.autoDispose<List<StopEventRow>>((ref) async {
  return ref.read(adminOperationsApiProvider).recentStopEvents();
});

final adminRecentHandoversProvider =
    FutureProvider.autoDispose<List<HandoverRow>>((ref) async {
  return ref.read(adminOperationsApiProvider).recentHandovers();
});

final adminPilot14dProvider =
    FutureProvider.autoDispose<Pilot14dMetrics>((ref) async {
  return ref.read(adminOperationsApiProvider).pilot14d();
});

final integrationsHealthProvider =
    FutureProvider.autoDispose<IntegrationsHealth>((ref) async {
  return ref.read(adminOperationsApiProvider).integrationsHealth();
});

class RolePromotionState {
  final bool busy;
  final String? error;
  final String? successMessage;

  const RolePromotionState({this.busy = false, this.error, this.successMessage});

  RolePromotionState copyWith({bool? busy, String? error, String? successMessage}) =>
      RolePromotionState(
        busy: busy ?? this.busy,
        error: error,
        successMessage: successMessage,
      );
}

class RolePromotionController extends StateNotifier<RolePromotionState> {
  RolePromotionController(this._ref) : super(const RolePromotionState());

  final Ref _ref;

  Future<bool> promote(String userId, String role) async {
    state = state.copyWith(busy: true, error: null, successMessage: null);
    try {
      final newRole =
          await _ref.read(adminOperationsApiProvider).promoteRole(userId, role);
      state = RolePromotionState(successMessage: 'Rôle mis à jour : $newRole');
      return true;
    } catch (err, st) {
      debugPrint('[RolePromotion] failed: $err\n$st');
      state = state.copyWith(busy: false, error: err.toString());
      return false;
    }
  }
}

final rolePromotionControllerProvider = StateNotifierProvider<
    RolePromotionController, RolePromotionState>((ref) {
  return RolePromotionController(ref);
});
