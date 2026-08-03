// lib/models/observability.dart
//
// Journaux techniques et journal d'audit métier.
//
// Contrat : `ProColis-Api/specs/logs/observability.md`. L'API interroge Loki et
// Prometheus ; le mobile ne les voit jamais directement et ne connaît que les
// quatre routes `/super-admin/observability/*` et `/super-admin/audit-logs`.
//
// Comme `UserRole` et les enums de `support.dart`, les enums portent ici leur
// libellé et leur ton d'affichage : c'est la convention du projet, et cela
// évite une table de correspondance recopiée dans chaque écran.

import '../widgets/pc_components.dart';

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? _toStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

Map<String, dynamic>? _toMap(dynamic v) {
  if (v is! Map) return null;
  return v.cast<String, dynamic>();
}

// ============================================================
// Journaux techniques
// ============================================================

/// Niveaux normalisés par l'API (`OBSERVABILITY_LEVELS`). Les libellés suivent
/// ceux du web (`labels.ts`) pour qu'un même incident se lise pareil des deux
/// côtés.
enum LogLevel {
  debug('debug', 'Debug', PcTone.neutral),
  info('info', 'Info', PcTone.primary),
  notice('notice', 'Notice', PcTone.primary),
  warning('warning', 'Alerte', PcTone.amber),
  error('error', 'Erreur', PcTone.red),
  critical('critical', 'Critique', PcTone.red),
  alert('alert', 'Urgence', PcTone.red),
  emergency('emergency', 'Panne', PcTone.red);

  final String value;
  final String label;
  final PcTone tone;
  const LogLevel(this.value, this.label, this.tone);

  /// Niveaux qui méritent une action : ce sont eux que compte la carte
  /// « Erreurs », en miroir de `CRITICAL_LEVELS` côté web.
  bool get isActionable =>
      this == LogLevel.error ||
      this == LogLevel.critical ||
      this == LogLevel.alert ||
      this == LogLevel.emergency;

  /// Un niveau inconnu retombe sur `info` plutôt que d'être écarté : mieux vaut
  /// afficher la ligne avec un ton neutre que la faire disparaître du journal.
  static LogLevel fromString(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    return LogLevel.values.firstWhere(
      (e) => e.value == normalized,
      orElse: () => LogLevel.info,
    );
  }
}

/// Sources acceptées par le filtre `source` (`OBSERVABILITY_SOURCES`).
enum LogSource {
  api('api', 'API'),
  postgres('postgres', 'PostgreSQL'),
  caddy('caddy', 'Caddy'),
  frontend('frontend', 'Web'),
  docker('docker', 'Infrastructure');

  final String value;
  final String label;
  const LogSource(this.value, this.label);

  static LogSource? fromString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.trim().toLowerCase();
    for (final source in LogSource.values) {
      if (source.value == normalized) return source;
    }
    return null;
  }

  /// Libellé d'une source arbitraire : Loki peut remonter un service que
  /// l'enum ne connaît pas encore.
  static String labelOf(String? raw) => fromString(raw)?.label ?? (raw ?? '—');
}

/// Erreur attachée à une entrée. Pour le support technique, l'API ne renvoie
/// que [name] et [code] — [message] et [stack] sont retirés côté serveur.
class LogEntryError {
  final String? name;
  final String? code;
  final String? message;
  final String? stack;

  const LogEntryError({this.name, this.code, this.message, this.stack});

  factory LogEntryError.fromJson(Map<String, dynamic> json) => LogEntryError(
        name: _toStringOrNull(json['name']),
        code: _toStringOrNull(json['code']),
        message: _toStringOrNull(json['message']),
        stack: _toStringOrNull(json['stack']),
      );

  bool get isEmpty =>
      name == null && code == null && message == null && stack == null;

  /// Étiquette courte pour la ligne repliée : `TypeError · INTERNAL_ERROR`.
  String get shortLabel =>
      [name, code].where((s) => s != null && s.isNotEmpty).join(' · ');
}

/// Une entrée de journal normalisée par l'API.
class LogEntry {
  final String id;
  final DateTime? timestamp;
  final LogLevel severity;
  final String source;
  final String? environment;
  final String message;
  final String? requestId;
  final String? route;
  final String? method;
  final int? statusCode;
  final int? durationMs;
  final String? userId;
  final LogEntryError? error;
  final Map<String, dynamic>? context;

