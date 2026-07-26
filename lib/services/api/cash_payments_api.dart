// lib/services/api/cash_payments_api.dart
//
// Règlements en espèces : déclaration par le chauffeur après encaissement, puis
// réconciliation par un admin.
//
// Une course en espèces n'est jamais encaissée par la plateforme. Le chauffeur
// reçoit l'argent en main propre (de l'expéditeur au ramassage ou du
// destinataire à la livraison) puis le déclare ici : le paiement passe alors en
// `processing` (« encaissement déclaré »). Un admin le valide ensuite, ce qui le
// passe en `completed` et marque le colis payé.

import 'client.dart';

class CashPaymentsApi {
  final ApiClient client;
  CashPaymentsApi(this.client);

  /// Le chauffeur déclare avoir encaissé les espèces d'un colis.
  ///
  /// [collectionPoint] vaut `sender_pickup` ou `receiver_delivery` et rappelle
  /// auprès de qui l'argent a été reçu. [proofUrl] est l'URL d'une photo déjà
  /// téléversée (reçu, colis remis…), facultative.
  Future<Map<String, dynamic>> declareCollection(
    String parcelId, {
    required double amount,
    required String collectionPoint,
    String? note,
    String? proofUrl,
  }) async {
    try {
      final res = await client.dio.post(
        '/driver/parcels/$parcelId/declare-cash',
        data: <String, dynamic>{
          'amount': amount,
          'collectionPoint': collectionPoint,
          if (note != null && note.isNotEmpty) 'note': note,
          if (proofUrl != null && proofUrl.isNotEmpty) 'proofUrl': proofUrl,
        },
      );
      final data = client.handle(res);
      final payment = data['payment'] ?? data['result'] ?? data;
      return {
        'success': data['success'] ?? true,
        'payment': payment is Map ? Map<String, dynamic>.from(payment) : null,
        if (data['message'] != null) 'message': data['message'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Encaissements espèces déclarés par le chauffeur connecté, tous statuts
  /// confondus, pour qu'il suive ce qui reste à valider.
  Future<List<Map<String, dynamic>>> driverDeclarations() async {
    try {
      final res = await client.dio.get('/driver/cash-declarations');
      final data = client.handle(res);
      final list = (data['declarations'] as List?) ??
          (data['payments'] as List?) ??
          (data['data'] as List?) ??
          const [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// File de réconciliation admin : les encaissements déclarés et non validés.
  Future<List<Map<String, dynamic>>> pendingDeclarations({
    Map<String, dynamic>? params,
  }) async {
    try {
      final res = await client.dio.get(
        '/super-admin/payments/cash-declarations',
        queryParameters: params,
      );
      final data = client.handle(res);
      final list = (data['declarations'] as List?) ??
          (data['payments'] as List?) ??
          (data['data'] as List?) ??
          const [];
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// L'admin confirme avoir retrouvé l'argent : paiement `completed`, colis payé.
  Future<Map<String, dynamic>> validateDeclaration(String paymentId) async {
    try {
      final res = await client.dio
          .post('/super-admin/payments/$paymentId/validate-cash');
      final data = client.handle(res);
      return {'success': data['success'] ?? true, ...data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// L'admin rejette la déclaration (montant incohérent, argent non remis…).
  /// Le paiement repasse en `failed` et le colis reste dû.
  Future<Map<String, dynamic>> rejectDeclaration(
    String paymentId, {
    required String reason,
  }) async {
    try {
      final res = await client.dio.post(
        '/super-admin/payments/$paymentId/reject-cash',
        data: {'reason': reason},
      );
      final data = client.handle(res);
      return {'success': data['success'] ?? true, ...data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fixe le mode de règlement d'un colis (canal, et point d'encaissement en
  /// espèces). Utilisé quand le client arrête son choix après la négociation.
  Future<Map<String, dynamic>> setPaymentChannel(
    String parcelId, {
    required String channel,
    String? collectionPoint,
  }) async {
    try {
      final res = await client.dio.patch(
        '/parcels/$parcelId/payment-channel',
        data: <String, dynamic>{
          'paymentChannel': channel,
          if (collectionPoint != null) 'cashCollectionPoint': collectionPoint,
        },
      );
      final data = client.handle(res);
      return {'success': data['success'] ?? true, ...data};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
