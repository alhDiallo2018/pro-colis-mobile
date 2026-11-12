// lib/services/api/international_carriers_api.dart
//
// Phase 5 — Devis carriers internationaux (SCP-041).
// Consomme GET /parcels/:id/international-offers et
// GET /parcels/international-estimate (pré-devis sans colis).

import 'dart:developer' as developer;

import 'client.dart';

class CarrierOffer {
  final String carrier;
  final String service;
  final int priceXof;
  final int etaDays;
  final String? originZone;
  final String? destinationZone;
  final String confidence; // 'stub' ou 'live' (V2)

  const CarrierOffer({
    required this.carrier,
    required this.service,
    required this.priceXof,
    required this.etaDays,
    this.originZone,
    this.destinationZone,
    this.confidence = 'stub',
  });

  factory CarrierOffer.fromJson(Map<String, dynamic> json) => CarrierOffer(
        carrier: json['carrier']?.toString() ?? '',
        service: json['service']?.toString() ?? '',
        priceXof: (json['priceXof'] as num?)?.toInt() ?? 0,
        etaDays: (json['etaDays'] as num?)?.toInt() ?? 0,
        originZone: json['originZone']?.toString(),
        destinationZone: json['destinationZone']?.toString(),
        confidence: json['confidence']?.toString() ?? 'stub',
      );
}

class InternationalOffersResult {
  final String parcelId;
  final String origin;
  final String destination;
  final bool isCustomsSigned;
  final List<CarrierOffer> offers;
  final int acceptedCarriers;

  const InternationalOffersResult({
    required this.parcelId,
    required this.origin,
    required this.destination,
    this.isCustomsSigned = false,
    this.offers = const [],
    this.acceptedCarriers = 0,
  });

  factory InternationalOffersResult.fromJson(Map<String, dynamic> json) =>
      InternationalOffersResult(
        parcelId: json['parcelId']?.toString() ?? '',
        origin: json['origin']?.toString() ?? '',
        destination: json['destination']?.toString() ?? '',
        isCustomsSigned: json['isCustomsSigned'] == true,
        offers: (json['offers'] as List?)
                ?.whereType<Map>()
                .map((e) => CarrierOffer.fromJson(e.cast<String, dynamic>()))
                .toList() ??
            const [],
        acceptedCarriers: (json['acceptedCarriers'] as num?)?.toInt() ?? 0,
      );
}

/// Pré-devis avant création — expose le tarif sous-régional (CEDEAO + MR)
/// pour un couple pays/poids donné. Permet au client de simuler un envoi
/// international sans engager un colis.
class InternationalEstimate {
  final bool ok;
  final String? reason;
  final int priceXof;
  final double priceDisplay;
  final String displayCurrency;
  final int customsSurchargeXof;
  final bool crossBorder;
  final int slaDays;
  final List<String> requiredDocuments;
  final int? maxWeightKg;

  const InternationalEstimate({
    required this.ok,
    this.reason,
    this.priceXof = 0,
    this.priceDisplay = 0,
    this.displayCurrency = 'XOF',
    this.customsSurchargeXof = 0,
    this.crossBorder = false,
    this.slaDays = 0,
    this.requiredDocuments = const [],
    this.maxWeightKg,
  });

  factory InternationalEstimate.fromJson(Map<String, dynamic> json) =>
      InternationalEstimate(
        ok: json['ok'] == true,
        reason: json['reason']?.toString(),
        priceXof: (json['priceXof'] as num?)?.toInt() ?? 0,
        priceDisplay: (json['priceDisplay'] as num?)?.toDouble() ?? 0,
        displayCurrency: json['displayCurrency']?.toString() ?? 'XOF',
        customsSurchargeXof:
            (json['customsSurchargeXof'] as num?)?.toInt() ?? 0,
        crossBorder: json['crossBorder'] == true,
        slaDays: (json['slaDays'] as num?)?.toInt() ?? 0,
        requiredDocuments: (json['requiredDocuments'] as List?)
                ?.whereType<String>()
                .toList() ??
            const [],
        maxWeightKg: (json['maxWeightKg'] as num?)?.toInt(),
      );
}

class InternationalCarriersApi {
  final ApiClient client;

  InternationalCarriersApi(this.client);

  Future<InternationalOffersResult> fetch(String parcelId) async {
    final res = await client.dio.get('/parcels/$parcelId/international-offers');
    final body = client.handle(res);
    final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
    return InternationalOffersResult.fromJson(payload);
  }

  /// Simulation avant création de colis. Ne lève pas : les cas de refus
  /// métier (pays non desservi, surpoids, pré-devis désactivé) sont portés
  /// par `ok=false` + `reason`.
  Future<InternationalEstimate> estimate({
    required String originCountry,
    required String destinationCountry,
    required double weightKg,
    String displayCurrency = 'XOF',
    bool declareValue = false,
  }) async {
    try {
      final res = await client.dio.get(
        '/parcels/international-estimate',
        queryParameters: {
          'originCountry': originCountry,
          'destinationCountry': destinationCountry,
          'weightKg': weightKg,
          'displayCurrency': displayCurrency,
          'declareValue': declareValue ? 'true' : 'false',
        },
      );
      final body = client.handle(res);
      final payload = (body['data'] as Map?)?.cast<String, dynamic>() ?? body;
      final raw = (payload['quote'] as Map?)?.cast<String, dynamic>() ?? {};
      return InternationalEstimate.fromJson(raw);
    } catch (error, stackTrace) {
      developer.log(
        'Pré-devis international indisponible',
        name: 'InternationalCarriersApi',
        error: error,
        stackTrace: stackTrace,
      );
      return const InternationalEstimate(ok: false, reason: 'network');
    }
  }
}