  /// Vrai quand le serveur a retiré message d'erreur, stack, contexte et
  /// `userId` — c'est le cas pour le support technique.
  final bool redacted;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.source,
    required this.message,
    this.environment,
    this.requestId,
    this.route,
    this.method,
    this.statusCode,
    this.durationMs,
    this.userId,
    this.error,
    this.context,
    this.redacted = false,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    final error = _toMap(json['error']);
    return LogEntry(
      id: json['id']?.toString() ?? '',
      timestamp: _toDate(json['timestamp']),
      severity: LogLevel.fromString(json['severity']?.toString()),
      source: json['source']?.toString() ?? 'api',
      environment: _toStringOrNull(json['environment']),
      message: json['message']?.toString() ?? '',
      requestId: _toStringOrNull(json['requestId']),
      route: _toStringOrNull(json['route']),
      method: _toStringOrNull(json['method']),
      statusCode: _toIntOrNull(json['statusCode']),
      durationMs: _toIntOrNull(json['durationMs']),
      userId: _toStringOrNull(json['userId']),
      error: error == null ? null : LogEntryError.fromJson(error),
      context: _toMap(json['context']),
      redacted: json['redacted'] == true,
    );
  }

  String get sourceLabel => LogSource.labelOf(source);

  /// La ligne mérite d'être dépliable seulement s'il reste quelque chose à
  /// montrer. Sous vue restreinte, c'est souvent faux.
  bool get hasDetail =>
      (error != null && !error!.isEmpty) ||
      (context != null && context!.isNotEmpty) ||
      (requestId != null) ||
      (route != null);

  /// Résumé de la requête : `GET /api/v1/parcels · 500 · 42 ms`.
  String get requestSummary => [
        if (method != null) method,
        if (route != null) route,
        if (statusCode != null) '$statusCode',
        if (durationMs != null) '$durationMs ms',
      ].whereType<String>().join(' · ');
}

/// Curseur de pagination. L'API pagine sur l'horodatage, jamais sur un offset.
class LogPage {
  final int limit;
  final bool hasMore;
  final String? nextCursor;

  const LogPage({this.limit = 50, this.hasMore = false, this.nextCursor});

  factory LogPage.fromJson(Map<String, dynamic> json) => LogPage(
        limit: _toIntOrNull(json['limit']) ?? 50,
        hasMore: json['hasMore'] == true,
        nextCursor: _toStringOrNull(json['nextCursor']),
      );
}

class LogList {
  final List<LogEntry> logs;
  final LogPage page;

  const LogList({this.logs = const [], this.page = const LogPage()});

  /// Vrai dès qu'une entrée est restreinte : suffit à afficher le bandeau
  /// d'explication en tête d'écran.
  bool get isRedacted => logs.any((entry) => entry.redacted);
}

/// État d'un service supervisé par Prometheus.
enum ServiceStatus {
  healthy('healthy', 'Opérationnel', PcTone.green),
  unavailable('unavailable', 'Indisponible', PcTone.red);

  final String value;
  final String label;
  final PcTone tone;
  const ServiceStatus(this.value, this.label, this.tone);

  /// Un état inconnu est traité comme une panne : sur un écran de supervision,
  /// l'optimisme est le mauvais défaut.
  static ServiceStatus fromString(String? raw) =>
      raw?.trim().toLowerCase() == 'healthy'
          ? ServiceStatus.healthy
          : ServiceStatus.unavailable;
}

class ServiceHealth {
  final String service;
  final ServiceStatus status;
  final DateTime? checkedAt;

  const ServiceHealth({
    required this.service,
    required this.status,
    this.checkedAt,
  });

  factory ServiceHealth.fromJson(Map<String, dynamic> json) => ServiceHealth(
        service: json['service']?.toString() ?? '',
        status: ServiceStatus.fromString(json['status']?.toString()),
        checkedAt: _toDate(json['checkedAt']),
      );

  static const Map<String, String> _labels = {
    'api': 'API',
    'postgres': 'Base de données',
    'caddy': 'Proxy web',
    'loki': 'Collecte des journaux',
    'alloy': 'Agent de collecte',
    'prometheus': 'Métriques',
  };

  String get label => _labels[service] ?? service;
}

/// Résumé d'une période : compteurs par niveau et par source, dernière entrée
/// et état des services.
class ObservabilitySummary {
  final DateTime? from;
  final DateTime? to;
  final int total;
  final Map<LogLevel, int> byLevel;
  final Map<String, int> bySource;
  final DateTime? latestAt;
  final List<ServiceHealth> services;

  const ObservabilitySummary({
    this.from,
    this.to,
    this.total = 0,
    this.byLevel = const {},
    this.bySource = const {},
    this.latestAt,
    this.services = const [],
  });

