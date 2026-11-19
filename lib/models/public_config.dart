import 'cancellation.dart';

class HelpGuide {
  const HelpGuide(
      {required this.id,
      required this.language,
      required this.title,
      required this.text,
      this.audioUrl});
  final String id, language, title, text;
  final String? audioUrl;
  factory HelpGuide.fromJson(dynamic value) {
    final json = value is Map ? value : <String, dynamic>{};
    return HelpGuide(
        id: json['id']?.toString() ?? '',
        language: json['language']?.toString() ?? 'fr',
        title: json['title']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        audioUrl: json['audioUrl']?.toString());
  }
}

// lib/models/public_config.dart
//
// Configuration publique renvoyée par `/public/config`. Elle contient les
// paramètres métier (commission, points, retraits, contact support) que le
// mobile affiche et utilise pour ses calculs. Aucune valeur n'est codée en dur
// dans l'application : tout provient de la configuration administrée côté API.

double _num(dynamic v, double fallback) {
  if (v is num) return v.toDouble();
  if (v == null) return fallback;
  final parsed = double.tryParse(v.toString());
  return parsed ?? fallback;
}

String _str(dynamic v, String fallback) =>
    (v == null) ? fallback : v.toString();

List<int> _intList(dynamic v) {
  if (v is! List) return const [];
  final result = <int>[];
  for (final item in v) {
    final n = (item is num) ? item.toInt() : int.tryParse(item.toString());
    if (n != null && n > 0) result.add(n);
  }
  return result;
}

/// Catégorie d'aide renvoyée par la configuration publique. Le libellé est
/// administré côté API ; `icon` est une clé (nom Material) mappée côté mobile.
class HelpTopic {
  final String icon;
  final String title;

  const HelpTopic({this.icon = '', this.title = ''});

