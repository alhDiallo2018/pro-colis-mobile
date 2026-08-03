// lib/services/api/parcels_api.dart
//
// Estimation tarifaire d'un colis.
//
// Le barème vit dans `SystemConfig` (`pricing.baseFee`, `pricing.pricePerKg`,
// `pricing.urgentFee`, `pricing.insuranceFee`) et n'est connu que du serveur :
// le recopier côté mobile ferait diverger l'estimation affichée du tarif que
// l'administrateur a réglé.

import 'client.dart';

/// Détail d'une estimation, tel que renvoyé par `POST /parcels/estimate`.
class ParcelEstimate {
  final double amount;
  final String currency;
  final double baseFee;
  final double pricePerKg;
  final double urgentFee;
  final double insuranceFee;

  const ParcelEstimate({
    required this.amount,
    this.currency = 'XOF',
    this.baseFee = 0,
    this.pricePerKg = 0,
    this.urgentFee = 0,
    this.insuranceFee = 0,
  });

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory ParcelEstimate.fromJson(Map<String, dynamic> json) => ParcelEstimate(
        amount: _toDouble(json['amount']),
        currency: json['currency']?.toString() ?? 'XOF',
        baseFee: _toDouble(json['baseFee']),
        pricePerKg: _toDouble(json['pricePerKg']),
        urgentFee: _toDouble(json['urgentFee']),
        insuranceFee: _toDouble(json['insuranceFee']),
      );
}

class ParcelsApi {
  final ApiClient client;

  ParcelsApi(this.client);

  /// Estimation pour un poids et des options donnés.
  ///
  /// Renvoie `null` plutôt que de lever : l'estimation est une aide à la
  /// saisie, pas une étape bloquante — le formulaire doit rester utilisable
  /// hors connexion, l'utilisateur pouvant de toute façon fixer son prix.
  Future<ParcelEstimate?> estimate({
    required double weight,
    bool isUrgent = false,
    bool isInsured = false,
  }) async {
    try {
      final res = await client.dio.post('/parcels/estimate', data: {
        'weight': weight,
        'isUrgent': isUrgent,
        'isInsured': isInsured,
      });
      final data = client.handle(res);
      final status = res.statusCode ?? 500;
      if (status >= 400 || data['success'] == false) return null;
      final raw = (data['estimate'] as Map?)?.cast<String, dynamic>();
      if (raw == null) return null;
      return ParcelEstimate.fromJson(raw);
    } catch (_) {
      return null;
    }
  }
}
