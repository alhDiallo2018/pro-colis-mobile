// lib/services/api/insurance_api.dart
//
// Devis et souscription d'assurance colis.
//
// Expose deux endpoints :
//  - POST /parcels/insurance/quote               → simulation (sans engagement)
//  - POST /parcels/:parcelId/insurance/subscribe → persistance sur un colis
//
// Le serveur recalcule la prime : on ne lui envoie que les paramètres de
// base pour éviter tout écart entre affichage mobile et facturation.

import 'dart:developer' as developer;

import 'client.dart';

class InsuranceQuote {
  final bool ok;
  final String? reason;
  final int premiumXof;
  final int coverageXof;
  final double coverageRate;
  final bool crossBorder;
  final List<String> exclusions;

  const InsuranceQuote({
    required this.ok,
    this.reason,
    this.premiumXof = 0,
    this.coverageXof = 0,
    this.coverageRate = 0,
    this.crossBorder = false,
    this.exclusions = const [],
  });

  factory InsuranceQuote.fromJson(Map<String, dynamic> json) => InsuranceQuote(
        ok: json['ok'] == true,
        reason: json['reason']?.toString(),
        premiumXof: (json['premiumXof'] as num?)?.toInt() ?? 0,
        coverageXof: (json['coverageXof'] as num?)?.toInt() ?? 0,
        coverageRate: (json['coverageRate'] as num?)?.toDouble() ?? 0,
        crossBorder: json['crossBorder'] == true,
        exclusions: (json['exclusions'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
      );
}

class InsuranceSubscription {
  final String id;
  final String parcelId;
  final int premiumXof;
  final int coverageXof;
  final String status;
  final DateTime subscribedAt;

  const InsuranceSubscription({
    required this.id,
    required this.parcelId,
    required this.premiumXof,
    required this.coverageXof,
    required this.status,
    required this.subscribedAt,
  });

  factory InsuranceSubscription.fromJson(Map<String, dynamic> json) =>
      InsuranceSubscription(
        id: json['id']?.toString() ?? '',
        parcelId: json['parcelId']?.toString() ?? '',
        premiumXof: (json['premiumXof'] as num?)?.toInt() ?? 0,
        coverageXof: (json['coverageXof'] as num?)?.toInt() ?? 0,
        status: json['status']?.toString() ?? 'unknown',
        subscribedAt:
            DateTime.tryParse(json['subscribedAt']?.toString() ?? '') ??
                DateTime.now(),
      );
}

class InsuranceSubscribeResult {
  final bool ok;
  final String? reason;
  final InsuranceSubscription? subscription;

  const InsuranceSubscribeResult({
    required this.ok,
    this.reason,
    this.subscription,
  });
}

class InsuranceApi {
  final ApiClient client;

  InsuranceApi(this.client);

  /// Simule une prime d'assurance. Ne lève pas : on renvoie un `InsuranceQuote`
  /// marqué `ok=false` pour que la UI puisse afficher la raison de refus
  /// (type non assurable, valeur manquante, assurance désactivée, …) plutôt
  /// qu'un simple "erreur réseau".
  Future<InsuranceQuote> quote({
    required int declaredValueXof,
    required String parcelType,
    bool crossBorder = false,
  }) async {
    try {
      final res = await client.dio.post('/parcels/insurance/quote', data: {
        'declaredValueXof': declaredValueXof,
        'parcelType': parcelType,
        'crossBorder': crossBorder,
      });
      final body = client.handle(res);
      final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
      final raw = (payload['quote'] as Map?)?.cast<String, dynamic>() ?? {};
      return InsuranceQuote.fromJson(raw);
    } catch (error, stackTrace) {
      developer.log(
        'Devis assurance indisponible',
        name: 'InsuranceApi',
        error: error,
        stackTrace: stackTrace,
      );
      return const InsuranceQuote(ok: false, reason: 'network');
    }
  }

  /// Souscrit l'assurance pour un colis existant. L'endpoint est idempotent
  /// (contrainte unique `parcelId`) : une seconde souscription renvoie
  /// `ok=false` avec le motif du serveur plutôt que de dupliquer.
  Future<InsuranceSubscribeResult> subscribe({
    required String parcelId,
    required int declaredValueXof,
    required String parcelType,
    bool crossBorder = false,
  }) async {
    try {
      final res = await client.dio.post(
        '/parcels/$parcelId/insurance/subscribe',
        data: {
          'declaredValueXof': declaredValueXof,
          'parcelType': parcelType,
          'crossBorder': crossBorder,
        },
      );
      final body = client.handle(res);
      final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
      final ok = payload['ok'] == true;
      if (!ok) {
        return InsuranceSubscribeResult(
          ok: false,
          reason: payload['reason']?.toString(),
        );
      }
      final sub = (payload['subscription'] as Map?)?.cast<String, dynamic>();
      return InsuranceSubscribeResult(
        ok: true,
        subscription:
            sub == null ? null : InsuranceSubscription.fromJson(sub),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Souscription assurance refusée',
        name: 'InsuranceApi',
        error: error,
        stackTrace: stackTrace,
      );
      return const InsuranceSubscribeResult(ok: false, reason: 'network');
    }
  }
}
