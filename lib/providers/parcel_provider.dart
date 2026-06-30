// mobile/lib/providers/parcel_provider.dart
// ignore_for_file: unrelated_type_equality_checks, avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/parcel.dart';
import '../services/api_service.dart';

// Provider pour le gestionnaire des colis
final parcelProvider =
    StateNotifierProvider<ParcelNotifier, ParcelState>((ref) {
  return ParcelNotifier();
});

class ParcelNotifier extends StateNotifier<ParcelState> {
  ParcelNotifier() : super(ParcelState.initial());

  final ApiService _apiService = ApiService();

  // Charger tous les colis de l'utilisateur (client)
  Future<void> loadMyParcels({String? status}) async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getMyParcels(status: status);
      state = state.copyWith(
        parcels: parcels,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // Charger les colis assignés au chauffeur
  Future<void> loadDriverParcels() async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getDriverParcels();
      state = state.copyWith(
        parcels: parcels,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // Charger tous les colis (Super Admin)
  Future<void> loadAllParcels() async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getAllParcelsSuperAdmin();
      state = state.copyWith(
        parcels: parcels,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // Charger les colis d'un garage (Admin Garage)
  Future<void> loadGarageParcels({String? status}) async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getGarageParcels(status: status);
      state = state.copyWith(
        parcels: parcels,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // Charger les colis en libre service (marchandage)
  Future<void> loadFreeParcels() async {
  try {
    state = state.copyWith(isLoadingFreeParcels: true);

    final parcels = await _apiService.getFreeParcels();

    // ✅ Les offres sont déjà incluses dans les colis
    // Pas besoin de les recharger séparément

    debugPrint('📦 ${parcels.length} colis en libre service chargés');
    for (var parcel in parcels) {
      debugPrint('📦 Colis: ${parcel.trackingNumber} - ${parcel.bids.length} offres');
      for (var bid in parcel.bids) {
        debugPrint('   - ${bid.driverName}: ${bid.price} FCFA (${bid.status.label})');
      }
    }

    state = state.copyWith(
      freeParcels: parcels,
      isLoadingFreeParcels: false,
      error: null,
    );
  } catch (e) {
    debugPrint('❌ Erreur loadFreeParcels: $e');
    state = state.copyWith(
      error: e.toString(),
      isLoadingFreeParcels: false,
    );
  }
}

  // Faire une offre sur un colis (chauffeur)
  Future<Map<String, dynamic>> makeBid(
      String parcelId, Map<String, dynamic> bidData) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.makeBid(parcelId, bidData);
      if (result['success'] == true) {
        // Rafraîchir les colis en libre service
        await loadFreeParcels();
        state = state.copyWith(
          isLoading: false,
          error: null,
        );
        return result;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors de l\'envoi de l\'offre',
        isLoading: false,
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return {'success': false, 'message': e.toString()};
    }
  }

  // Accepter une offre (client)
  Future<bool> acceptBid(String parcelId, String bidId) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.acceptBid(parcelId, bidId);
      if (result['success'] == true) {
        // Rafraîchir les listes
        await loadMyParcels();
        await loadFreeParcels();
        state = state.copyWith(
          isLoading: false,
          error: null,
        );
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors de l\'acceptation de l\'offre',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return false;
    }
  }

  // Refuser une offre (client)
  Future<bool> rejectBid(String parcelId, String bidId,
      {String? responseMessage}) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.rejectBid(parcelId, bidId,
          responseMessage: responseMessage);
      if (result['success'] == true) {
        await loadMyParcels();
        await loadFreeParcels();
        state = state.copyWith(
          isLoading: false,
          error: null,
        );
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors du refus de l\'offre',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return false;
    }
  }

  // Mettre un colis en libre service
  Future<bool> setParcelFreeForBidding(String parcelId,
      {double? proposedPrice}) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.setParcelFreeForBidding(parcelId,
          proposedPrice: proposedPrice);
      if (result['success'] == true) {
        await loadMyParcels();
        await loadFreeParcels();
        state = state.copyWith(
          isLoading: false,
          error: null,
        );
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors de la mise en libre service',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return false;
    }
  }

