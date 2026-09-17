import 'package:dio/dio.dart';

import 'client.dart';

/// Corps de requête d'un règlement de dette de pénalité client via PayDunya.
///
/// `amount` est OMMIS lorsque `null` : le backend règle alors le reliquat
/// complet. Le mobile n'envoie jamais un montant qu'il aurait lui-même calculé
/// (pas de `remaining = amount - paid` côté client) : soit il omet `amount`
/// (« tout payer »), soit il transmet le montant saisi par l'utilisateur.
Map<String, dynamic> buildPenaltyDebtPayload({
  required String debtId,
  double? amount,
}) {
  return <String, dynamic>{
    'type': 'penalty_debt',
    'debtId': debtId,
    if (amount != null) 'amount': amount,
  };
}

/// Extrait le message métier renvoyé par le backend dans l'enveloppe d'erreur
/// (`{ success, message, error: { code, details } }`). Les erreurs de validation
/// portent leur libellé utilisateur dans `error.details[].message`, pas dans
/// `message`.
String? _serverMessage(Map<String, dynamic> body) {
  final error = body['error'];
  if (error is Map) {
    final details = error['details'];
    if (details is List && details.isNotEmpty) {
      final parts = details
          .whereType<Map>()
          .map((d) => d['message']?.toString())
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts.join(' ');
    }
  }
  return null;
}

/// Traduit un échec de création de paiement en libellé utilisateur propre.
///
/// Le backend reste l'autorité : aucun montant, statut ou reliquat n'est
/// déduit ici. Un `403` (dette non autorisée) est masqué par un message
/// générique de sécurité ; un `422` remonte le message du serveur (montant
/// supérieur au restant, dette déjà réglée, etc.).
String friendlyPenaltyDebtError(int statusCode, {String? serverMessage}) {
  switch (statusCode) {
    case 401:
      return 'Votre session a expiré. Veuillez vous reconnecter.';
    case 403:
      return 'Accès refusé. Vous n’êtes pas autorisé à régler cette dette.';
    case 404:
      return 'Cette dette est introuvable.';
    case 409:
      return serverMessage ??
          'Cette dette a changé d’état. Veuillez actualiser.';
    case 422:
      return serverMessage ?? 'Le montant saisi est invalide.';
    default:
      return serverMessage ?? 'Impossible de créer le paiement.';
  }
}

class PaydunyaApi {
  final ApiClient client;
  PaydunyaApi(this.client);

  Future<Map<String, dynamic>> createPayment(String type,
      {String? parcelId, int? points, double? amount, String? debtId}) async {
    try {
      final data = <String, dynamic>{'type': type};
      if (parcelId != null) data['parcelId'] = parcelId;
      if (points != null) data['points'] = points;
      if (amount != null) data['amount'] = amount;
      if (debtId != null) data['debtId'] = debtId;
      final res = await client.dio.post('/payments/paydunya/create', data: data);
      final rd = client.handle(res);
      return rd['data'] ?? rd;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Règlement d'une dette de pénalité client (`type: penalty_debt`).
  ///
  /// Retourne un contrat stable : `{ success, token, paymentUrl, statusCode,
  /// message }`. Le `statusCode` permet à l'appelant de distinguer 401 / 403 /
  /// 404 / 409 / 422 des erreurs réseau, et de produire un message propre.
  Future<Map<String, dynamic>> createPenaltyDebtPayment({
    required String debtId,
    double? amount,
  }) async {
    final payload = buildPenaltyDebtPayload(debtId: debtId, amount: amount);
    try {
      final res = await client.dio.post('/payments/paydunya/create', data: payload);
      final status = res.statusCode ?? 0;
      final rd = client.handle(res);
      // `validateStatus` renvoie une Response pour les 4xx : on distingue ici
      // l'échec métier (403/404/409/422) du succès, sans lever d'exception.
      if (status >= 400) {
        return {
          'success': false,
          'statusCode': status,
          'message': friendlyPenaltyDebtError(
            status,
            serverMessage: _serverMessage(rd),
          ),
        };
      }
      final token = rd['token']?.toString() ?? '';
      final paymentUrl = rd['paymentUrl']?.toString() ?? '';
      if (token.isEmpty || paymentUrl.isEmpty) {
        return {
          'success': false,
          'statusCode': status,
          'message': 'Réponse de paiement invalide',
        };
      }
      return {
        'success': true,
        'token': token,
        'paymentUrl': paymentUrl,
      };
    } on DioException catch (e) {
      return _penaltyDebtDioError(e);
    } catch (e) {
      return {'success': false, 'statusCode': 0, 'message': e.toString()};
    }
  }

  Map<String, dynamic> _penaltyDebtDioError(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    String? serverMessage;
    if (data is Map) {
      serverMessage =
          _serverMessage(Map<String, dynamic>.from(data));
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return {
        'success': false,
        'statusCode': status,
        'message': 'Le serveur ne répond pas. Vérifiez votre connexion.',
      };
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      return {
        'success': false,
        'statusCode': status,
        'message': 'Serveur injoignable. Vérifiez votre connexion.',
      };
    }
    if (e.type == DioExceptionType.cancel) {
      return {'success': false, 'statusCode': status, 'message': 'Paiement annulé.'};
    }
    return {
      'success': false,
      'statusCode': status,
      'message': friendlyPenaltyDebtError(status, serverMessage: serverMessage),
    };
  }

  Future<Map<String, dynamic>> confirmPayment(String token) async {
    try {
      final res = await client.dio.get('/payments/paydunya/confirm/$token');
      final rd = client.handle(res);
      return rd['data'] ?? rd;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
