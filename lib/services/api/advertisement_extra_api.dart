// lib/services/api/advertisement_extra_api.dart
//
// Endpoints navette ajoutés en Phase 1+6 :
//  - GET  /advertisements/:id/reached-stops : journal des arrêts atteints.
//  - POST /advertisements/:id/optimize-route : ordre de visite optimal.

import 'client.dart';

class ReachedStopEvent {
  final int stopOrder;
  final String? stopLabel;
  final String? zoneId;
  final int distanceMeters;
  final int radiusMeters;
  final DateTime? reachedAt;
  final int confirmedBy;

  const ReachedStopEvent({
    required this.stopOrder,
    this.stopLabel,
    this.zoneId,
    this.distanceMeters = 0,
    this.radiusMeters = 0,
    this.reachedAt,
    this.confirmedBy = 1,
  });

  factory ReachedStopEvent.fromJson(Map<String, dynamic> json) =>
      ReachedStopEvent(
        stopOrder: json['stopOrder'] is num ? (json['stopOrder'] as num).toInt() : 0,
        stopLabel: json['stopLabel']?.toString(),
        zoneId: json['zoneId']?.toString(),
        distanceMeters: json['distanceMeters'] is num
            ? (json['distanceMeters'] as num).toInt()
            : 0,
        radiusMeters: json['radiusMeters'] is num
            ? (json['radiusMeters'] as num).toInt()
            : 0,
        reachedAt: DateTime.tryParse(json['reachedAt']?.toString() ?? ''),
        confirmedBy: json['confirmedBy'] is num
            ? (json['confirmedBy'] as num).toInt()
            : 1,
      );
}

class ReachedStopsResult {
  final String advertisementId;
  final String? transitLineId;
  final List<ReachedStopEvent> reachedStops;

  const ReachedStopsResult({
    required this.advertisementId,
    this.transitLineId,
    this.reachedStops = const [],
  });

