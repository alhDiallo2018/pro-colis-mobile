// lib/services/api/fraud_api.dart
//
// Fraude — scores live + alertes persistées. Parité avec
// `lib/api/admin-operations.ts` côté web (sections Fraude).
//
// Endpoints (RBAC super_admin) :
//   - GET  /super-admin/fraud/scores?limit=&level=
//   - GET  /super-admin/fraud/alerts?status=open|resolved
//   - POST /super-admin/fraud/alerts/:id/resolve  body: { notes }
//   - POST /super-admin/fraud/refresh

import 'package:dio/dio.dart';

import 'client.dart';

enum FraudLevel { safe, low, medium, high }

FraudLevel parseFraudLevel(dynamic raw) {
  final v = raw?.toString().toLowerCase();
  switch (v) {
    case 'high':
      return FraudLevel.high;
    case 'medium':
      return FraudLevel.medium;
    case 'low':
      return FraudLevel.low;
    default:
      return FraudLevel.safe;
  }
}

String fraudLevelLabel(FraudLevel l) {
  switch (l) {
    case FraudLevel.high:
      return 'Élevé';
    case FraudLevel.medium:
      return 'Moyen';
    case FraudLevel.low:
      return 'Faible';
    case FraudLevel.safe:
      return 'Normal';
  }
}

class FraudScore {
  final String userId;
  final String name;
  final String? email;
  final String phone;
  final String role;
  final int score;
  final FraudLevel level;
  final List<String> flags;

  const FraudScore({
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
    required this.score,
    required this.level,
    required this.flags,
    this.email,
  });

  factory FraudScore.fromJson(Map<String, dynamic> j) => FraudScore(
        userId: j['userId']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        email: j['email']?.toString(),
        phone: j['phone']?.toString() ?? '',
        role: j['role']?.toString() ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        level: parseFraudLevel(j['level']),
        flags: ((j['flags'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}

class FraudAlertUser {
  final String id;
  final String fullName;
  final String? email;
  final String phone;
  final String role;

  const FraudAlertUser({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    this.email,
  });

  factory FraudAlertUser.fromJson(Map<String, dynamic> j) => FraudAlertUser(
        id: j['id']?.toString() ?? '',
        fullName: j['fullName']?.toString() ?? '',
        email: j['email']?.toString(),
        phone: j['phone']?.toString() ?? '',
        role: j['role']?.toString() ?? '',
      );
}

class FraudAlert {
  final String id;
  final String userId;
  final FraudAlertUser? user;
  final int score;
  final FraudLevel level;
  final List<String> flags;
  final String? notes;
  final DateTime? resolvedAt;
  final String? resolvedById;
  final FraudAlertUser? resolvedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FraudAlert({
    required this.id,
    required this.userId,
    required this.score,
    required this.level,
    required this.flags,
    this.user,
    this.notes,
    this.resolvedAt,
    this.resolvedById,
    this.resolvedBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isResolved => resolvedAt != null;

  factory FraudAlert.fromJson(Map<String, dynamic> j) {
    final u = j['user'] as Map?;
    final r = j['resolvedBy'] as Map?;
    return FraudAlert(
      id: j['id']?.toString() ?? '',
      userId: j['userId']?.toString() ?? '',
      user: u != null ? FraudAlertUser.fromJson(u.cast<String, dynamic>()) : null,
      score: (j['score'] as num?)?.toInt() ?? 0,
      level: parseFraudLevel(j['level']),
      flags: ((j['flags'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList(),
      notes: j['notes']?.toString(),
      resolvedAt: DateTime.tryParse(j['resolvedAt']?.toString() ?? ''),
      resolvedById: j['resolvedById']?.toString(),
      resolvedBy: r != null
          ? FraudAlertUser(
              id: r['id']?.toString() ?? '',
              fullName: r['fullName']?.toString() ?? '',
              phone: '',
              role: '',
            )
          : null,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(j['updatedAt']?.toString() ?? ''),
    );
  }
}

class FraudRefreshResult {
  final int scanned;
  final int created;
  final int skipped;

  const FraudRefreshResult({
    required this.scanned,
    required this.created,
    required this.skipped,
  });

  factory FraudRefreshResult.fromJson(Map<String, dynamic> j) =>
      FraudRefreshResult(
        scanned: (j['scanned'] as num?)?.toInt() ?? 0,
        created: (j['created'] as num?)?.toInt() ?? 0,
        skipped: (j['skipped'] as num?)?.toInt() ?? 0,
      );
}

class FraudApi {
  final ApiClient client;

  FraudApi(this.client);

  Future<List<FraudScore>> fetchScores({int limit = 50, FraudLevel? level}) async {
    final params = <String, dynamic>{'limit': limit};
    if (level != null && level != FraudLevel.safe) {
      params['level'] = level.name;
    }
    final res = await client.dio.get(
      '/super-admin/fraud/scores',
      queryParameters: params,
    );
    final body = client.handle(res);
    final list = (body['scores'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => FraudScore.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<FraudAlert>> fetchAlerts({String status = 'open'}) async {
    final res = await client.dio.get(
      '/super-admin/fraud/alerts',
      queryParameters: {'status': status},
    );
    final body = client.handle(res);
    final list = (body['alerts'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => FraudAlert.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<FraudAlert> resolveAlert(String id, String notes) async {
    final res = await client.dio.request(
      '/super-admin/fraud/alerts/$id/resolve',
      data: {'notes': notes},
      options: Options(method: 'POST'),
    );
    final body = client.handle(res);
    final alert =
        (body['alert'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    return FraudAlert.fromJson(alert);
  }

  Future<FraudRefreshResult> refresh() async {
    final res = await client.dio.post('/super-admin/fraud/refresh', data: {});
    final body = client.handle(res);
    return FraudRefreshResult.fromJson(body);
  }
}
