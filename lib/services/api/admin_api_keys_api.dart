// lib/services/api/admin_api_keys_api.dart
//
// Gestion des clés API partenaires e-commerce côté super-admin. Consomme
// les 5 endpoints `/super-admin/api-keys/*` exposés par le backend
// (`listApiKeys`, `createApiKey`, `rotateApiKey`, `updateApiKey`,
// `deactivateApiKey`).
//
// Le secret généré n'est renvoyé qu'une seule fois — au moment du create et
// du rotate — via le champ `secretOnce` (concaténé `keyId.secret`). L'UI
// doit l'afficher à l'utilisateur et le laisser copier ; il disparaît au
// prochain refresh.

import 'client.dart';

class ApiKey {
  final String id;
  final String keyId;
  final String partnerName;
  final List<String> scopes;
  final bool active;
  final String? webhookUrl;
  final bool hasWebhookSecret;
  final DateTime? lastUsedAt;
  final DateTime? rotatedAt;
  final DateTime? createdAt;

  const ApiKey({
    required this.id,
    required this.keyId,
    required this.partnerName,
    this.scopes = const [],
    this.active = true,
    this.webhookUrl,
    this.hasWebhookSecret = false,
    this.lastUsedAt,
    this.rotatedAt,
    this.createdAt,
  });

  factory ApiKey.fromJson(Map<String, dynamic> json) => ApiKey(
        id: json['id']?.toString() ?? '',
        keyId: json['keyId']?.toString() ?? '',
        partnerName: json['partnerName']?.toString() ?? '',
        scopes: (json['scopes'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        active: json['active'] != false,
        webhookUrl: json['webhookUrl']?.toString(),
        hasWebhookSecret: json['hasWebhookSecret'] == true,
        lastUsedAt: DateTime.tryParse(json['lastUsedAt']?.toString() ?? ''),
        rotatedAt: DateTime.tryParse(json['rotatedAt']?.toString() ?? ''),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

class ApiKeyWithSecret {
  final ApiKey key;

  /// Secret complet (`keyId.secret`) à afficher une seule fois.
  final String? secretOnce;

  /// Secret webhook éventuellement généré à la création.
  final String? webhookSecretOnce;

  const ApiKeyWithSecret(
      {required this.key, this.secretOnce, this.webhookSecretOnce});

  factory ApiKeyWithSecret.fromJson(Map<String, dynamic> json) {
    return ApiKeyWithSecret(
      key: ApiKey.fromJson(json),
      secretOnce: json['secretOnce']?.toString(),
      webhookSecretOnce: json['webhookSecretOnce']?.toString(),
    );
  }
}

class AdminApiKeysException implements Exception {
  final String message;
  final int? statusCode;

  const AdminApiKeysException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Détermine l'espace serveur consommé par l'écran : super-admin voit toutes
/// les clés, un business-shipper ne voit (et ne gère) que les siennes.
enum ApiKeysScope {
  superAdmin('/super-admin/api-keys'),
  businessShipper('/business-shipper/api-keys');

  final String basePath;
  const ApiKeysScope(this.basePath);
}

class AdminApiKeysApi {
  final ApiClient client;
  final ApiKeysScope scope;

  AdminApiKeysApi(this.client, {this.scope = ApiKeysScope.superAdmin});

  /// Scopes gérés aujourd'hui côté backend — alignés sur
  /// `src/utils/api-key-auth.js`. À élargir si le backend en ajoute.
  static const List<String> scopeChoices = [
    'parcel.read',
    'parcel.write',
    'webhook.receive',
  ];

  String get _base => scope.basePath;

  Future<List<ApiKey>> list() async {
    final res = await client.dio.get(_base);
    final body = client.handle(res);
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final raw = data['keys'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ApiKey.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ApiKeyWithSecret> create({
    required String partnerName,
    List<String> scopes = const [],
    String? webhookUrl,
    String? webhookSecret,
  }) async {
    final res = await client.dio.post(_base, data: {
      'partnerName': partnerName,
      'scopes': scopes,
      if (webhookUrl != null && webhookUrl.isNotEmpty) 'webhookUrl': webhookUrl,
      if (webhookSecret != null && webhookSecret.isNotEmpty)
        'webhookSecret': webhookSecret,
    });
    final body = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || body['success'] == false) {
      throw AdminApiKeysException(
        body['message']?.toString() ?? 'Création impossible',
        statusCode: status,
      );
    }
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final key = (data['key'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ApiKeyWithSecret.fromJson(key);
  }

  Future<ApiKeyWithSecret> rotate(String keyId) async {
    final res = await client.dio.post('$_base/$keyId/rotate');
    final body = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || body['success'] == false) {
      throw AdminApiKeysException(
        body['message']?.toString() ?? 'Rotation impossible',
        statusCode: status,
      );
    }
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final key = (data['key'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ApiKeyWithSecret.fromJson(key);
  }

  Future<ApiKey> update(
    String keyId, {
    List<String>? scopes,
    String? webhookUrl,
    bool? active,
  }) async {
    final res = await client.dio.patch('$_base/$keyId', data: {
      if (scopes != null) 'scopes': scopes,
      if (webhookUrl != null) 'webhookUrl': webhookUrl,
      if (active != null) 'active': active,
    });
    final body = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || body['success'] == false) {
      throw AdminApiKeysException(
        body['message']?.toString() ?? 'Mise à jour impossible',
        statusCode: status,
      );
    }
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final key = (data['key'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ApiKey.fromJson(key);
  }

  Future<ApiKey> deactivate(String keyId) async {
    final res =
        await client.dio.post('$_base/$keyId/deactivate');
    final body = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || body['success'] == false) {
      throw AdminApiKeysException(
        body['message']?.toString() ?? 'Désactivation impossible',
        statusCode: status,
      );
    }
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final key = (data['key'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ApiKey.fromJson(key);
  }
}
