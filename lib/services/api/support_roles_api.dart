// lib/services/api/support_roles_api.dart
//
// Accès aux espaces support technique et support commercial.
//
// Distinct de `support_api.dart`, qui envoie les messages de support côté
// utilisateur final. Ici on consomme les endpoints réservés aux agents
// (voir specs/api/10-support-roles.md).

import '../../models/support.dart';
import 'client.dart';

/// Erreur métier remontée par l'API support, avec un message affichable.
class SupportApiException implements Exception {
  final String message;
  final int? statusCode;

  const SupportApiException(this.message, {this.statusCode});

  /// 403 : l'agent n'a pas le rôle attendu — message dédié, car « Erreur
  /// serveur » enverrait l'utilisateur sur une fausse piste.
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

class SupportRolesApi {
  final ApiClient client;

  SupportRolesApi(this.client);

  Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? query}) async {
    final res = await client.dio.get(path, queryParameters: query);
    final data = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || data['success'] == false) {
      throw SupportApiException(
        data['message']?.toString() ?? 'Requête support impossible',
        statusCode: status,
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> _send(
    String path,
    Map<String, dynamic> body, {
    bool patch = false,
  }) async {
    final res = patch
        ? await client.dio.patch(path, data: body)
        : await client.dio.post(path, data: body);
    final data = client.handle(res);
    final status = res.statusCode ?? 500;
    if (status >= 400 || data['success'] == false) {
      throw SupportApiException(
        data['message']?.toString() ?? 'Enregistrement impossible',
        statusCode: status,
      );
    }
    return data;
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  // ---------------- Support technique ----------------

  Future<SupportTechniqueSummary> techniqueStats() async {
    final data = await _get('/support-technique/stats');
    final stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    return SupportTechniqueSummary.fromJson(stats);
  }

  /// [status] et [priority] attendent les valeurs de l'API (`open`,
  /// `in_progress`, `critical`…) — passer par `TicketStatus.value`.
  Future<List<SupportTicket>> tickets({
    String? status,
    String? priority,
    bool assignedToMe = false,
    int limit = 50,
  }) async {
    final data = await _get('/support-technique/tickets', query: {
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (assignedToMe) 'assignee': 'me',
      'limit': limit,
    });
    return _list(data['tickets']).map(SupportTicket.fromJson).toList();
  }

  /// Détail d'un ticket (messages + colis lié). L'écran liste n'en expose
  /// qu'un résumé : la vue détaillée nécessite cet endpoint pour les champs
  /// manquants (`description`, `messages`, `createdBy`…).
  Future<SupportTicket> getTicket(String ticketId) async {
    final data = await _get('/support-technique/tickets/$ticketId');
    final raw = (data['ticket'] as Map?)?.cast<String, dynamic>() ?? {};
    return SupportTicket.fromJson(raw);
  }

  Future<SupportTicket> updateTicket(
    String ticketId, {
    TicketStatus? status,
    TicketPriority? priority,
    String? category,
  }) async {
    final data = await _send(
      '/support-technique/tickets/$ticketId',
      {
        if (status != null) 'status': status.value,
        if (priority != null) 'priority': priority.value,
        if (category != null) 'category': category,
      },
      patch: true,
    );
    return SupportTicket.fromJson(
      (data['ticket'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Future<List<PlatformIncident>> incidents({bool includeResolved = false}) async {
    final data = await _get('/support-technique/incidents', query: {
      if (includeResolved) 'includeResolved': 'true',
    });
    return _list(data['incidents']).map(PlatformIncident.fromJson).toList();
  }

  Future<PlatformIncident> createIncident({
    required String title,
    required String scope,
    required IncidentSeverity severity,
    int impactedUsers = 0,
    bool mitigated = false,
  }) async {
    final data = await _send('/support-technique/incidents', {
      'title': title,
      'scope': scope,
      'severity': severity.value,
      'impactedUsers': impactedUsers,
      'mitigated': mitigated,
    });
    return PlatformIncident.fromJson(
      (data['incident'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Future<PlatformIncident> resolveIncident(String incidentId) async {
    final data = await _send(
      '/support-technique/incidents/$incidentId',
      {'resolved': true},
      patch: true,
    );
    return PlatformIncident.fromJson(
      (data['incident'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  /// Mise à jour générique d'un incident. Seuls les champs fournis sont
  /// envoyés, pour éviter d'écraser les autres valeurs côté serveur.
  /// `resolveIncident` reste la voie pour marquer un incident résolu : on
  /// évite de dupliquer la responsabilité.
  Future<PlatformIncident> updateIncident(
    String incidentId, {
    String? title,
    String? scope,
    IncidentSeverity? severity,
    int? impactedUsers,
    bool? mitigated,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title,
      if (scope != null) 'scope': scope,
      if (severity != null) 'severity': severity.value,
      if (impactedUsers != null) 'impactedUsers': impactedUsers,
      if (mitigated != null) 'mitigated': mitigated,
    };
    final data = await _send(
      '/support-technique/incidents/$incidentId',
      payload,
      patch: true,
    );
    return PlatformIncident.fromJson(
      (data['incident'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  // ---------------- Support commercial ----------------

  Future<SupportCommercialSummary> commercialStats() async {
    final data = await _get('/support-commercial/stats');
    final stats = (data['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    return SupportCommercialSummary.fromJson(stats);
  }

  Future<List<CommercialLead>> leads({String? stage, int limit = 50}) async {
    final data = await _get('/support-commercial/leads', query: {
      if (stage != null) 'stage': stage,
      'limit': limit,
    });
    return _list(data['leads']).map(CommercialLead.fromJson).toList();
  }

  /// Nouveau prospect dans le portefeuille de l'agent commercial. Le
  /// serveur fixe le `ownerId` à partir du JWT : on n'a pas à le passer.
  Future<CommercialLead> createLead({
    required String name,
    String? city,
    LeadKind? kind,
    LeadStage? stage,
    double? monthlyValue,
    String? contactName,
    String? contactPhone,
    DateTime? nextFollowUpAt,
    String? notes,
  }) async {
    final data = await _send('/support-commercial/leads', {
      'name': name,
      if (city != null && city.isNotEmpty) 'city': city,
      if (kind != null) 'kind': kind.value,
      if (stage != null) 'stage': stage.value,
      if (monthlyValue != null) 'monthlyValue': monthlyValue,
      if (contactName != null && contactName.isNotEmpty)
        'contactName': contactName,
      if (contactPhone != null && contactPhone.isNotEmpty)
        'contactPhone': contactPhone,
      if (nextFollowUpAt != null)
        'nextFollowUpAt': nextFollowUpAt.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return CommercialLead.fromJson(
      (data['lead'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Future<CommercialLead> updateLead(
    String leadId, {
    LeadStage? stage,
    DateTime? nextFollowUpAt,
    double? monthlyValue,
  }) async {
    final data = await _send(
      '/support-commercial/leads/$leadId',
      {
        if (stage != null) 'stage': stage.value,
        if (nextFollowUpAt != null)
          'nextFollowUpAt': nextFollowUpAt.toIso8601String(),
        if (monthlyValue != null) 'monthlyValue': monthlyValue,
      },
      patch: true,
    );
    return CommercialLead.fromJson(
      (data['lead'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Future<NetworkCoverage> coverage() async {
    final data = await _get('/support-commercial/coverage');
    return NetworkCoverage.fromJson(
      (data['coverage'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}