  factory ObservabilitySummary.fromJson(Map<String, dynamic> json) {
    final byLevel = <LogLevel, int>{};
    final rawLevels = _toMap(json['byLevel']) ?? const {};
    rawLevels.forEach((key, value) {
      final level = LogLevel.fromString(key);
      // Deux clés inconnues retomberaient toutes deux sur `info` : on additionne
      // plutôt que d'écraser, pour que le total reste juste.
      byLevel[level] = (byLevel[level] ?? 0) + (_toIntOrNull(value) ?? 0);
    });

    final bySource = <String, int>{};
    final rawSources = _toMap(json['bySource']) ?? const {};
    rawSources.forEach((key, value) {
      bySource[key] = _toIntOrNull(value) ?? 0;
    });

    final rawServices = json['services'];
    return ObservabilitySummary(
      from: _toDate(json['from']),
      to: _toDate(json['to']),
      total: _toIntOrNull(json['total']) ?? 0,
      byLevel: byLevel,
      bySource: bySource,
      latestAt: _toDate(json['latestAt']),
      services: rawServices is List
          ? rawServices
              .whereType<Map>()
              .map((e) => ServiceHealth.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }

  /// Total des niveaux qui appellent une action.
  int get actionableTotal => byLevel.entries
      .where((e) => e.key.isActionable)
      .fold(0, (sum, e) => sum + e.value);

  /// Source la plus bruyante sur la période, ou `null` si rien n'est remonté.
  MapEntry<String, int>? get topSource {
    if (bySource.isEmpty) return null;
    final entries = bySource.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.value == 0 ? null : entries.first;
  }

  int get unavailableServices =>
      services.where((s) => s.status == ServiceStatus.unavailable).length;
}

/// Filtres de la liste et du résumé. Les valeurs vides sont retirées à la
/// sérialisation : l'API rejette en 400 une source inconnue ou une recherche de
/// moins de deux caractères, y compris quand la valeur est une chaîne vide.
class LogFilters {
  final LogSource? source;
  final Set<LogLevel> levels;
  final String query;
  final String requestId;
  final DateTime? from;
  final DateTime? to;
  final int limit;

  const LogFilters({
    this.source,
    this.levels = const {},
    this.query = '',
    this.requestId = '',
    this.from,
    this.to,
    this.limit = 50,
  });

  LogFilters copyWith({
    LogSource? source,
    bool clearSource = false,
    Set<LogLevel>? levels,
    String? query,
    String? requestId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) =>
      LogFilters(
        source: clearSource ? null : (source ?? this.source),
        levels: levels ?? this.levels,
        query: query ?? this.query,
        requestId: requestId ?? this.requestId,
        from: from ?? this.from,
        to: to ?? this.to,
        limit: limit ?? this.limit,
      );

  Map<String, dynamic> toQuery({String? cursor}) {
    final trimmedQuery = query.trim();
    final trimmedRequestId = requestId.trim();
    return {
      if (source != null) 'source': source!.value,
      if (levels.isNotEmpty)
        'levels':
            LogLevel.values.where(levels.contains).map((l) => l.value).join(','),
      if (trimmedQuery.length >= 2) 'q': trimmedQuery,
      if (trimmedRequestId.isNotEmpty) 'requestId': trimmedRequestId,
      if (from != null) 'from': from!.toUtc().toIso8601String(),
      if (to != null) 'to': to!.toUtc().toIso8601String(),
      'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
  }
}

// ============================================================
// Journal d'audit métier
// ============================================================

class AuditLogActor {
  final String id;
  final String fullName;
  final String? phone;
  final String? role;

  const AuditLogActor({
    required this.id,
    required this.fullName,
    this.phone,
    this.role,
  });

  factory AuditLogActor.fromJson(Map<String, dynamic> json) => AuditLogActor(
        id: json['id']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        phone: _toStringOrNull(json['phone']),
        role: _toStringOrNull(json['role']),
      );
}

/// Une ligne du journal d'audit. Hors super administrateur, `beforeData` et
/// `afterData` sont absents et [redacted] vaut vrai : la ligne dit qui a fait
/// quoi, quand et depuis où, sans le détail des valeurs métier.
class AuditLogEntry {
  final String id;
  final String? actorId;
  final String? actorRole;
  final AuditLogActor? actor;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic>? beforeData;
  final Map<String, dynamic>? afterData;

  /// Le serveur signale l'existence d'un instantané même quand il ne l'expose
  /// pas : l'écran peut alors expliquer l'absence au lieu de l'ignorer.
  final bool hasChangeSnapshot;
  final String? ipAddress;
  final String? userAgent;
  final String? requestId;
  final bool redacted;
  final DateTime? createdAt;

  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.entityType,
    this.actorId,
    this.actorRole,
    this.actor,
    this.entityId,
    this.beforeData,
    this.afterData,
    this.hasChangeSnapshot = false,
    this.ipAddress,
    this.userAgent,
    this.requestId,
    this.redacted = false,
    this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final actor = _toMap(json['actor']);
    final before = _toMap(json['beforeData']);
    final after = _toMap(json['afterData']);
    return AuditLogEntry(
      id: json['id']?.toString() ?? '',
      actorId: _toStringOrNull(json['actorId']),
      actorRole: _toStringOrNull(json['actorRole']),
      actor: actor == null ? null : AuditLogActor.fromJson(actor),
      action: json['action']?.toString() ?? '',
      entityType: json['entityType']?.toString() ?? '',
      entityId: _toStringOrNull(json['entityId']),
      beforeData: before,
      afterData: after,
      // Les anciennes réponses n'ont pas le drapeau : on le déduit alors des
      // instantanés effectivement reçus.
      hasChangeSnapshot: json['hasChangeSnapshot'] == true ||
          before != null ||
          after != null,
      ipAddress: _toStringOrNull(json['ipAddress']),
      userAgent: _toStringOrNull(json['userAgent']),
      requestId: _toStringOrNull(json['requestId']),
      redacted: json['redacted'] == true,
      createdAt: _toDate(json['createdAt']),
    );
  }

  bool get hasVisibleSnapshot =>
      (beforeData != null && beforeData!.isNotEmpty) ||
      (afterData != null && afterData!.isNotEmpty);

  /// Une suppression ou un rejet doit se repérer d'un coup d'œil.
  PcTone get tone {
    if (RegExp(r'delete|cancel|reject|suspend').hasMatch(action)) {
      return PcTone.red;
    }
    if (RegExp(r'update|reset|export').hasMatch(action)) return PcTone.amber;
    if (RegExp(r'create|approve|validate|accept').hasMatch(action)) {
      return PcTone.green;
    }
    return PcTone.neutral;
  }

  /// Les actions sont nommées `domaine.objet.verbe` côté API. On traduit les
  /// segments connus plutôt que de maintenir une table de toutes les actions,
  /// qui dériverait au premier ajout backend. Table alignée sur
  /// `ACTION_SEGMENT` du web.
  static const Map<String, String> _actionSegments = {
    'advertisement': 'Annonce',
    'advertisements': 'Annonce',
    'assistance': 'Assistance',
    'audit': 'Audit',
    'auth': 'Authentification',
    'broadcast': 'Diffusion',
    'cash': 'Espèces',
    'commission': 'Commission',
    'config': 'Configuration',
    'expense': 'Dépense',
    'garage': 'Zone',
    'zone': 'Zone',
    'identity': 'Identité',
    'incident': 'Incident',
    'message': 'Message',
    'messages': 'Message',
    'notification': 'Notification',
    'observability': 'Observabilité',
    'offer': 'Offre',
    'parcel': 'Colis',
    'payment': 'Paiement',
    'paydunya': 'PayDunya',
    'reputation': 'Réputation',
    'score': 'Score',
    'user': 'Utilisateur',
    'wallet': 'Wallet',
    'withdrawal': 'Retrait',
    'accept': 'acceptée',
    'approve': 'approuvé',
    'cancel': 'annulé',
    'create': 'création',
    'delete': 'suppression',
    'export': 'export',
    'login': 'connexion',
    'logout': 'déconnexion',
    'reject': 'rejeté',
    'reset': 'réinitialisation',
    'update': 'mise à jour',
    'validate': 'validation',
  };

  String get actionLabel => action
      .split('.')
      .map((segment) => _actionSegments[segment] ?? segment)
      .join(' · ');

  static const Map<String, String> _roleLabels = {
    'client': 'Client',
    'driver': 'Chauffeur',
    'admin': 'Admin zone',
    'super_admin': 'Super admin',
    'support': 'Support',
    'support_technique': 'Support technique',
    'support_commercial': 'Support commercial',
  };

  /// Une action sans acteur est une action du système (tâche planifiée, IPN).
  String get roleLabel {
    final role = actorRole ?? actor?.role;
    if (role == null || role.isEmpty) return 'Système';
    return _roleLabels[role] ?? role;
  }

  String get actorLabel {
    final name = actor?.fullName;
    if (name != null && name.isNotEmpty) return name;
    return roleLabel;
  }
}
