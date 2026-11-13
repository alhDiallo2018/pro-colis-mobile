// lib/services/api/shipment_batch_api.dart
//
// Phase 4 — Expéditions groupées B2B/e-commerce (ShipmentBatch).
// Statut workflow : draft → open → closed/cancelled.

import 'client.dart';

class ShipmentBatchParcel {
  final String id;
  final String? trackingNumber;
  final double weight;
  final String? status;
  final String? receiverName;

  const ShipmentBatchParcel({
    required this.id,
    this.trackingNumber,
    this.weight = 0,
    this.status,
    this.receiverName,
  });

  factory ShipmentBatchParcel.fromJson(Map<String, dynamic> json) =>
      ShipmentBatchParcel(
        id: json['id']?.toString() ?? '',
        trackingNumber: json['trackingNumber']?.toString(),
        weight:
            json['weight'] is num ? (json['weight'] as num).toDouble() : 0,
        status: json['status']?.toString(),
        receiverName: json['receiverName']?.toString(),
      );
}

class ShipmentBatch {
  final String id;
  final String creatorId;
  final String? reference;
  final String? label;
  final String status;
  final int totalParcels;
  final double totalWeightKg;
  final double? totalAmount;
  final String? currency;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ShipmentBatchParcel> parcels;

  const ShipmentBatch({
    required this.id,
    required this.creatorId,
    this.reference,
    this.label,
    required this.status,
    this.totalParcels = 0,
    this.totalWeightKg = 0,
    this.totalAmount,
    this.currency,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
    this.parcels = const [],
  });

  bool get isMutable => status == 'draft' || status == 'open';

  factory ShipmentBatch.fromJson(Map<String, dynamic> json) => ShipmentBatch(
        id: json['id']?.toString() ?? '',
        creatorId: json['creatorId']?.toString() ?? '',
        reference: json['reference']?.toString(),
        label: json['label']?.toString(),
        status: json['status']?.toString() ?? 'draft',
        totalParcels: json['totalParcels'] is num
            ? (json['totalParcels'] as num).toInt()
            : 0,
        totalWeightKg: json['totalWeightKg'] is num
            ? (json['totalWeightKg'] as num).toDouble()
            : 0,
        totalAmount: json['totalAmount'] is num
            ? (json['totalAmount'] as num).toDouble()
            : null,
        currency: json['currency']?.toString(),
        closedAt: DateTime.tryParse(json['closedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
        parcels: (json['parcels'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    ShipmentBatchParcel.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class ShipmentBatchApi {
  final ApiClient client;

  ShipmentBatchApi(this.client);

  Future<List<ShipmentBatch>> list({String? status}) async {
    final res = await client.dio.get('/shipment-batches', queryParameters: {
      if (status != null) 'status': status,
    });
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final list = (payload['batches'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => ShipmentBatch.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ShipmentBatch> get(String batchId) async {
    final res = await client.dio.get('/shipment-batches/$batchId');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final batch = (payload['batch'] as Map?)?.cast<String, dynamic>() ?? {};
    return ShipmentBatch.fromJson(batch);
  }

  Future<ShipmentBatch> create({String? reference, String? label}) async {
    final res = await client.dio.post('/shipment-batches', data: {
      if (reference != null) 'reference': reference,
      if (label != null) 'label': label,
    });
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final batch = (payload['batch'] as Map?)?.cast<String, dynamic>() ?? {};
    return ShipmentBatch.fromJson(batch);
  }

  Future<ShipmentBatch> attach(String batchId, List<String> parcelIds) async {
    final res = await client.dio.post(
      '/shipment-batches/$batchId/parcels',
      data: {'parcelIds': parcelIds},
    );
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final batch = (payload['batch'] as Map?)?.cast<String, dynamic>() ?? {};
    return ShipmentBatch.fromJson(batch);
  }

  Future<ShipmentBatch> detach(String batchId, String parcelId) async {
    final res =
        await client.dio.delete('/shipment-batches/$batchId/parcels/$parcelId');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final batch = (payload['batch'] as Map?)?.cast<String, dynamic>() ?? {};
    return ShipmentBatch.fromJson(batch);
  }

  Future<ShipmentBatch> close(String batchId) async {
    final res = await client.dio.post('/shipment-batches/$batchId/close');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final batch = (payload['batch'] as Map?)?.cast<String, dynamic>() ?? {};
    return ShipmentBatch.fromJson(batch);
  }

  /// Récupère les événements de tournée du lot (arrivée arrêt, incident, etc.).
  /// Renvoie une liste vide si l'endpoint n'existe pas encore (404) — la
  /// section UI s'affichera alors avec « Aucun événement enregistré ».
  Future<List<ShipmentBatchStopEvent>> stopEvents(String batchId) async {
    try {
      final res = await client.dio
          .get('/shipment-batches/$batchId/stop-events');
      final body = client.handle(res);
      final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
      final list = (payload['events'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) =>
              ShipmentBatchStopEvent.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class ShipmentBatchStopEvent {
  final String id;
  final String type;
  final String? label;
  final String? description;
  final DateTime? occurredAt;
  final String? parcelId;
  final String? stopLabel;

  const ShipmentBatchStopEvent({
    required this.id,
    required this.type,
    this.label,
    this.description,
    this.occurredAt,
    this.parcelId,
    this.stopLabel,
  });

  factory ShipmentBatchStopEvent.fromJson(Map<String, dynamic> json) =>
      ShipmentBatchStopEvent(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'event',
        label: json['label']?.toString(),
        description: json['description']?.toString(),
        occurredAt: DateTime.tryParse(json['occurredAt']?.toString() ?? ''),
        parcelId: json['parcelId']?.toString(),
        stopLabel: json['stopLabel']?.toString(),
      );
}