  factory HelpTopic.fromJson(dynamic json) {
    if (json is! Map) return const HelpTopic();
    return HelpTopic(
      icon: json['icon']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

/// Question fréquente renvoyée par la configuration publique.
class HelpFaq {
  final String question;
  final String answer;

  const HelpFaq({this.question = '', this.answer = ''});

  factory HelpFaq.fromJson(dynamic json) {
    if (json is! Map) return const HelpFaq();
    return HelpFaq(
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
    );
  }
}

List<T> _objList<T>(dynamic v, T Function(dynamic) fromJson) {
  if (v is! List) return const [];
  return v.map(fromJson).toList();
}

/// Timings administrables (polling, timeouts, fenêtres GPS et messaging).
/// Correspond côté API au module `utils/timings-config.js` et côté web à
/// `TimingsConfig`. Valeurs par défaut gardées côté mobile (`kTimingsFallback`)
/// pour fonctionner au boot avant la première réponse `/public/config`.
class TimingsConfig {
  // Polling
  final int parcelStatusPollMs;
  final int parcelsListPollMs;
  final int announcementsFeedPollMs;
  final int journeyPositionsPollMs;
  final int operationsDashboardPollMs;
  final int driverDiscoveryPollMs;
  // Timeouts
  final int apiRequestTimeoutMs;
  final int geolocationTimeoutMs;
  final int googleAuthTimeoutMs;
  // GPS
  final int locationUploadIntervalSec;
  final int locationFreshnessSec;
  // Messaging
  final int messageEditWindowMs;
  final int broadcastSnoozeHours;
  // Discovery
  final int positionTtlMs;
  // Webhooks (exposés en lecture)
  final int webhookRetryBackoffBaseMs;
  final int webhookPollIntervalMs;
  final int webhookMaxAttempts;
  // PWA
  final int pwaSyncMaxAttempts;

  const TimingsConfig({
    this.parcelStatusPollMs = 60000,
    this.parcelsListPollMs = 15000,
    this.announcementsFeedPollMs = 5000,
    this.journeyPositionsPollMs = 15000,
    this.operationsDashboardPollMs = 60000,
    this.driverDiscoveryPollMs = 60000,
    this.apiRequestTimeoutMs = 30000,
    this.geolocationTimeoutMs = 15000,
    this.googleAuthTimeoutMs = 15000,
    this.locationUploadIntervalSec = 10,
    this.locationFreshnessSec = 60,
    this.messageEditWindowMs = 900000,
    this.broadcastSnoozeHours = 2,
    this.positionTtlMs = 600000,
    this.webhookRetryBackoffBaseMs = 30000,
    this.webhookPollIntervalMs = 15000,
    this.webhookMaxAttempts = 6,
    this.pwaSyncMaxAttempts = 10,
  });

  static int _int(dynamic v, int fallback) {
    if (v is num) {
      final n = v.toInt();
      return n >= 0 ? n : fallback;
    }
    if (v == null) return fallback;
    final parsed = int.tryParse(v.toString());
    return (parsed != null && parsed >= 0) ? parsed : fallback;
  }

  factory TimingsConfig.fromJson(dynamic value) {
    const d = TimingsConfig();
    if (value is! Map) return d;
    final m = Map<String, dynamic>.from(value);
    return TimingsConfig(
      parcelStatusPollMs: _int(m['parcelStatusPollMs'], d.parcelStatusPollMs),
      parcelsListPollMs: _int(m['parcelsListPollMs'], d.parcelsListPollMs),
      announcementsFeedPollMs:
          _int(m['announcementsFeedPollMs'], d.announcementsFeedPollMs),
      journeyPositionsPollMs:
          _int(m['journeyPositionsPollMs'], d.journeyPositionsPollMs),
      operationsDashboardPollMs:
          _int(m['operationsDashboardPollMs'], d.operationsDashboardPollMs),
      driverDiscoveryPollMs:
          _int(m['driverDiscoveryPollMs'], d.driverDiscoveryPollMs),
      apiRequestTimeoutMs:
          _int(m['apiRequestTimeoutMs'], d.apiRequestTimeoutMs),
      geolocationTimeoutMs:
          _int(m['geolocationTimeoutMs'], d.geolocationTimeoutMs),
      googleAuthTimeoutMs:
          _int(m['googleAuthTimeoutMs'], d.googleAuthTimeoutMs),
      locationUploadIntervalSec:
          _int(m['locationUploadIntervalSec'], d.locationUploadIntervalSec),
      locationFreshnessSec:
          _int(m['locationFreshnessSec'], d.locationFreshnessSec),
      messageEditWindowMs:
          _int(m['messageEditWindowMs'], d.messageEditWindowMs),
      broadcastSnoozeHours:
          _int(m['broadcastSnoozeHours'], d.broadcastSnoozeHours),
      positionTtlMs: _int(m['positionTtlMs'], d.positionTtlMs),
      webhookRetryBackoffBaseMs:
          _int(m['webhookRetryBackoffBaseMs'], d.webhookRetryBackoffBaseMs),
      webhookPollIntervalMs:
          _int(m['webhookPollIntervalMs'], d.webhookPollIntervalMs),
      webhookMaxAttempts:
          _int(m['webhookMaxAttempts'], d.webhookMaxAttempts),
      pwaSyncMaxAttempts:
          _int(m['pwaSyncMaxAttempts'], d.pwaSyncMaxAttempts),
    );
  }
}

/// Snapshot de référence utilisé tant que `PublicConfig` n'est pas chargé.
const TimingsConfig kTimingsFallback = TimingsConfig();

class PublicConfig {
  final double commissionPercentage;
  final double commissionMinimum;
  final double commissionMaximum;

  final double deliveryPoints;
  final double signupBonus;
  final double cfaPerPoint;
  final double commitmentFee;
  final List<int> scorePacks;

  final double withdrawalMinAmount;
  final double withdrawalMaxAmount;
  final double withdrawalMaxPerDay;

  final String insufficientPolicy;
  final double debtLimit;

  final String supportPhone;
  final String supportEmail;
  final String supportTechnicalEmail;
  final String supportTechnicalPhone;
  final String supportResponseTime;
  final String supportAvailability;

  final List<HelpGuide> helpGuides;
  final List<HelpTopic> helpTopics;
  final List<HelpFaq> helpFaqs;

  /// Motifs d'annulation exposés par la configuration publique
  /// (`cancellation.reasons`). Uniquement `value`/`label` : les règles
  /// financières (responsabilité, exemption, pénalité) restent côté serveur.
  final List<CancellationReason> cancellationReasons;

  /// Identité légale configurée par l'administrateur (affichée dans les pages
  /// Mentions légales / Confidentialité / CGU). Champs vides = « à compléter ».
  final String legalCompanyName;
  final String legalAddress;
  final String legalRegistrationNumber;
  final String legalCdpAuthorization;
  final String legalPrivacyEmail;
  final String legalPublisherName;
  final String legalHostName;
  final String legalDirectorName;
  final String legalDirectorEmail;
  final String legalTechnicalDirectorName;
  final String legalTechnicalDirectorEmail;

  /// Phase 1 externalisation : paramètres d'authentification administrables
  /// via `auth.*` dans `SystemConfig`. Permet de borner la saisie OTP sans
  /// valeur magique codée côté mobile (`attempts < 5` historique).
  final int otpExpiryMinutes;
  final int otpMaxAttempts;

  /// Phase 1 externalisation : devise d'affichage par défaut et liste
  /// autorisée. Remplace les `currency = 'XOF'` codés en dur dans les modèles
  /// paiement / colis / douane.
  final String currencyDefault;
  final List<String> currencySupported;

  /// Phase 1 externalisation : tarification internationale CEDEAO. Les paires
  /// desservies et la limite de poids proviennent de la config admin.
  final double internationalMaxWeightKg;
  final List<String> internationalCountryPairs;

  /// Phase 3 externalisation : timings (polling, timeouts, fenêtres GPS/messaging).
  /// `null` tant que la réponse `/public/config` n'embarque pas le bloc —
  /// l'appelant retombe alors sur `kTimingsFallback`.
  final TimingsConfig? timings;

  const PublicConfig({
    this.commissionPercentage = 0,
    this.commissionMinimum = 0,
    this.commissionMaximum = 0,
    this.deliveryPoints = 0,
    this.signupBonus = 0,
    this.cfaPerPoint = 0,
    this.commitmentFee = 0,
    this.scorePacks = const [],
    this.withdrawalMinAmount = 0,
    this.withdrawalMaxAmount = 0,
    this.withdrawalMaxPerDay = 0,
    this.insufficientPolicy = 'block',
    this.debtLimit = 0,
    this.supportPhone = '',
    this.supportEmail = '',
    this.supportTechnicalEmail = '',
    this.supportTechnicalPhone = '',
    this.supportResponseTime = '',
    this.supportAvailability = '',
    this.helpGuides = const [],
    this.helpTopics = const [],
    this.helpFaqs = const [],
    this.cancellationReasons = const [],
    this.legalCompanyName = '',
    this.legalAddress = '',
    this.legalRegistrationNumber = '',
    this.legalCdpAuthorization = '',
    this.legalPrivacyEmail = '',
    this.legalPublisherName = '',
    this.legalHostName = '',
    this.legalDirectorName = '',
    this.legalDirectorEmail = '',
    this.legalTechnicalDirectorName = '',
    this.legalTechnicalDirectorEmail = '',
    this.otpExpiryMinutes = 10,
    this.otpMaxAttempts = 5,
    this.currencyDefault = 'XOF',
    this.currencySupported = const ['XOF'],
    this.internationalMaxWeightKg = 50,
    this.internationalCountryPairs = const [],
    this.timings,
  });

  factory PublicConfig.fromJson(Map<String, dynamic> json) {
    final commission = json['commission'] is Map
        ? Map<String, dynamic>.from(json['commission'] as Map)
        : const <String, dynamic>{};
    final points = json['points'] is Map
        ? Map<String, dynamic>.from(json['points'] as Map)
        : const <String, dynamic>{};
    final withdrawal = json['withdrawal'] is Map
        ? Map<String, dynamic>.from(json['withdrawal'] as Map)
        : const <String, dynamic>{};
    final support = json['support'] is Map
        ? Map<String, dynamic>.from(json['support'] as Map)
        : const <String, dynamic>{};
    final help = json['help'] is Map
        ? Map<String, dynamic>.from(json['help'] as Map)
        : const <String, dynamic>{};
    final cancellation = json['cancellation'] is Map
        ? Map<String, dynamic>.from(json['cancellation'] as Map)
        : const <String, dynamic>{};
    final legal = json['legal'] is Map
        ? Map<String, dynamic>.from(json['legal'] as Map)
        : const <String, dynamic>{};
    final auth = json['auth'] is Map
        ? Map<String, dynamic>.from(json['auth'] as Map)
        : const <String, dynamic>{};
    final currency = json['currency'] is Map
        ? Map<String, dynamic>.from(json['currency'] as Map)
        : const <String, dynamic>{};
    final international = json['international'] is Map
        ? Map<String, dynamic>.from(json['international'] as Map)
        : const <String, dynamic>{};

    List<String> _stringList(dynamic v, List<String> fallback) {
      if (v is! List) return fallback;
      final result = <String>[];
      for (final item in v) {
        if (item == null) continue;
        final s = item.toString().trim();
        if (s.isNotEmpty) result.add(s);
      }
      return result.isEmpty ? fallback : result;
    }

    return PublicConfig(
      commissionPercentage: _num(commission['percentage'], 0),
      commissionMinimum: _num(commission['minAmount'], 0),
      commissionMaximum: _num(commission['maxAmount'], 0),
      deliveryPoints: _num(points['deliveryCompleted'], 0),
      signupBonus: _num(points['signupBonus'], 0),
      cfaPerPoint: _num(points['cfaPerPoint'], 0),
      commitmentFee: _num(points['commitmentFee'], 0),
      scorePacks: _intList(points['packs']),
      withdrawalMinAmount: _num(withdrawal['minAmount'], 0),
      withdrawalMaxAmount: _num(withdrawal['maxAmount'], 0),
      withdrawalMaxPerDay: _num(withdrawal['maxPerDay'], 0),
      insufficientPolicy: _str(json['insufficientPolicy'], 'block'),
      debtLimit: _num(json['debtLimit'], 0),
      supportPhone: _str(support['phone'], ''),
      supportEmail: _str(support['email'], ''),
      supportTechnicalEmail: _str(support['technicalEmail'], ''),
      supportTechnicalPhone: _str(support['technicalPhone'], ''),
      supportResponseTime: _str(support['responseTime'], ''),
      supportAvailability: _str(support['availability'], ''),
      helpGuides: _objList(help['guides'], HelpGuide.fromJson),
      helpTopics: _objList(help['topics'], HelpTopic.fromJson),
      helpFaqs: _objList(help['faqs'], HelpFaq.fromJson),
      cancellationReasons:
          _objList(cancellation['reasons'], CancellationReason.fromJson)
              .where((r) => r.isValid)
              .toList(),
      legalCompanyName: _str(legal['companyName'], ''),
      legalAddress: _str(legal['address'], ''),
      legalRegistrationNumber: _str(legal['registrationNumber'], ''),
      legalCdpAuthorization: _str(legal['cdpAuthorization'], ''),
      legalPrivacyEmail: _str(legal['privacyEmail'], ''),
      legalPublisherName: _str(legal['publisherName'], ''),
      legalHostName: _str(legal['hostName'], ''),
      legalDirectorName: _str(legal['directorName'], ''),
      legalDirectorEmail: _str(legal['directorEmail'], ''),
      legalTechnicalDirectorName: _str(legal['technicalDirectorName'], ''),
      legalTechnicalDirectorEmail: _str(legal['technicalDirectorEmail'], ''),
      otpExpiryMinutes: _num(auth['otpExpiryMinutes'], 10).toInt(),
      otpMaxAttempts: _num(auth['otpMaxAttempts'], 5).toInt(),
      currencyDefault: _str(currency['default'], 'XOF'),
      currencySupported: _stringList(currency['supported'], const ['XOF']),
      internationalMaxWeightKg: _num(international['maxWeightKg'], 50),
      internationalCountryPairs:
          _stringList(international['countryPairs'], const <String>[]),
      timings:
          json['timings'] == null ? null : TimingsConfig.fromJson(json['timings']),
    );
  }

  /// Timings effectifs : valeurs admin si disponibles, sinon fallback statique.
  TimingsConfig get effectiveTimings => timings ?? kTimingsFallback;

  /// Numéro de téléphone du support, fourni par la configuration API.
  String get displaySupportPhone => supportPhone.trim();

  String get displaySupportEmail => supportEmail.trim();

  String get displayTechnicalEmail => supportTechnicalEmail.trim();

  String get displayTechnicalPhone => supportTechnicalPhone.trim();

  /// Délai de réponse du support fourni par la config (ex. « 24h »).
  String get displaySupportResponseTime => supportResponseTime.trim();

  /// Plage de disponibilité du support (ex. « 7j/7 »).
  String get displaySupportAvailability => supportAvailability.trim();

  /// Raison sociale configurée par l'administrateur (vide si non renseignée).
  String get displayLegalCompanyName => legalCompanyName.trim();

  /// Adresse du siège configurée par l'administrateur.
  String get displayLegalAddress => legalAddress.trim();

  /// Numéro d'immatriculation configuré par l'administrateur.
  String get displayLegalRegistrationNumber => legalRegistrationNumber.trim();

  /// Numéro d'autorisation CDP configuré par l'administrateur.
  String get displayLegalCdpAuthorization => legalCdpAuthorization.trim();

  /// Contact protection des données configuré par l'administrateur.
  String get displayLegalPrivacyEmail => legalPrivacyEmail.trim();

  /// Directeur de la publication configuré par l'administrateur.
  String get displayLegalPublisherName => legalPublisherName.trim();

  /// Hébergeur de la plateforme configuré par l'administrateur.
  String get displayLegalHostName => legalHostName.trim();

  /// Directeur Général (nom) configuré par l'administrateur.
  String get displayLegalDirectorName => legalDirectorName.trim();

  /// Directeur Général (email) configuré par l'administrateur.
  String get displayLegalDirectorEmail => legalDirectorEmail.trim();

  /// Directeur Technique (nom) configuré par l'administrateur.
  String get displayLegalTechnicalDirectorName =>
      legalTechnicalDirectorName.trim();

  /// Directeur Technique (email) configuré par l'administrateur.
  String get displayLegalTechnicalDirectorEmail =>
      legalTechnicalDirectorEmail.trim();
}