  // Obtenir les offres d'un colis
  Future<List<Bid>> getParcelBids(String parcelId) async {
    try {
      final bids = await _apiService.getParcelBids(parcelId);
      return bids.map((b) => Bid.fromJson(b)).toList();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  // Créer un nouveau colis
  Future<Parcel?> createParcel(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      final Parcel parcel = await _apiService.createParcel(data);
      await loadMyParcels();
      state = state.copyWith(
        isLoading: false,
        error: null,
        isSuccess: true,
      );
      return parcel;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return null;
    }
  }

  // Suivre un colis par numéro de tracking
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
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return null;
    }
  }

  // Mettre à jour le statut d'un colis
  Future<Parcel?> updateParcelStatus(String parcelId, String status,
      {String? location}) async {
    state = state.copyWith(isLoading: true);
    try {
      final parcel = await _apiService.updateParcelStatus(parcelId, status,
          location: location);
      await loadMyParcels();
      state = state.copyWith(
        isLoading: false,
        error: null,
      );
      return parcel;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return null;
    }
  }

  // Récupérer les événements d'un colis
  Future<List<ParcelEvent>> getParcelEvents(String parcelId) async {
    try {
      final events = await _apiService.getParcelEvents(parcelId);
      return events;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  // Marquer un colis comme ramassé (chauffeur)
  Future<void> markAsPickedUp(String parcelId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _apiService.updateParcelStatus(parcelId, 'picked_up',
          location: 'Au garage');
      await loadDriverParcels();
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Marquer un colis comme en transit (chauffeur)
  Future<void> markAsInTransit(String parcelId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _apiService.updateParcelStatus(parcelId, 'in_transit');
      await loadDriverParcels();
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Marquer un colis comme livré (chauffeur)
  Future<void> markAsDelivered(String parcelId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _apiService.updateParcelStatus(parcelId, 'delivered',
          location: 'Au destinataire');
      await loadDriverParcels();
      state = state.copyWith(isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // Assigner un chauffeur à un colis (Admin Garage)
  Future<bool> assignDriverToParcel(String parcelId, String driverId) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.assignDriverToParcel(parcelId, driverId);
      if (result['success'] == true) {
        await loadGarageParcels();
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors de l\'assignation',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  // Annuler un colis
  Future<bool> cancelParcel(String parcelId, {String? reason}) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.cancelParcel(parcelId, reason: reason);
      if (result['success'] == true) {
        await loadMyParcels();
        await loadFreeParcels();
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur lors de l\'annulation',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  // Réinitialiser l'état
  void reset() {
    state = ParcelState.initial();
  }

  // Effacer les erreurs
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  // Réinitialiser le succès
  void clearSuccess() {
    if (state.isSuccess) {
      state = state.copyWith(isSuccess: false);
    }
  }
}

// État du provider
class ParcelState {
  final bool isLoading;
  final List<Parcel> parcels;
  final List<Parcel> freeParcels;
  final Parcel? trackedParcel;
  final String? error;
  final bool isSuccess;
  final bool isLoadingFreeParcels;

  ParcelState({
    required this.isLoading,
    this.parcels = const [],
    this.freeParcels = const [],
    this.trackedParcel,
    this.error,
    this.isSuccess = false,
    this.isLoadingFreeParcels = false,
  });

  // État initial
  factory ParcelState.initial() => ParcelState(
        isLoading: false,
        parcels: const [],
        freeParcels: const [],
        trackedParcel: null,
        error: null,
        isSuccess: false,
        isLoadingFreeParcels: false,
      );

  // État de chargement
  factory ParcelState.loading() => ParcelState(
        isLoading: true,
        parcels: const [],
        freeParcels: const [],
        trackedParcel: null,
        error: null,
        isSuccess: false,
        isLoadingFreeParcels: false,
      );

  // État avec liste de colis chargée
  factory ParcelState.loaded(List<Parcel> parcels) => ParcelState(
        isLoading: false,
        parcels: parcels,
        freeParcels: const [],
        trackedParcel: null,
        error: null,
        isSuccess: true,
        isLoadingFreeParcels: false,
      );

  // État avec colis suivi
  factory ParcelState.tracked(Parcel parcel) => ParcelState(
        isLoading: false,
        parcels: const [],
        freeParcels: const [],
        trackedParcel: parcel,
        error: null,
        isSuccess: true,
        isLoadingFreeParcels: false,
      );

  // État d'erreur
  factory ParcelState.error(String error) => ParcelState(
        isLoading: false,
        parcels: const [],
        freeParcels: const [],
        trackedParcel: null,
        error: error,
        isSuccess: false,
        isLoadingFreeParcels: false,
      );

  // Méthode copyWith pour créer une nouvelle instance avec des champs modifiés
  ParcelState copyWith({
    bool? isLoading,
    List<Parcel>? parcels,
    List<Parcel>? freeParcels,
    Parcel? trackedParcel,
    String? error,
    bool? isSuccess,
    bool? isLoadingFreeParcels,
  }) {
    return ParcelState(
      isLoading: isLoading ?? this.isLoading,
      parcels: parcels ?? this.parcels,
      freeParcels: freeParcels ?? this.freeParcels,
      trackedParcel: trackedParcel ?? this.trackedParcel,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
      isLoadingFreeParcels: isLoadingFreeParcels ?? this.isLoadingFreeParcels,
    );
  }

  // ==================== GETTERS UTILES ====================

  bool get hasParcels => parcels.isNotEmpty;
  bool get hasFreeParcels => freeParcels.isNotEmpty;

  // Obtenir les colis par statut
  List<Parcel> getParcelsByStatus(ParcelStatus status) {
    return parcels.where((parcel) => parcel.status == status).toList();
  }

  // Colis en libre service (marchandage)
  List<Parcel> get freeParcelsList {
    return freeParcels;
  }

  // Colis en attente de ramassage
  List<Parcel> get pendingParcels {
    return parcels
        .where((parcel) =>
            parcel.status == ParcelStatus.pending ||
            parcel.status == ParcelStatus.free ||
            parcel.status == ParcelStatus.confirmed)
        .toList();
  }

  // Colis en cours
  List<Parcel> get inProgressParcels {
    return parcels
        .where((parcel) =>
            parcel.status == ParcelStatus.pickedUp ||
            parcel.status == ParcelStatus.inTransit ||
            parcel.status == ParcelStatus.arrived ||
            parcel.status == ParcelStatus.outForDelivery)
        .toList();
  }

  // Colis terminés
  List<Parcel> get completedParcels {
    return parcels
        .where((parcel) => parcel.status == ParcelStatus.delivered)
        .toList();
  }

  // Colis annulés
  List<Parcel> get cancelledParcels {
    return parcels
        .where((parcel) => parcel.status == ParcelStatus.cancelled)
        .toList();
  }

  // Colis avec offres reçues
  List<Parcel> get parcelsWithBids {
    return parcels
        .where((parcel) => parcel.isFreeForBidding && parcel.bids.isNotEmpty)
        .toList();
  }

  // Statistiques globales
  Map<String, int> get stats {
    return {
      'total': parcels.length,
      'free': freeParcels.length,
      'pending': pendingParcels.length,
      'inProgress': inProgressParcels.length,
      'delivered': completedParcels.length,
      'cancelled': cancelledParcels.length,
      'withBids': parcelsWithBids.length,
    };
  }

  // Statistiques pour le marchandage
  Map<String, dynamic> get biddingStats {
    int totalOffers = 0;
    int pendingOffers = 0;
    int acceptedOffers = 0;

    for (final parcel in parcels) {
      totalOffers += parcel.bids.length;
      pendingOffers += parcel.pendingBids.length;
      acceptedOffers += parcel.acceptedBids.length;
    }

    return {
      'totalParcelsFree': freeParcels.length,
      'totalOffers': totalOffers,
      'pendingOffers': pendingOffers,
      'acceptedOffers': acceptedOffers,
    };
  }
}