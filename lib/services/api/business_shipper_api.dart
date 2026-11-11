// lib/services/api/business_shipper_api.dart
//
// Dashboard B2B de l'expéditeur professionnel. Consomme
// `GET /business-shipper/dashboard` qui agrège les colis de l'utilisateur
// authentifié sur une période (query `from` / `to` ISO 8601 — par défaut
// les 30 derniers jours).
//
// Le backend renvoie `{ period, stats }` : on garde la même décomposition
// côté mobile pour que le composant d'écran puisse afficher la période
// consultée à côté des KPI.

import 'client.dart';

class ShipperTopDestination {
  final String zoneId;
  final String name;
  final int count;

  const ShipperTopDestination(
      {required this.zoneId, required this.name, required this.count});

  factory ShipperTopDestination.fromJson(Map<String, dynamic> json) =>
      ShipperTopDestination(
        zoneId: json['zoneId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        count: json['count'] is num ? (json['count'] as num).toInt() : 0,
      );
}

class ShipperDailyVolume {
  final String date; // yyyy-MM-dd
  final int count;

  const ShipperDailyVolume({required this.date, required this.count});

  factory ShipperDailyVolume.fromJson(Map<String, dynamic> json) =>
      ShipperDailyVolume(
        date: json['date']?.toString() ?? '',
        count: json['count'] is num ? (json['count'] as num).toInt() : 0,
      );
}

class ShipperStats {
  final int volumeTotal;
  final int volumeDelivered;
  final int volumeInProgress;
  final int volumeCancelled;

  /// `null` si aucun colis n'a de prix renseigné sur la période.
  final double? averageCost;
  final double totalBilled;

  /// Pourcentage [0,100] de livraisons à l'heure. `null` si aucun colis
  /// livré n'avait d'`estimatedDeliveryDate` pour comparer.
  final int? slaOnTimePercent;

  final List<ShipperTopDestination> topDestinations;
  final List<ShipperDailyVolume> byDay;

  const ShipperStats({
    this.volumeTotal = 0,
    this.volumeDelivered = 0,
    this.volumeInProgress = 0,
    this.volumeCancelled = 0,
    this.averageCost,
    this.totalBilled = 0,
    this.slaOnTimePercent,
    this.topDestinations = const [],
    this.byDay = const [],
  });

  factory ShipperStats.fromJson(Map<String, dynamic> json) => ShipperStats(
        volumeTotal: json['volumeTotal'] is num
            ? (json['volumeTotal'] as num).toInt()
            : 0,
        volumeDelivered: json['volumeDelivered'] is num
            ? (json['volumeDelivered'] as num).toInt()
            : 0,
        volumeInProgress: json['volumeInProgress'] is num
            ? (json['volumeInProgress'] as num).toInt()
            : 0,
        volumeCancelled: json['volumeCancelled'] is num
            ? (json['volumeCancelled'] as num).toInt()
            : 0,
        averageCost: json['averageCost'] is num
            ? (json['averageCost'] as num).toDouble()
            : null,
        totalBilled: json['totalBilled'] is num
            ? (json['totalBilled'] as num).toDouble()
            : 0,
        slaOnTimePercent: json['slaOnTimePercent'] is num
            ? (json['slaOnTimePercent'] as num).toInt()
            : null,
        topDestinations: (json['topDestinations'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    ShipperTopDestination.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        byDay: (json['byDay'] as List?)
                ?.whereType<Map>()
                .map(
                    (e) => ShipperDailyVolume.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
      );
}

class ShipperDashboard {
  final DateTime? from;
  final DateTime? to;
  final ShipperStats stats;

  const ShipperDashboard(
      {this.from, this.to, this.stats = const ShipperStats()});

  factory ShipperDashboard.fromJson(Map<String, dynamic> json) {
    final period = (json['period'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stats = (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ShipperDashboard(
      from: DateTime.tryParse(period['from']?.toString() ?? ''),
      to: DateTime.tryParse(period['to']?.toString() ?? ''),
      stats: ShipperStats.fromJson(stats),
    );
  }
}

class BusinessShipperApi {
  final ApiClient client;

  BusinessShipperApi(this.client);

  /// Les bornes [from] / [to] sont optionnelles ; l'API retombe sur 30 jours.
  Future<ShipperDashboard> getDashboard({DateTime? from, DateTime? to}) async {
    final res = await client.dio.get(
      '/business-shipper/dashboard',
      queryParameters: {
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
    );
    final body = client.handle(res);
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    return ShipperDashboard.fromJson(data);
  }
}
