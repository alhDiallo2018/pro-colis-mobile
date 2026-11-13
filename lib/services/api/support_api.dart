import 'client.dart';

class SupportSlaOverview {
  final int technicalAtRisk;
  final int technicalBreached;
  final int commercialDelayed;
  final int chatExceeded;
  final double? chatAvgFirstResponseMinutes;
  final double? technicalAvgResolutionHours;

  const SupportSlaOverview({
    this.technicalAtRisk = 0,
    this.technicalBreached = 0,
    this.commercialDelayed = 0,
    this.chatExceeded = 0,
    this.chatAvgFirstResponseMinutes,
    this.technicalAvgResolutionHours,
  });

  factory SupportSlaOverview.fromJson(Map<String, dynamic> json) =>
      SupportSlaOverview(
        technicalAtRisk: json['technicalAtRisk'] is num
            ? (json['technicalAtRisk'] as num).toInt()
            : 0,
        technicalBreached: json['technicalBreached'] is num
            ? (json['technicalBreached'] as num).toInt()
            : 0,
        commercialDelayed: json['commercialDelayed'] is num
            ? (json['commercialDelayed'] as num).toInt()
            : 0,
        chatExceeded: json['chatExceeded'] is num
            ? (json['chatExceeded'] as num).toInt()
            : 0,
        chatAvgFirstResponseMinutes:
            json['chatAvgFirstResponseMinutes'] is num
                ? (json['chatAvgFirstResponseMinutes'] as num).toDouble()
                : null,
        technicalAvgResolutionHours:
            json['technicalAvgResolutionHours'] is num
                ? (json['technicalAvgResolutionHours'] as num).toDouble()
                : null,
      );
}

class SupportApi {
  final ApiClient client;
  SupportApi(this.client);

  /// Vue consolidée des SLA cross-tier (technique, commercial, chat).
  /// Renvoie null si l'endpoint n'existe pas encore (404) — le dashboard
  /// masquera alors la section SLA.
  Future<SupportSlaOverview?> getSlaOverview() async {
    try {
      final res = await client.dio.get('/support-admin/sla-overview');
      final body = client.handle(res);
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ??
          (body['overview'] as Map?)?.cast<String, dynamic>() ??
          body.cast<String, dynamic>();
      return SupportSlaOverview.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Envoie un message au support (formulaire contact / réclamation).
  /// Aligné sur la webapp : POST /support/messages { subject, message, name?, email? }.
  Future<Map<String, dynamic>> sendSupportMessage({
    required String subject,
    required String message,
    String? name,
    String? email,
  }) async {
    try {
      final res = await client.dio.post('/support/messages', data: {
        'subject': subject,
        'message': message,
        if (name != null && name.isNotEmpty) 'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      final data = client.handle(res);
      if (res.statusCode != null && res.statusCode! >= 400) {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de l\'envoi du message',
        };
      }
      return {'success': data['success'] ?? true, ...data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
