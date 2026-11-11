// lib/services/api/pilot_metrics_api.dart
//
// Snapshot des métriques pilote (lecture seule) consommé par l'écran
// super-admin. Les 5 sections (`referrals`, `insurance`, `apiKeys`,
// `whatsapp`, `aiAssistant`, `anomalies`, `sla`) peuvent être `null` quand
// le backend n'a pas encore de source alimentée — l'UI doit le gérer.

import 'client.dart';

class PilotReferralMetrics {
  final int total;
  final int pending;
  final int triggered;
  final double? conversionPercent;

  const PilotReferralMetrics(
      {this.total = 0,
      this.pending = 0,
      this.triggered = 0,
      this.conversionPercent});

  factory PilotReferralMetrics.fromJson(Map<String, dynamic> json) =>
      PilotReferralMetrics(
        total: _int(json['total']),
        pending: _int(json['pending']),
        triggered: _int(json['triggered']),
        conversionPercent: _double(json['conversionPercent']),
      );
}

class PilotInsuranceMetrics {
  final int active;
  final int claimed;
  final int cancelled;
  final double? claimRatePercent;

  const PilotInsuranceMetrics(
      {this.active = 0,
      this.claimed = 0,
      this.cancelled = 0,
      this.claimRatePercent});

  factory PilotInsuranceMetrics.fromJson(Map<String, dynamic> json) =>
      PilotInsuranceMetrics(
        active: _int(json['active']),
        claimed: _int(json['claimed']),
        cancelled: _int(json['cancelled']),
        claimRatePercent: _double(json['claimRatePercent']),
      );
}

class PilotApiKeyMetrics {
  final int active;
  final int total;

  const PilotApiKeyMetrics({this.active = 0, this.total = 0});

  factory PilotApiKeyMetrics.fromJson(Map<String, dynamic> json) =>
      PilotApiKeyMetrics(
        active: _int(json['active']),
        total: _int(json['total']),
      );
}

class PilotWhatsAppMetrics {
  final int sent;
  final int delivered;
  final int read;
  final double? deliveryRatePercent;
  final double? readRatePercent;

  const PilotWhatsAppMetrics(
      {this.sent = 0,
      this.delivered = 0,
      this.read = 0,
      this.deliveryRatePercent,
      this.readRatePercent});

  factory PilotWhatsAppMetrics.fromJson(Map<String, dynamic> json) =>
      PilotWhatsAppMetrics(
        sent: _int(json['sent']),
        delivered: _int(json['delivered']),
        read: _int(json['read']),
        deliveryRatePercent: _double(json['deliveryRatePercent']),
        readRatePercent: _double(json['readRatePercent']),
      );
}

class PilotAiAssistantMetrics {
  final int requested;
  final int completed;
  final double? successRatePercent;

  const PilotAiAssistantMetrics(
      {this.requested = 0, this.completed = 0, this.successRatePercent});

  factory PilotAiAssistantMetrics.fromJson(Map<String, dynamic> json) =>
      PilotAiAssistantMetrics(
        requested: _int(json['requested']),
        completed: _int(json['completed']),
        successRatePercent: _double(json['successRatePercent']),
      );
}

class PilotAnomalyMetrics {
  final int gpsSilence;
  final int prolongedStop;
  final int routeDeviation;
  final int total;

  const PilotAnomalyMetrics(
      {this.gpsSilence = 0,
      this.prolongedStop = 0,
      this.routeDeviation = 0,
      this.total = 0});

  factory PilotAnomalyMetrics.fromJson(Map<String, dynamic> json) =>
      PilotAnomalyMetrics(
        gpsSilence: _int(json['gpsSilence']),
        prolongedStop: _int(json['prolongedStop']),
        routeDeviation: _int(json['routeDeviation']),
        total: _int(json['total']),
      );
}

class PilotSlaMetrics {
  final int deliveredOnTime;
  final int delivered;
  final double? onTimePercent;

  const PilotSlaMetrics(
      {this.deliveredOnTime = 0, this.delivered = 0, this.onTimePercent});

  factory PilotSlaMetrics.fromJson(Map<String, dynamic> json) => PilotSlaMetrics(
        deliveredOnTime: _int(json['deliveredOnTime']),
        delivered: _int(json['delivered']),
        onTimePercent: _double(json['onTimePercent']),
      );
}

class PilotMetrics {
  final PilotReferralMetrics referrals;
  final PilotInsuranceMetrics insurance;
  final PilotApiKeyMetrics apiKeys;

  /// Les 4 derniers blocs sont optionnels : le backend renvoie `null` tant
  /// qu'ils ne sont pas alimentés (compteurs WhatsApp via callback Meta,
  /// counter anomalies, etc.).
  final PilotWhatsAppMetrics? whatsapp;
  final PilotAiAssistantMetrics? aiAssistant;
  final PilotAnomalyMetrics? anomalies;
  final PilotSlaMetrics? sla;
  final DateTime? computedAt;

  const PilotMetrics({
    this.referrals = const PilotReferralMetrics(),
    this.insurance = const PilotInsuranceMetrics(),
    this.apiKeys = const PilotApiKeyMetrics(),
    this.whatsapp,
    this.aiAssistant,
    this.anomalies,
    this.sla,
    this.computedAt,
  });

  factory PilotMetrics.fromJson(Map<String, dynamic> json) => PilotMetrics(
        referrals: PilotReferralMetrics.fromJson(
            (json['referrals'] as Map?)?.cast<String, dynamic>() ?? const {}),
        insurance: PilotInsuranceMetrics.fromJson(
            (json['insurance'] as Map?)?.cast<String, dynamic>() ?? const {}),
        apiKeys: PilotApiKeyMetrics.fromJson(
            (json['apiKeys'] as Map?)?.cast<String, dynamic>() ?? const {}),
        whatsapp: json['whatsapp'] is Map
            ? PilotWhatsAppMetrics.fromJson(
                (json['whatsapp'] as Map).cast<String, dynamic>())
            : null,
        aiAssistant: json['aiAssistant'] is Map
            ? PilotAiAssistantMetrics.fromJson(
                (json['aiAssistant'] as Map).cast<String, dynamic>())
            : null,
        anomalies: json['anomalies'] is Map
            ? PilotAnomalyMetrics.fromJson(
                (json['anomalies'] as Map).cast<String, dynamic>())
            : null,
        sla: json['sla'] is Map
            ? PilotSlaMetrics.fromJson(
                (json['sla'] as Map).cast<String, dynamic>())
            : null,
        computedAt: DateTime.tryParse(json['computedAt']?.toString() ?? ''),
      );
}

class PilotMetricsApi {
  final ApiClient client;

  PilotMetricsApi(this.client);

  Future<PilotMetrics> fetch() async {
    final res = await client.dio.get('/super-admin/pilot-metrics');
    final body = client.handle(res);
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    final metrics =
        (data['metrics'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PilotMetrics.fromJson(metrics);
  }
}

int _int(dynamic v) => v is num ? v.toInt() : 0;
double? _double(dynamic v) => v is num ? v.toDouble() : null;
