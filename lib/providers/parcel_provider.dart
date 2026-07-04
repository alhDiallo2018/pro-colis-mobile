// mobile/lib/providers/parcel_provider.dart
// Aligné sur l'API Web ProColis

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/parcel.dart';
import '../services/api_service.dart';

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

  Future<void> loadDriverParcels() async {
    state = state.copyWith(isLoading: true);
    try {
      final parcels = await _apiService.getDriverParcels();
      state = state.copyWith(parcels: parcels, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
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
        await loadFreeParcels();
        state = state.copyWith(isLoading: false, error: null);
        return {'success': true};
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
        await loadMyParcels();
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

  Future<bool> rejectBid(String parcelId, String bidId,
      {String? responseMessage}) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.rejectBid(parcelId, bidId,
          responseMessage: responseMessage);
      if (result['success'] == true) {
        await loadMyParcels();
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
      await loadMyParcels();
      state = state.copyWith(
          isLoading: false, error: null, isSuccess: true);
      return parcel;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
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
        return {'success': true};
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
  Future<Map<String, dynamic>> deliverParcel(String parcelId,
      Map<String, dynamic> data) async {
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

  Future<bool> assignDriverToParcel(
      String parcelId, String driverId) async {
    state = state.copyWith(isLoading: true);
    try {
      final result =
          await _apiService.assignDriverToParcel(parcelId, driverId);
      if (result['success'] == true) {
        await loadGarageParcels();
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur assignation',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  Future<bool> cancelParcel(String parcelId, {String? reason}) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.cancelParcel(parcelId, reason: reason);
      if (result['success'] == true) {
        await loadMyParcels();
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur annulation',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
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

  factory ParcelState.initial() => ParcelState(
        isLoading: false,
        parcels: const [],
        freeParcels: const [],
        trackedParcel: null,
        error: null,
        isSuccess: false,
        isLoadingFreeParcels: false,
      );

  factory ParcelState.loading() => ParcelState(
        isLoading: true,
        parcels: const [],
        freeParcels: const [],
        trackedParcel: null,
        error: null,
        isSuccess: false,
        isLoadingFreeParcels: false,
      );

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

  bool get hasParcels => parcels.isNotEmpty;
  bool get hasFreeParcels => freeParcels.isNotEmpty;

  List<Parcel> get freeParcelsList => freeParcels;

  List<Parcel> get pendingParcels =>
      parcels.where((p) =>
          p.status == ParcelStatus.pending ||
          p.status == ParcelStatus.free ||
          p.status == ParcelStatus.confirmed).toList();

  List<Parcel> get inProgressParcels =>
      parcels.where((p) =>
          p.status == ParcelStatus.pickedUp ||
          p.status == ParcelStatus.inTransit ||
          p.status == ParcelStatus.arrived ||
          p.status == ParcelStatus.outForDelivery).toList();

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
