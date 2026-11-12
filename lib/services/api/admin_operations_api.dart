// lib/services/api/admin_operations_api.dart
//
// Dashboards admin (ADM-1, OPS-3, OPS-4) + promotion de rôle (OPS-2).

import 'package:dio/dio.dart';

import 'client.dart';

class WebhookDeliveryRow {
  final String id;
  final String partnerName;
  final String eventType;
  final String status;
  final int attempts;
  final int? lastStatusCode;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? nextAttemptAt;

  const WebhookDeliveryRow({
    required this.id,
    required this.partnerName,
    required this.eventType,
    required this.status,
    this.attempts = 0,
    this.lastStatusCode,
    this.createdAt,
    this.deliveredAt,
    this.nextAttemptAt,
  });

  factory WebhookDeliveryRow.fromJson(Map<String, dynamic> j) =>
      WebhookDeliveryRow(
        id: j['id']?.toString() ?? '',
        partnerName: j['partnerName']?.toString() ?? '',
        eventType: j['eventType']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
        lastStatusCode: (j['lastStatusCode'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
        deliveredAt: DateTime.tryParse(j['deliveredAt']?.toString() ?? ''),
        nextAttemptAt:
            DateTime.tryParse(j['nextAttemptAt']?.toString() ?? ''),
      );
}

class StopEventRow {
  final String id;
  final String advertisementId;
  final String driverId;
  final int stopOrder;
  final String? stopLabel;
  final int distanceMeters;
  final int radiusMeters;
  final DateTime? reachedAt;

  const StopEventRow({
    required this.id,
    required this.advertisementId,
    required this.driverId,
    required this.stopOrder,
    this.stopLabel,
    this.distanceMeters = 0,
    this.radiusMeters = 0,
    this.reachedAt,
  });

  factory StopEventRow.fromJson(Map<String, dynamic> j) => StopEventRow(
        id: j['id']?.toString() ?? '',
        advertisementId: j['advertisementId']?.toString() ?? '',
        driverId: j['driverId']?.toString() ?? '',
        stopOrder: (j['stopOrder'] as num?)?.toInt() ?? 0,
        stopLabel: j['stopLabel']?.toString(),
        distanceMeters: (j['distanceMeters'] as num?)?.toInt() ?? 0,
        radiusMeters: (j['radiusMeters'] as num?)?.toInt() ?? 0,
        reachedAt: DateTime.tryParse(j['reachedAt']?.toString() ?? ''),
      );
}

class HandoverRow {
  final String id;
  final String parcelId;
  final String? trackingNumber;
  final String fromDriverId;
  final String toDriverId;
  final String status;
  final DateTime? initiatedAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  const HandoverRow({
    required this.id,
    required this.parcelId,
    this.trackingNumber,
    required this.fromDriverId,
    required this.toDriverId,
    required this.status,
    this.initiatedAt,
    this.confirmedAt,
    this.cancelledAt,
    this.cancellationReason,
  });

  factory HandoverRow.fromJson(Map<String, dynamic> j) => HandoverRow(
        id: j['id']?.toString() ?? '',
        parcelId: j['parcelId']?.toString() ?? '',
        trackingNumber: j['trackingNumber']?.toString(),
        fromDriverId: j['fromDriverId']?.toString() ?? '',
        toDriverId: j['toDriverId']?.toString() ?? '',
        status: j['status']?.toString() ?? '',
        initiatedAt: DateTime.tryParse(j['initiatedAt']?.toString() ?? ''),
        confirmedAt: DateTime.tryParse(j['confirmedAt']?.toString() ?? ''),
        cancelledAt: DateTime.tryParse(j['cancelledAt']?.toString() ?? ''),
        cancellationReason: j['cancellationReason']?.toString(),
      );
}

class IntegrationsHealth {
  final String status;
  final Map<String, dynamic> integrations;
  final DateTime? checkedAt;

  const IntegrationsHealth({
    required this.status,
    this.integrations = const {},
    this.checkedAt,
  });

  factory IntegrationsHealth.fromJson(Map<String, dynamic> j) =>
      IntegrationsHealth(
        status: j['status']?.toString() ?? 'unknown',
        integrations:
            (j['integrations'] as Map?)?.cast<String, dynamic>() ?? const {},
        checkedAt: DateTime.tryParse(j['checkedAt']?.toString() ?? ''),
      );
}

class Pilot14dMetrics {
  final Map<String, dynamic> raw;
  const Pilot14dMetrics(this.raw);
}

class AdminOperationsApi {
  final ApiClient client;

  AdminOperationsApi(this.client);

  Future<List<WebhookDeliveryRow>> recentWebhooks({int limit = 50}) async {
    final res = await client.dio
        .get('/super-admin/webhooks/recent', queryParameters: {'limit': limit});
    final body = client.handle(res);
    final list = (body['deliveries'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => WebhookDeliveryRow.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<StopEventRow>> recentStopEvents({int limit = 50}) async {
    final res = await client.dio.get('/super-admin/stop-events/recent',
        queryParameters: {'limit': limit});
    final body = client.handle(res);
    final list = (body['events'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => StopEventRow.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<HandoverRow>> recentHandovers({int limit = 50}) async {
    final res = await client.dio.get('/super-admin/handovers/recent',
        queryParameters: {'limit': limit});
    final body = client.handle(res);
    final list = (body['handovers'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => HandoverRow.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Pilot14dMetrics> pilot14d({int windowDays = 14}) async {
    final res = await client.dio.get('/super-admin/pilot-metrics/14d',
        queryParameters: {'windowDays': windowDays});
    final body = client.handle(res);
    return Pilot14dMetrics(body);
  }

  Future<IntegrationsHealth> integrationsHealth() async {
    final res = await client.dio.get('/health/integrations');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    return IntegrationsHealth.fromJson(payload);
  }

  Future<String> promoteRole(String userId, String role) async {
    final res = await client.dio.request(
      '/super-admin/users/$userId/role',
      data: {'role': role},
      options: Options(method: 'PATCH'),
    );
    final body = client.handle(res);
    // L'API renvoie l'utilisateur mis à jour. On retourne le rôle actuel pour UX.
    final user = (body['user'] as Map?) ?? (body['data'] as Map?)?['user'];
    return user?['role']?.toString() ?? role;
  }
}
