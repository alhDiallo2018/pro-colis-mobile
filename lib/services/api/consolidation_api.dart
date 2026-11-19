// lib/services/api/consolidation_api.dart
//
// Backhaul / consolidation — suggestions de colis à adopter pour une annonce
// driver donnée. Parité avec `lib/api/consolidation.ts` côté web.
//
// Endpoint : `GET /drivers/backhaul-matches/:advertisementId`
// RBAC : driver propriétaire de l'annonce ou shuttle_operator.

import 'client.dart';

class BackhaulMatch {
  final String id;
  final String? trackingNumber;
  final String? senderName;
  final double weightKg;
  final double? price;
  final DateTime? createdAt;
  final String status;
  final bool compatible;
  final int? score;
  final List<String> reasons;
  final double? detourKm;

  const BackhaulMatch({
    required this.id,
    required this.status,
    required this.weightKg,
    required this.compatible,
    required this.reasons,
    this.trackingNumber,
    this.senderName,
    this.price,
    this.createdAt,
    this.score,
    this.detourKm,
  });

  factory BackhaulMatch.fromJson(Map<String, dynamic> j) {
    final reasonsRaw = (j['reasons'] as List?) ?? const [];
    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return BackhaulMatch(
      id: j['id']?.toString() ?? '',
      trackingNumber: j['trackingNumber']?.toString(),
      senderName: j['senderName']?.toString(),
      weightKg: asDouble(j['weightKg']) ?? 0,
      price: asDouble(j['price']),
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      status: j['status']?.toString() ?? '',
      compatible: j['compatible'] == true,
      score: (j['score'] as num?)?.toInt(),
      reasons:
          reasonsRaw.map((r) => r.toString()).where((s) => s.isNotEmpty).toList(),
      detourKm: asDouble(j['detourKm']),
    );
  }
}

class BackhaulResponse {
  final List<BackhaulMatch> matches;
  final List<BackhaulMatch> rejected;

  const BackhaulResponse({required this.matches, required this.rejected});
}

/// Libellés UX pour les codes `reasons` renvoyés par le matcher.
const Map<String, String> kBackhaulReasonLabels = {
  'disabled': 'Consolidation désactivée',
  'invalid_trip': 'Trajet invalide',
  'status_not_adoptable': 'Colis déjà pris',
  'overweight': 'Trop lourd pour la capacité restante',
  'off_route': 'Trop loin du trajet',
  'missing_pickup_zone': 'Zone de retrait manquante',
  'missing_dropoff_zone': 'Zone de livraison manquante',
};

class ConsolidationApi {
  final ApiClient client;

  ConsolidationApi(this.client);

  Future<BackhaulResponse> fetchBackhaulMatches(String advertisementId) async {
    final res = await client.dio.get('/drivers/backhaul-matches/$advertisementId');
    final body = client.handle(res);
    final payload =
        (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final matches = (payload['matches'] as List?) ?? const [];
    final rejected = (payload['rejected'] as List?) ?? const [];
    return BackhaulResponse(
      matches: matches
          .whereType<Map>()
          .map((e) => BackhaulMatch.fromJson(e.cast<String, dynamic>()))
          .toList(),
      rejected: rejected
          .whereType<Map>()
          .map((e) => BackhaulMatch.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
