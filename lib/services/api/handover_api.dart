// lib/services/api/handover_api.dart
//
// Phase 2 — Correspondances inter-véhicules (ParcelHandover).
// Secrets (PIN + QR token) retournés uniquement à l'initiation. Non persistés
// côté mobile au-delà de la phase d'affichage.

import 'client.dart';

class ParcelHandover {
  final String id;
  final String parcelId;
  final String fromDriverId;
  final String toDriverId;
  final String? fromAdvertisementId;
  final String? toAdvertisementId;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? pickupPinLast4;
  final String? pickupProofType;
  final String? cancellationReason;
  final DateTime? initiatedAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  // Secrets exposés UNIQUEMENT lors de la réponse à initiate.
  final String? pickupPin;
  final String? pickupQrToken;

  const ParcelHandover({
    required this.id,
    required this.parcelId,
    required this.fromDriverId,
    required this.toDriverId,
    this.fromAdvertisementId,
    this.toAdvertisementId,
    this.latitude,
    this.longitude,
    required this.status,
    this.pickupPinLast4,
    this.pickupProofType,
    this.cancellationReason,
    this.initiatedAt,
    this.confirmedAt,
    this.cancelledAt,
    this.pickupPin,
    this.pickupQrToken,
  });

  bool get isPending => status == 'pending_pickup';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  factory ParcelHandover.fromJson(Map<String, dynamic> json) => ParcelHandover(
        id: json['id']?.toString() ?? '',
        parcelId: json['parcelId']?.toString() ?? '',
        fromDriverId: json['fromDriverId']?.toString() ?? '',
        toDriverId: json['toDriverId']?.toString() ?? '',
        fromAdvertisementId: json['fromAdvertisementId']?.toString(),
        toAdvertisementId: json['toAdvertisementId']?.toString(),
        latitude: json['latitude'] is num
            ? (json['latitude'] as num).toDouble()
            : null,
        longitude: json['longitude'] is num
            ? (json['longitude'] as num).toDouble()
            : null,
        status: json['status']?.toString() ?? 'pending_pickup',
        pickupPinLast4: json['pickupPinLast4']?.toString(),
        pickupProofType: json['pickupProofType']?.toString(),
        cancellationReason: json['cancellationReason']?.toString(),
        initiatedAt: DateTime.tryParse(json['initiatedAt']?.toString() ?? ''),
        confirmedAt: DateTime.tryParse(json['confirmedAt']?.toString() ?? ''),
        cancelledAt: DateTime.tryParse(json['cancelledAt']?.toString() ?? ''),
        pickupPin: json['pickupPin']?.toString(),
        pickupQrToken: json['pickupQrToken']?.toString(),
      );
}

class HandoverApi {
  final ApiClient client;

  HandoverApi(this.client);

  Future<ParcelHandover> initiate(String parcelId,
      {required String toDriverId, double? latitude, double? longitude}) async {
    final res = await client.dio.post(
      '/parcels/$parcelId/handovers',
      data: {
        'toDriverId': toDriverId,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final handover = (payload['handover'] as Map?)?.cast<String, dynamic>() ?? {};
    return ParcelHandover.fromJson(handover);
  }

  Future<ParcelHandover> confirm(String parcelId, String handoverId,
      {required String pin, required String qrToken}) async {
    final res = await client.dio.post(
      '/parcels/$parcelId/handovers/$handoverId/confirm',
      data: {'pin': pin, 'qrToken': qrToken},
    );
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final handover = (payload['handover'] as Map?)?.cast<String, dynamic>() ?? {};
    return ParcelHandover.fromJson(handover);
  }

  Future<ParcelHandover> cancel(String parcelId, String handoverId,
      {String? reason}) async {
    final res = await client.dio.post(
      '/parcels/$parcelId/handovers/$handoverId/cancel',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final handover = (payload['handover'] as Map?)?.cast<String, dynamic>() ?? {};
    return ParcelHandover.fromJson(handover);
  }

  Future<List<ParcelHandover>> list(String parcelId) async {
    final res = await client.dio.get('/parcels/$parcelId/handovers');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final list = (payload['handovers'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => ParcelHandover.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