  factory ReachedStopsResult.fromJson(Map<String, dynamic> json) =>
      ReachedStopsResult(
        advertisementId: json['advertisementId']?.toString() ?? '',
        transitLineId: json['transitLineId']?.toString(),
        reachedStops: (json['reachedStops'] as List?)
                ?.whereType<Map>()
                .map((e) => ReachedStopEvent.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class OptimizedStop {
  final String offerId;
  final String? parcelId;
  final String? trackingNumber;
  final String? receiverName;
  final double latitude;
  final double longitude;
  final int? dropOffStopOrder;

  const OptimizedStop({
    required this.offerId,
    this.parcelId,
    this.trackingNumber,
    this.receiverName,
    required this.latitude,
    required this.longitude,
    this.dropOffStopOrder,
  });

  factory OptimizedStop.fromJson(Map<String, dynamic> json) => OptimizedStop(
        offerId: json['offerId']?.toString() ?? '',
        parcelId: json['parcelId']?.toString(),
        trackingNumber: json['trackingNumber']?.toString(),
        receiverName: json['receiverName']?.toString(),
        latitude: json['latitude'] is num
            ? (json['latitude'] as num).toDouble()
            : 0,
        longitude: json['longitude'] is num
            ? (json['longitude'] as num).toDouble()
            : 0,
        dropOffStopOrder: json['dropOffStopOrder'] is num
            ? (json['dropOffStopOrder'] as num).toInt()
            : null,
      );
}

class OptimizedRoute {
  final String advertisementId;
  final Map<String, double>? origin;
  final List<OptimizedStop> ordered;
  final double distanceKm;
  final double improvedBy;
  final int iterations;

  const OptimizedRoute({
    required this.advertisementId,
    this.origin,
    this.ordered = const [],
    this.distanceKm = 0,
    this.improvedBy = 0,
    this.iterations = 0,
  });

  factory OptimizedRoute.fromJson(Map<String, dynamic> json) {
    final rawOrigin = (json['origin'] as Map?)?.cast<String, dynamic>();
    return OptimizedRoute(
      advertisementId: json['advertisementId']?.toString() ?? '',
      origin: rawOrigin != null
          ? {
              'latitude': (rawOrigin['latitude'] as num?)?.toDouble() ?? 0,
              'longitude': (rawOrigin['longitude'] as num?)?.toDouble() ?? 0,
            }
          : null,
      ordered: (json['ordered'] as List?)
              ?.whereType<Map>()
              .map((e) => OptimizedStop.fromJson(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      distanceKm:
          json['distanceKm'] is num ? (json['distanceKm'] as num).toDouble() : 0,
      improvedBy:
          json['improvedBy'] is num ? (json['improvedBy'] as num).toDouble() : 0,
      iterations:
          json['iterations'] is num ? (json['iterations'] as num).toInt() : 0,
    );
  }
}

// Phase 2 — Confirmation chauffeur par colis à l'arrêt. Deux entrées par offre :
// pickup à l'embarquement, dropoff à la remise. Le backend applique l'idempotence
// applicative : POST sur une (offer, type) déjà confirmée renvoie 200.
enum StopConfirmationType { pickup, dropoff }

class ShuttleStopConfirmation {
  final String id;
  final String advertisementId;
  final String offerId;
  final String driverId;
  final int stopOrder;
  final StopConfirmationType type;
  final double? latitude;
  final double? longitude;
  final String? note;
  final DateTime confirmedAt;

  const ShuttleStopConfirmation({
    required this.id,
    required this.advertisementId,
    required this.offerId,
    required this.driverId,
    required this.stopOrder,
    required this.type,
    this.latitude,
    this.longitude,
    this.note,
    required this.confirmedAt,
  });

  factory ShuttleStopConfirmation.fromJson(Map<String, dynamic> json) {
    return ShuttleStopConfirmation(
      id: json['id']?.toString() ?? '',
      advertisementId: json['advertisementId']?.toString() ?? '',
      offerId: json['offerId']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      stopOrder: json['stopOrder'] is num ? (json['stopOrder'] as num).toInt() : 0,
      type: json['type'] == 'dropoff'
          ? StopConfirmationType.dropoff
          : StopConfirmationType.pickup,
      latitude: json['latitude'] is num ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] is num ? (json['longitude'] as num).toDouble() : null,
      note: json['note']?.toString(),
      confirmedAt:
          DateTime.tryParse(json['confirmedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ConfirmStopResult {
  final ShuttleStopConfirmation confirmation;
  final bool created;

  const ConfirmStopResult({required this.confirmation, required this.created});
}

class AdvertisementExtraApi {
  final ApiClient client;

  AdvertisementExtraApi(this.client);

  Future<ReachedStopsResult> fetchReachedStops(String advertisementId) async {
    final res = await client.dio
        .get('/advertisements/$advertisementId/reached-stops');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    return ReachedStopsResult.fromJson(payload);
  }

  Future<OptimizedRoute> optimizeRoute(String advertisementId,
      {Map<String, dynamic>? config}) async {
    final res = await client.dio.post(
      '/advertisements/$advertisementId/optimize-route',
      data: config != null ? {'config': config} : {},
    );
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    return OptimizedRoute.fromJson(payload);
  }

  Future<List<ShuttleStopConfirmation>> fetchStopConfirmations(
      String advertisementId) async {
    final res = await client.dio
        .get('/advertisements/$advertisementId/stop-confirmations');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final rows = (payload['confirmations'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((e) => ShuttleStopConfirmation.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<ConfirmStopResult> confirmStop({
    required String advertisementId,
    required String offerId,
    required StopConfirmationType type,
    double? latitude,
    double? longitude,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'type': type == StopConfirmationType.dropoff ? 'dropoff' : 'pickup',
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    final res = await client.dio.post(
      '/advertisements/$advertisementId/offers/$offerId/stop-confirmations',
      data: payload,
    );
    final body = client.handle(res);
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final created = data['created'] == true;
    final confirmationJson =
        (data['confirmation'] as Map?)?.cast<String, dynamic>() ?? {};
    return ConfirmStopResult(
      confirmation: ShuttleStopConfirmation.fromJson(confirmationJson),
      created: created,
    );
  }
}
