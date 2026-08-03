// lib/services/api/system_api.dart
//
// Santé applicative et abonnements sortants (webhooks).
//
// Port du client web `ProColis-Web/src/lib/api/system.ts`.
//
// À ne pas confondre avec `/super-admin/observability/services`, qui interroge
// Prometheus sur l'ensemble de l'infrastructure : ici, c'est une sonde
// applicative simple (l'API répond-elle, la base est-elle joignable).

import 'client.dart';

/// Sonde applicative. `degraded` est un état renvoyé avec un **503** : l'échec
/// de la requête est lui-même l'information, pas une erreur à masquer.
class SystemHealth {
  final String status;
  final String database;

  /// Temps depuis le dernier démarrage du process API, en secondes.
  final double uptime;
  final DateTime? timestamp;

  const SystemHealth({
    this.status = 'degraded',
    this.database = 'unknown',
    this.uptime = 0,
    this.timestamp,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) => SystemHealth(
        status: json['status']?.toString() ?? 'degraded',
        database: json['database']?.toString() ?? 'unknown',
        uptime: json['uptime'] is num
            ? (json['uptime'] as num).toDouble()
            : double.tryParse(json['uptime']?.toString() ?? '') ?? 0,
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
      );

  bool get isHealthy => status == 'healthy';

  /// Durée lisible : « 3 j 4 h », « 5 h 12 min », « 42 min ».
  String get uptimeLabel {
    if (!uptime.isFinite || uptime <= 0) return '—';
    final total = uptime.round();
    final days = total ~/ 86400;
    final hours = (total % 86400) ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    if (days > 0) return '$days j $hours h';
    if (hours > 0) return '$hours h $minutes min';
    return '$minutes min';
  }
}

/// Abonnement sortant : l'API poste les événements choisis vers [url].
class Webhook {
  final String id;
  final String url;
  final List<String> events;

  /// Le secret de signature n'est jamais relu : seule sa présence est exposée.
  final bool hasSecret;
  final bool isActive;
  final DateTime? createdAt;

  const Webhook({
    required this.id,
    required this.url,
    this.events = const [],
    this.hasSecret = false,
    this.isActive = true,
    this.createdAt,
  });

  factory Webhook.fromJson(Map<String, dynamic> json) => Webhook(
        id: json['id']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        events: json['events'] is List
            ? (json['events'] as List).map((e) => e.toString()).toList()
            : const [],
        hasSecret: json['hasSecret'] == true,
        isActive: json['isActive'] != false,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

class SystemApiException implements Exception {
  final String message;
  final int? statusCode;

  const SystemApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class SystemApi {
  final ApiClient client;

  SystemApi(this.client);

  /// Événements que l'API sait pousser, alignés sur `EVENT_CHOICES` du web.
  static const List<String> eventChoices = [
    'parcel.created',
    'parcel.status_changed',
    'parcel.delivered',
    'bid.received',
    'bid.accepted',
    'payment.completed',
    'withdrawal.requested',
  ];

  /// Sonde applicative. Un 503 n'est pas propagé en exception : il porte
  /// l'état dégradé, que l'écran doit afficher tel quel.
  Future<SystemHealth> health() async {
    final res = await client.dio.get('/super-admin/system/health');
    final data = client.handle(res);
    return SystemHealth.fromJson(data);
  }

  Future<List<Webhook>> listWebhooks() async {
    final res = await client.dio.get('/webhooks');
    final data = client.handle(res);
    final raw = data['webhooks'] ?? data['data'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Webhook.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Webhook> createWebhook({
    required String url,
    required List<String> events,
    String? secret,
  }) async {
    final res = await client.dio.post('/webhooks', data: {
      'url': url,
      'events': events,
      if (secret != null && secret.isNotEmpty) 'secret': secret,
    });
    final data = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || data['success'] == false) {
      throw SystemApiException(
        data['message']?.toString() ?? 'Création du webhook impossible',
        statusCode: status,
      );
    }
    final raw = (data['webhook'] as Map?) ?? const {};
    return Webhook.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> deleteWebhook(String webhookId) async {
    final res = await client.dio.delete('/webhooks/$webhookId');
    final data = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || data['success'] == false) {
      throw SystemApiException(
        data['message']?.toString() ?? 'Suppression impossible',
        statusCode: status,
      );
    }
  }
}
