// lib/services/api/observability_api.dart
//
// Journaux techniques et journal d'audit métier.
//
// Contrat : `ProColis-Api/specs/logs/observability.md`. Les quatre routes
// `/super-admin/observability/*` sont ouvertes au super administrateur et au
// support technique ; l'export, qui contient les stacks complètes, reste
// réservé au super administrateur et n'est pas exposé ici (voir plus bas).
//
// `/super-admin/audit-logs` est ouverte en plus au support transverse.

import '../../models/observability.dart';
import 'client.dart';

/// Erreur d'observabilité, avec un message affichable.
///
/// Les trois cas distingués correspondent aux réponses documentées par la
/// spec : ils appellent des messages d'écran très différents, et « Erreur
/// serveur » enverrait l'utilisateur sur une fausse piste dans les trois.
class ObservabilityApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const ObservabilityApiException(this.message, {this.statusCode, this.code});

  /// 403 : le rôle n'a pas accès aux journaux.
  bool get isForbidden => statusCode == 403;

  /// 503 : Loki ou Prometheus est injoignable. La panne est côté supervision,
  /// pas côté application — l'écran doit le dire explicitement.
  bool get isUnavailable =>
      statusCode == 503 || code == 'OBSERVABILITY_UNAVAILABLE';

  /// 429 : 30 consultations par minute, 2 exports par minute et par
  /// utilisateur.
  bool get isRateLimited => statusCode == 429;

  /// 400 : filtres refusés (période trop longue, niveau inconnu, recherche
  /// trop courte). Le message serveur est déjà explicite.
  bool get isInvalidQuery =>
      statusCode == 400 || code == 'INVALID_OBSERVABILITY_QUERY';

  @override
  String toString() => message;
}

class ObservabilityApi {
  final ApiClient client;

  ObservabilityApi(this.client);

  static const String _base = '/super-admin/observability';

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
    required String fallbackMessage,
  }) async {
    final res = await client.dio.get(path, queryParameters: query);
    final data = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || data['success'] == false) {
      throw ObservabilityApiException(
        data['message']?.toString() ?? fallbackMessage,
        statusCode: status,
        code: (data['error'] as Map?)?['code']?.toString(),
      );
    }
    return data;
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  // ---------------- Journaux techniques ----------------

  /// Compteurs par niveau et par source sur la période, dernière entrée et état
  /// des services. Période par défaut : une heure ; maximum 14 jours.
  Future<ObservabilitySummary> summary(LogFilters filters) async {
    final data = await _get(
      '$_base/summary',
      query: filters.toQuery(),
      fallbackMessage: 'Résumé d\'observabilité indisponible',
    );
    final raw = (data['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    return ObservabilitySummary.fromJson(raw);
  }

  /// Une page de journaux. [cursor] provient de la page précédente : la
  /// pagination est par curseur opaque, jamais par offset.
  Future<LogList> logs(LogFilters filters, {String? cursor}) async {
    final data = await _get(
      '$_base/logs',
      query: filters.toQuery(cursor: cursor),
      fallbackMessage: 'Journaux indisponibles',
    );
    final page = (data['page'] as Map?)?.cast<String, dynamic>();
    return LogList(
      logs: _list(data['logs']).map(LogEntry.fromJson).toList(),
      // Sans bloc `page`, on retient la limite demandée : l'écran s'en sert
      // pour savoir s'il a reçu une page pleine.
      page: page == null
          ? LogPage(limit: filters.limit)
          : LogPage.fromJson(page),
    );
  }

  /// État de `api`, `postgres`, `caddy`, `loki`, `alloy` et `prometheus`.
  Future<List<ServiceHealth>> services() async {
    final data = await _get(
      '$_base/services',
      fallbackMessage: 'État des services indisponible',
    );
    return _list(data['services']).map(ServiceHealth.fromJson).toList();
  }

  // L'export (`GET /super-admin/observability/export`) n'est volontairement pas
  // porté sur mobile : il renvoie un fichier CSV/JSONL de 10 000 entrées, dont
  // les stacks complètes, destiné à une analyse sur poste de travail. Le web le
  // couvre pour le super administrateur.

  // ---------------- Journal d'audit métier ----------------

  /// Journal d'audit. Hors super administrateur, les instantanés avant/après
  /// sont retirés par le serveur et chaque ligne porte `redacted: true`.
  Future<AuditLogPage> auditLogs({
    int page = 1,
    int limit = 25,
    String search = '',
    String actorRole = '',
    String action = '',
    String entityType = '',
    DateTime? from,
    DateTime? to,
  }) async {
    final data = await _get(
      '/super-admin/audit-logs',
      query: {
        'page': page,
        'limit': limit,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (actorRole.isNotEmpty) 'actorRole': actorRole,
        if (action.isNotEmpty) 'action': action,
        if (entityType.isNotEmpty) 'entityType': entityType,
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
      fallbackMessage: 'Journal d\'audit indisponible',
    );

    final pagination = (data['pagination'] as Map?)?.cast<String, dynamic>();
    return AuditLogPage(
      entries: _list(data['auditLogs'] ?? data['data'])
          .map(AuditLogEntry.fromJson)
          .toList(),
      page: pagination?['page'] is num
          ? (pagination!['page'] as num).toInt()
          : page,
      totalPages: pagination?['totalPages'] is num
          ? (pagination!['totalPages'] as num).toInt()
          : 1,
      total: pagination?['total'] is num
          ? (pagination!['total'] as num).toInt()
          : 0,
    );
  }
}

/// Une page du journal d'audit, avec de quoi savoir s'il reste des pages.
class AuditLogPage {
  final List<AuditLogEntry> entries;
  final int page;
  final int totalPages;
  final int total;

  const AuditLogPage({
    this.entries = const [],
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
  });

  bool get hasMore => page < totalPages;

  /// Vrai dès qu'une ligne est restreinte : suffit à afficher le bandeau
  /// d'explication en tête d'écran.
  bool get isRedacted => entries.any((entry) => entry.redacted);
}
