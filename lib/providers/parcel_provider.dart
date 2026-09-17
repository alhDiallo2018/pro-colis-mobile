// mobile/lib/providers/parcel_provider.dart
// Aligné sur l'API Web ProColis

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/parcel.dart';
import '../models/user.dart';
import '../models/cancellation.dart';
import '../services/api_service.dart';
import '../utils/parcel_access_policy.dart';

final parcelProvider =
    StateNotifierProvider<ParcelNotifier, ParcelState>((ref) {
  return ParcelNotifier();
});

class ParcelNotifier extends StateNotifier<ParcelState> {
  ParcelNotifier() : super(ParcelState.initial());

  final ApiService _apiService = ApiService();

  Future<void> loadMyParcels({String? status}) async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getMyParcels(status: status);
      state = state.copyWith(parcels: parcels, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadSentParcels({String? status}) async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getSentParcels(status: status);
      state =
          state.copyWith(sentParcels: parcels, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadReceivedParcels({String? status}) async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getReceivedParcels(status: status);
      state = state.copyWith(
          receivedParcels: parcels, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Charge les deux directions ensemble, puis les reclasse avec l'identité du
  /// client. Cette vérification locale empêche une réponse serveur mal filtrée
  /// de placer les colis expédiés dans l'onglet « Reçus ».
  Future<void> loadClientParcels(
    User client, {
    String? status,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _apiService.getSentParcels(status: status),
        _apiService.getReceivedParcels(status: status),
      ]);

      // Les deux endpoints peuvent contenir le même colis selon la version de
      // l'API. La fusion permet de reconstituer une source fiable avant de
      // séparer expéditeur et destinataire.
      final byId = <String, Parcel>{};
      for (final parcel in [...results[0], ...results[1]]) {
        byId[parcel.id] = parcel;
      }

      final sent = <Parcel>[];
      final received = <Parcel>[];
      for (final parcel in byId.values) {
        final sentByClient = isParcelSender(parcel, client);
        final receivedByClient = isParcelRecipient(parcel, client);

        if (sentByClient) sent.add(parcel);

        // ✅ CORRECTION : Un colis où l'utilisateur est destinataire
        // (même s'il est aussi expéditeur) doit apparaître dans les "Reçus"
        if (receivedByClient) received.add(parcel);
      }

      state = state.copyWith(
        sentParcels: sent,
        receivedParcels: received,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      debugPrint('❌ Erreur classement des colis client: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// ✅ CORRIGÉ : Charge les colis du chauffeur avec gestion d'erreur améliorée
  Future<void> loadDriverParcels() async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getDriverParcels();
      state = state.copyWith(parcels: parcels, isLoading: false, error: null);
    } catch (e) {
      debugPrint('❌ [ParcelProvider] loadDriverParcels failed: $e');
      state = state.copyWith(
        error: 'Impossible de charger les colis du chauffeur',
        isLoading: false,
      );
    }
  }

  Future<void> loadAllParcels() async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getAllParcelsSuperAdmin();
      state = state.copyWith(parcels: parcels, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadGarageParcels({String? status}) async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getGarageParcels(status: status);
      state = state.copyWith(parcels: parcels, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadFreeParcels() async {
    try {
      state = state.copyWith(isLoadingFreeParcels: true);
      final parcels = await _apiService.getFreeParcels();
      state = state.copyWith(
        freeParcels: parcels,
        isLoadingFreeParcels: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoadingFreeParcels: false,
      );
    }
  }

  Future<Map<String, dynamic>> createBid(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.createBid(data);
      if (result['success'] == true || result['bid'] != null) {
        final bidData = result['bid'];
        final bidId = bidData is Map ? bidData['id']?.toString() : null;
        await loadFreeParcels();
        state = state.copyWith(isLoading: false, error: null);
        return {'success': true, 'bidId': bidId};
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors de l\'envoi de l\'offre',
        isLoading: false,
      );
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> acceptBid(String parcelId, String bidId) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.acceptBid(parcelId, bidId);
      if (result['success'] == true) {
        await loadSentParcels();
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors de l\'acceptation',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Driver responds to a bid: accept, counter, or reject
  Future<bool> driverRespondToBid(String bidId,
      {required String action, double? price, String? message}) async {
    state = state.copyWith(isLoading: true);
    try {
      final data = <String, dynamic>{'action': action};
      if (price != null) data['price'] = price;
      if (message != null) data['message'] = message;
      final result = await _apiService.driverRespondToBid(bidId, data);
      if (result['success'] == true) {
        await loadDriverParcels();
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors de la réponse',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> rejectBid(String parcelId, String bidId,
      {String? responseMessage}) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.rejectBid(parcelId, bidId,
          responseMessage: responseMessage);
      if (result['success'] == true) {
        await loadSentParcels();
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors du refus',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<List<Bid>> getParcelBids(String parcelId) async {
    try {
      final bids = await _apiService.getParcelBids(parcelId);
      return bids.map((b) => Bid.fromJson(b)).toList();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  Future<Parcel?> createParcel(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      final parcel = await _apiService.createParcel(data);
      await loadSentParcels();
      state = state.copyWith(isLoading: false, error: null, isSuccess: true);
      return parcel;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Corrige un colis pas encore pris en charge. L'API refuse la modification
  /// dès qu'un chauffeur est assigné, qu'une offre est acceptée ou qu'un
  /// paiement est engagé ; son message de refus est remonté tel quel.
  Future<Map<String, dynamic>> updateParcel(
      String parcelId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.updateParcel(parcelId, data);
      if (result['success'] == true) {
        await loadSentParcels();
        state = state.copyWith(isLoading: false, error: null, isSuccess: true);
        return result;
      }
      final message =
          result['message']?.toString() ?? 'Erreur lors de la modification';
      state = state.copyWith(error: message, isLoading: false);
      return {...result, 'success': false, 'message': message};
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Parcel?> trackParcel(String trackingNumber) async {
    state = state.copyWith(isLoading: true);
    try {
      final parcel = await _apiService.trackParcel(trackingNumber);
      state = state.copyWith(
        trackedParcel: parcel,
        isLoading: false,
        error: null,
      );
      return parcel;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Advance parcel lifecycle: confirm, pickup, transit, arrived, out-for-delivery
  Future<Map<String, dynamic>> advanceParcel(String parcelId, String step,
      {String? location, String? otp}) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.advanceParcel(parcelId, step,
          location: location, otp: otp);
      if (result['success'] == true || result['parcel'] != null) {
        await loadDriverParcels();
        state = state.copyWith(isLoading: false, error: null);
        final score = result['score'];
        final credited = score is Map ? score['credited'] : null;
        return {'success': true, if (credited is num) 'points': credited};
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors de la mise à jour',
        isLoading: false,
      );
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Confirm delivery with OTP
  Future<Map<String, dynamic>> deliverParcel(
      String parcelId, Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.driverDeliver(parcelId, data);
      if (result['success'] == true || result['parcel'] != null) {
        await loadDriverParcels();
        state = state.copyWith(isLoading: false, error: null);
        return {'success': true};
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur livraison',
        isLoading: false,
      );
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<ParcelEvent>> getParcelTimeline(String parcelId) async {
    try {
      return await _apiService.getParcelTimeline(parcelId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  /// Annule un colis et retourne le résultat parsé de la réponse de l'API.
  ///
  /// En cas de succès, [CancellationOutcome.result] contient les conséquences
  /// réelles (pénalité, remboursement, wallet, points, dette) telles que le
  /// backend les a calculées. En cas d'échec, `errorMessage` / `errorCode`
  /// portent un libellé exploitable par l'utilisateur.
  Future<CancellationOutcome> cancelParcel(String parcelId,
      {String? reason}) async {
    return _runCancellation(
      () => _apiService.cancelParcel(parcelId, reason: reason),
      onSuccess: loadSentParcels,
    );
  }

  /// Annule une mission assignée par le chauffeur, via son propre endpoint
  /// (`/driver/parcels/:id/cancel`). Le backend reste la seule autorité pour la
  /// pénalité, le wallet, les points, la dette et le remboursement : le mobile
  /// se contente de relire la réponse. Contrairement au client, le chauffeur
  /// rafraîchit ses propres missions après l'annulation.
  Future<CancellationOutcome> cancelDriverParcel(String parcelId,
      {String? reason}) async {
    return _runCancellation(
      () => _apiService.cancelDriverParcel(parcelId, reason: reason),
      onSuccess: loadDriverParcels,
    );
  }

  /// Exécute un appel d'annulation (client ou chauffeur) avec le même contrat :
  /// `success == true` → résultat parsé ; `success == false` / erreur réseau →
  /// un libellé exploitable. Jamais de « succès » inventé après une erreur.
  Future<CancellationOutcome> _runCancellation(
    Future<Map<String, dynamic>> Function() request, {
    required Future<void> Function() onSuccess,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await request();
      if (result['success'] == true) {
        await onSuccess();
        state = state.copyWith(isLoading: false, error: null);
        return CancellationOutcome(
          result: CancellationResult.fromResponse(result),
        );
      }
      final message = result['message']?.toString();
      final code = result['error'] is Map
          ? (result['error'] as Map)['code']?.toString()
          : null;
      final friendly = _cancellationErrorMessage(code, message);
      state = state.copyWith(error: friendly, isLoading: false);
      return CancellationOutcome(errorMessage: friendly, errorCode: code);
    } catch (e) {
      final friendly = 'Impossible d’annuler le colis pour le moment';
      state = state.copyWith(error: friendly, isLoading: false);
      return CancellationOutcome(errorMessage: friendly);
    }
  }

  void reset() {
    state = ParcelState.initial();
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  void clearSuccess() {
    if (state.isSuccess) {
      state = state.copyWith(isSuccess: false);
    }
  }
}

class ParcelState {
  final bool isLoading;
  final List<Parcel> parcels;
  final List<Parcel> sentParcels;
  final List<Parcel> receivedParcels;
  final List<Parcel> freeParcels;
  final Parcel? trackedParcel;
  final String? error;
  final bool isSuccess;
  final bool isLoadingFreeParcels;

  ParcelState({
    required this.isLoading,
    this.parcels = const [],
    this.sentParcels = const [],
    this.receivedParcels = const [],
    this.freeParcels = const [],
    this.trackedParcel,
    this.error,
    this.isSuccess = false,
    this.isLoadingFreeParcels = false,
  });

  factory ParcelState.initial() => ParcelState(
        isLoading: false,
        parcels: const [],
        sentParcels: const [],
        receivedParcels: const [],
        freeParcels: const [],
        trackedParcel: null,
        error: null,
        isSuccess: false,
        isLoadingFreeParcels: false,
      );

  factory ParcelState.loading() => ParcelState(
        isLoading: true,
        parcels: const [],
        sentParcels: const [],
        receivedParcels: const [],
        freeParcels: const [],
        trackedParcel: null,
        error: null,
        isSuccess: false,
        isLoadingFreeParcels: false,
      );

  ParcelState copyWith({
    bool? isLoading,
    List<Parcel>? parcels,
    List<Parcel>? sentParcels,
    List<Parcel>? receivedParcels,
    List<Parcel>? freeParcels,
    Parcel? trackedParcel,
    String? error,
    bool? isSuccess,
    bool? isLoadingFreeParcels,
  }) {
    return ParcelState(
      isLoading: isLoading ?? this.isLoading,
      parcels: parcels ?? this.parcels,
      sentParcels: sentParcels ?? this.sentParcels,
      receivedParcels: receivedParcels ?? this.receivedParcels,
      freeParcels: freeParcels ?? this.freeParcels,
      trackedParcel: trackedParcel ?? this.trackedParcel,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
      isLoadingFreeParcels: isLoadingFreeParcels ?? this.isLoadingFreeParcels,
    );
  }

  bool get hasParcels => parcels.isNotEmpty;
  bool get hasFreeParcels => freeParcels.isNotEmpty;

  List<Parcel> get freeParcelsList => freeParcels;

  List<Parcel> get pendingParcels => parcels
      .where((p) =>
          p.status == ParcelStatus.pending ||
          p.status == ParcelStatus.negotiating ||
          p.status == ParcelStatus.free ||
          p.status == ParcelStatus.confirmed)
      .toList();

  List<Parcel> get inProgressParcels => parcels
      .where((p) =>
          p.status == ParcelStatus.pickedUp ||
          p.status == ParcelStatus.inTransit ||
          p.status == ParcelStatus.arrived ||
          p.status == ParcelStatus.outForDelivery)
      .toList();

  List<Parcel> get completedParcels =>
      parcels.where((p) => p.status == ParcelStatus.delivered).toList();

  List<Parcel> get cancelledParcels =>
      parcels.where((p) => p.status == ParcelStatus.cancelled).toList();

  Map<String, int> get stats => {
        'total': parcels.length,
        'free': freeParcels.length,
        'pending': pendingParcels.length,
        'inProgress': inProgressParcels.length,
        'delivered': completedParcels.length,
        'cancelled': cancelledParcels.length,
      };
}

/// Traduit un code d'erreur d'annulation renvoyé par l'API en un libellé
/// compréhensible. Le message du serveur reste prioritaire : on ne le remplace
/// que lorsque le code est connu et plus parlant.
String _cancellationErrorMessage(String? code, String? message) {
  if (message != null && message.isNotEmpty) return message;
  switch (code?.toUpperCase()) {
    case 'PARCEL_ALREADY_CANCELLED':
    case 'ALREADY_CANCELLED':
      return 'Ce colis a déjà été annulé';
    case 'CANCELLATION_NOT_ALLOWED':
    case 'CANCELLATION_FORBIDDEN':
      return 'Cette annulation n’est pas autorisée';
    case 'CANCELLATION_REASON_REQUIRED':
      return 'Veuillez sélectionner un motif d’annulation valide';
    case 'CANCELLATION_EXEMPT_REASON_FORBIDDEN':
      return 'Ce motif d’annulation est réservé au support';
    case 'STATUS_CHANGED':
      return 'Le statut du colis a changé. Actualisez la page';
    case 'REFUND_IMPOSSIBLE':
      return 'Le remboursement n’est pas possible pour ce colis';
    case 'PAYDUNYA_ERROR':
      return 'Le remboursement via PayDunya a échoué';
    case 'INSUFFICIENT_FUNDS':
      return 'Fonds insuffisants pour cette opération';
    case 'DEBT_LIMIT_EXCEEDED':
      return 'La dette du chauffeur dépasse la limite autorisée';
    default:
      return message ?? 'L’annulation a échoué';
  }
}