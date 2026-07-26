// lib/models/support.dart
//
// Modèles des espaces support technique et support commercial.
//
// Alignés sur les réponses de `/support-technique/*` et `/support-commercial/*`
// (voir specs/api/10-support-roles.md). Comme `UserRole`, les enums portent
// leur libellé et leur ton d'affichage : c'est la convention du projet, et cela
// évite une table de correspondance dupliquée dans chaque écran.

import 'package:flutter/material.dart';

import '../widgets/pc_components.dart';

int _toInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double _toDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

List<Map<String, dynamic>> _mapList(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

// ============================================================
// Enums
// ============================================================

enum TicketChannel {
  inApp('in_app', 'Chat in-app', Icons.chat_bubble_rounded),
  phone('phone', 'Téléphone', Icons.call_rounded),
  email('email', 'Email', Icons.mail_rounded);

  final String value;
  final String label;
  final IconData icon;
  const TicketChannel(this.value, this.label, this.icon);

  static TicketChannel fromString(String? raw) => TicketChannel.values.firstWhere(
        (e) => e.value == raw,
        orElse: () => TicketChannel.inApp,
      );
}

enum TicketPriority {
  critical('critical', 'Critique', PcTone.red, 60),
  high('high', 'Haute', PcTone.amber, 240),
  normal('normal', 'Normale', PcTone.primary, 720),
  low('low', 'Basse', PcTone.neutral, 2880);

  final String value;
  final String label;
  final PcTone tone;

  /// Budget de première réponse, en minutes. Doit rester aligné sur
  /// `SLA_MINUTES` dans l'API (support.controller.js).
  final int slaMinutes;

  const TicketPriority(this.value, this.label, this.tone, this.slaMinutes);

  static TicketPriority fromString(String? raw) => TicketPriority.values.firstWhere(
        (e) => e.value == raw,
        orElse: () => TicketPriority.normal,
      );
}

enum TicketStatus {
  open('open', 'Ouvert', PcTone.amber),
  pending('pending', 'En attente client', PcTone.neutral),
  inProgress('in_progress', 'En cours', PcTone.primary),
  resolved('resolved', 'Résolu', PcTone.green);

  final String value;
  final String label;
  final PcTone tone;
  const TicketStatus(this.value, this.label, this.tone);

  static TicketStatus fromString(String? raw) => TicketStatus.values.firstWhere(
        (e) => e.value == raw,
        orElse: () => TicketStatus.open,
      );
}

enum IncidentSeverity {
  sev1('sev1', 'SEV-1', PcTone.red),
  sev2('sev2', 'SEV-2', PcTone.amber),
  sev3('sev3', 'SEV-3', PcTone.neutral);

  final String value;
  final String label;
  final PcTone tone;
  const IncidentSeverity(this.value, this.label, this.tone);

  static IncidentSeverity fromString(String? raw) => IncidentSeverity.values.firstWhere(
        (e) => e.value == raw,
        orElse: () => IncidentSeverity.sev3,
      );
}

enum LeadKind {
  garage('garage', 'Zone / garage', Icons.garage_rounded),
  businessClient('business_client', 'Client pro', Icons.storefront_rounded),
  driverFleet('driver_fleet', 'Flotte chauffeurs', Icons.local_shipping_rounded);

  final String value;
  final String label;
  final IconData icon;
  const LeadKind(this.value, this.label, this.icon);

  static LeadKind fromString(String? raw) => LeadKind.values.firstWhere(
        (e) => e.value == raw,
        orElse: () => LeadKind.businessClient,
      );
}

enum LeadStage {
  contacted('contacted', 'Contacté', 1, PcTone.neutral),
  qualified('qualified', 'Qualifié', 2, PcTone.primary),
  negotiation('negotiation', 'Négociation', 3, PcTone.amber),
  signed('signed', 'Signé', 4, PcTone.green);

  final String value;
  final String label;
  final int step;
  final PcTone tone;
  const LeadStage(this.value, this.label, this.step, this.tone);

  static const int totalSteps = 4;

  static LeadStage fromString(String? raw) => LeadStage.values.firstWhere(
        (e) => e.value == raw,
        orElse: () => LeadStage.contacted,
      );
}

// ============================================================
// Séries et répartitions
// ============================================================

class RoleSeries {
  final String title;
  final String unit;
  final List<int> values;
  final List<String> labels;

  const RoleSeries({
    required this.title,
    required this.unit,
    required this.values,
    required this.labels,
  });

  factory RoleSeries.fromJson(
    Map<String, dynamic>? json, {
    required String title,
    List<String> fallbackLabels = const [],
  }) {
    final rawValues = json?['values'];
    final rawLabels = json?['labels'];
    return RoleSeries(
      title: title,
      unit: json?['unit']?.toString() ?? '',
      values: rawValues is List ? rawValues.map((v) => _toInt(v)).toList() : const [],
      labels: rawLabels is List
          ? rawLabels.map((v) => v.toString()).toList()
          : fallbackLabels,
    );
  }

  bool get isEmpty => values.isEmpty;
  int get total => values.fold(0, (a, b) => a + b);
}

class RoleBreakdown {
  final String label;
  final int count;

  const RoleBreakdown({required this.label, required this.count});

  factory RoleBreakdown.fromJson(Map<String, dynamic> json) => RoleBreakdown(
        label: json['label']?.toString() ?? '—',
        count: _toInt(json['count']),
      );
}

// ============================================================
// Ticket
// ============================================================

class SupportTicket {
  final String id;
  final String reference;
  final String subject;
  final String? body;
  final TicketChannel channel;
  final TicketPriority priority;
  final TicketStatus status;
  final String? category;

  /// Ancienneté, calculée par le serveur.
  final Duration age;

  /// Temps restant avant rupture de SLA ; négatif = dépassé. `null` quand
  /// aucune échéance n'est définie côté serveur.
  final Duration? slaRemaining;

  final String? requesterName;
  final String? requesterRole;
  final String? assigneeName;
  final DateTime? resolvedAt;

  const SupportTicket({
    required this.id,
    required this.reference,
    required this.subject,
    this.body,
    required this.channel,
    required this.priority,
    required this.status,
    this.category,
    required this.age,
    this.slaRemaining,
    this.requesterName,
    this.requesterRole,
    this.assigneeName,
    this.resolvedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final slaMinutes = _toIntOrNull(json['slaRemainingMinutes']);
    return SupportTicket(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '—',
      subject: json['subject']?.toString() ?? '',
      body: json['body']?.toString(),
      channel: TicketChannel.fromString(json['channel']?.toString()),
      priority: TicketPriority.fromString(json['priority']?.toString()),
      status: TicketStatus.fromString(json['status']?.toString()),
      category: json['category']?.toString(),
      age: Duration(minutes: _toInt(json['ageMinutes'])),
      slaRemaining: slaMinutes == null ? null : Duration(minutes: slaMinutes),
      requesterName: json['requesterName']?.toString(),
      requesterRole: json['requesterRole']?.toString(),
      assigneeName: json['assigneeName']?.toString(),
      resolvedAt: _toDate(json['resolvedAt']),
    );
  }

  bool get isSlaBreached => slaRemaining != null && slaRemaining!.isNegative;
  bool get isActive => status != TicketStatus.resolved;
}

// ============================================================
// Incident
// ============================================================

class PlatformIncident {
  final String id;
  final String title;
  final String scope;
  final IncidentSeverity severity;
  final bool mitigated;
  final int impactedUsers;
  final Duration since;
  final DateTime? resolvedAt;

  const PlatformIncident({
    required this.id,
    required this.title,
    required this.scope,
    required this.severity,
    required this.mitigated,
    required this.impactedUsers,
    required this.since,
    this.resolvedAt,
  });

  factory PlatformIncident.fromJson(Map<String, dynamic> json) => PlatformIncident(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        scope: json['scope']?.toString() ?? '',
        severity: IncidentSeverity.fromString(json['severity']?.toString()),
        mitigated: json['mitigated'] == true,
        impactedUsers: _toInt(json['impactedUsers']),
        since: Duration(minutes: _toInt(json['sinceMinutes'])),
        resolvedAt: _toDate(json['resolvedAt']),
      );
}

// ============================================================
// Prospect commercial
// ============================================================

class CommercialLead {
  final String id;
  final String name;
  final String? city;
  final LeadKind kind;
  final LeadStage stage;
  final double monthlyValue;
  final String? contactName;
  final String? contactPhone;

  /// Jours avant la prochaine relance ; négatif = en retard. `null` quand
  /// aucune relance n'est planifiée.
  final int? daysToFollowUp;

  const CommercialLead({
    required this.id,
    required this.name,
    this.city,
    required this.kind,
    required this.stage,
    required this.monthlyValue,
    this.contactName,
    this.contactPhone,
    this.daysToFollowUp,
  });

  factory CommercialLead.fromJson(Map<String, dynamic> json) => CommercialLead(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        city: json['city']?.toString(),
        kind: LeadKind.fromString(json['kind']?.toString()),
        stage: LeadStage.fromString(json['stage']?.toString()),
        monthlyValue: _toDouble(json['monthlyValue']),
        contactName: json['contactName']?.toString(),
        contactPhone: json['contactPhone']?.toString(),
        daysToFollowUp: _toIntOrNull(json['daysToFollowUp']),
      );

  bool get isOverdue => (daysToFollowUp ?? 0) < 0;
}

// ============================================================
// Couverture réseau
// ============================================================

class CoverageGap {
  final String id;
  final String name;
  final String? city;
  final String? region;
  final int activeDrivers;
  final String reason;

  const CoverageGap({
    required this.id,
    required this.name,
    this.city,
    this.region,
    required this.activeDrivers,
    required this.reason,
  });

  factory CoverageGap.fromJson(Map<String, dynamic> json) => CoverageGap(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        city: json['city']?.toString(),
        region: json['region']?.toString(),
        activeDrivers: _toInt(json['activeDrivers']),
        reason: json['reason']?.toString() ?? '',
      );
}

class NetworkCoverage {
  final int totalZones;
  final int thinThreshold;
  final List<CoverageGap> gaps;

  const NetworkCoverage({
    required this.totalZones,
    required this.thinThreshold,
    required this.gaps,
  });

  factory NetworkCoverage.fromJson(Map<String, dynamic> json) => NetworkCoverage(
        totalZones: _toInt(json['totalZones']),
        thinThreshold: _toInt(json['thinThreshold'], 2),
        gaps: _mapList(json['gaps']).map(CoverageGap.fromJson).toList(),
      );
}

// ============================================================
// Résumés
// ============================================================

class SupportTechniqueSummary {
  final int openTickets;
  final int resolvedToday;
  final int resolvedThisMonth;
  final int firstResponseMinutes;
  final double resolutionHours;

  /// `null` quand aucun avis n'a encore été recueilli : afficher 0 % se lirait
  /// comme une mauvaise note plutôt que comme une absence de donnée.
  final int? satisfactionPercent;

  final int slaAtRisk;
  final int openIncidents;
  final RoleSeries weeklySeries;
  final List<RoleBreakdown> categories;

  const SupportTechniqueSummary({
    required this.openTickets,
    required this.resolvedToday,
    required this.resolvedThisMonth,
    required this.firstResponseMinutes,
    required this.resolutionHours,
    required this.satisfactionPercent,
    required this.slaAtRisk,
    required this.openIncidents,
    required this.weeklySeries,
    required this.categories,
  });

  factory SupportTechniqueSummary.fromJson(Map<String, dynamic> json) =>
      SupportTechniqueSummary(
        openTickets: _toInt(json['openTickets']),
        resolvedToday: _toInt(json['resolvedToday']),
        resolvedThisMonth: _toInt(json['resolvedThisMonth']),
        firstResponseMinutes: _toInt(json['firstResponseMinutes']),
        resolutionHours: _toDouble(json['resolutionHours']),
        satisfactionPercent: _toIntOrNull(json['satisfactionPercent']),
        slaAtRisk: _toInt(json['slaAtRisk']),
        openIncidents: _toInt(json['openIncidents']),
        weeklySeries: RoleSeries.fromJson(
          (json['weeklySeries'] as Map?)?.cast<String, dynamic>(),
          title: 'Tickets reçus',
        ),
        categories:
            _mapList(json['categories']).map(RoleBreakdown.fromJson).toList(),
      );

  String get firstResponseLabel => firstResponseMinutes <= 0
      ? '—'
      : firstResponseMinutes < 60
          ? '$firstResponseMinutes min'
          : '${(firstResponseMinutes / 60).toStringAsFixed(1)} h';

  String get resolutionLabel =>
      resolutionHours <= 0 ? '—' : '${resolutionHours.toStringAsFixed(1)} h';

  String get satisfactionLabel =>
      satisfactionPercent == null ? '—' : '$satisfactionPercent%';
}

class SupportCommercialSummary {
  final int activeLeads;
  final int signedThisMonth;
  final int managedAccounts;
  final double monthlyRevenue;
  final double monthlyObjective;

  /// `null` quand le portefeuille est vide.
  final int? conversionPercent;

  final int overdueFollowUps;
  final int newZonesSigned;
  final String? territory;
  final RoleSeries monthlySeries;
  final List<RoleBreakdown> sources;

  const SupportCommercialSummary({
    required this.activeLeads,
    required this.signedThisMonth,
    required this.managedAccounts,
    required this.monthlyRevenue,
    required this.monthlyObjective,
    required this.conversionPercent,
    required this.overdueFollowUps,
    required this.newZonesSigned,
    required this.territory,
    required this.monthlySeries,
    required this.sources,
  });

  factory SupportCommercialSummary.fromJson(Map<String, dynamic> json) =>
      SupportCommercialSummary(
        activeLeads: _toInt(json['activeLeads']),
        signedThisMonth: _toInt(json['signedThisMonth']),
        managedAccounts: _toInt(json['managedAccounts']),
        monthlyRevenue: _toDouble(json['monthlyRevenue']),
        monthlyObjective: _toDouble(json['monthlyObjective']),
        conversionPercent: _toIntOrNull(json['conversionPercent']),
        overdueFollowUps: _toInt(json['overdueFollowUps']),
        newZonesSigned: _toInt(json['newZonesSigned']),
        territory: json['territory']?.toString(),
        monthlySeries: RoleSeries.fromJson(
          (json['monthlySeries'] as Map?)?.cast<String, dynamic>(),
          title: 'Signatures',
          fallbackLabels: const [
            'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
          ],
        ),
        sources: _mapList(json['sources']).map(RoleBreakdown.fromJson).toList(),
      );

  /// Aucun objectif défini pour le mois : la jauge n'a pas de sens.
  bool get hasObjective => monthlyObjective > 0;

  int get objectivePercent => hasObjective
      ? ((monthlyRevenue / monthlyObjective) * 100).round()
      : 0;

  double get objectiveProgress =>
      hasObjective ? (objectivePercent / 100).clamp(0.0, 1.0).toDouble() : 0;

  String get conversionLabel =>
      conversionPercent == null ? '—' : '$conversionPercent%';
}
