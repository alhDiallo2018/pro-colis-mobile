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
