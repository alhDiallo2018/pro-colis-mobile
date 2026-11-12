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
}
