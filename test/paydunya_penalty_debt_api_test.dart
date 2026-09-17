// test/paydunya_penalty_debt_api_test.dart
//
// Tests du client API PayDunya pour le règlement `penalty_debt` (sans réseau).
// Un adaptateur Dio factice vérifie le payload envoyé et la traduction des
// réponses du backend (succès, 403, 409, 422, erreur réseau, token/paymentUrl
// manquants).

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/api/client.dart';
import 'package:procolis/services/api/paydunya_api.dart';

class _FakeAdapter implements HttpClientAdapter {
  final int statusCode;
  final Map<String, dynamic> body;
  final bool failNetwork;

  _FakeAdapter({
    required this.statusCode,
    required this.body,
    this.failNetwork = false,
  });

  Map<String, dynamic>? lastData;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastData = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : null;
    if (failNetwork) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'no route to host',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PaydunyaApi _api(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost',
    headers: {'Content-Type': 'application/json'},
    validateStatus: (s) => s != null && s < 500,
  ));
  dio.httpClientAdapter = adapter;
  return PaydunyaApi(ApiClient(dioOverride: dio));
}

void main() {
  const debtId = 'd5f8e3a1-9c42-4a7b-b1e0-2f3a4b5c6d7e';

  group('PaydunyaApi.createPenaltyDebtPayment', () {
    test('envoie type=penalty_debt + debtId et renvoie token/paymentUrl', () async {
      final adapter = _FakeAdapter(
        statusCode: 201,
        body: {
          'success': true,
          'message': 'Facture PayDunya creee',
          'token': 'tok-1',
          'paymentUrl': 'https://paydunya.test/checkout',
        },
      );
      final api = _api(adapter);

      final result = await api.createPenaltyDebtPayment(debtId: debtId);

      expect(adapter.lastPath, '/payments/paydunya/create');
      expect(adapter.lastData?['type'], 'penalty_debt');
      expect(adapter.lastData?['debtId'], debtId);
      expect(adapter.lastData?.containsKey('amount'), false);
      expect(result['success'], true);
      expect(result['token'], 'tok-1');
      expect(result['paymentUrl'], 'https://paydunya.test/checkout');
    });

    test('paiement partiel : amount transmis', () async {
      final adapter = _FakeAdapter(
        statusCode: 201,
        body: {'success': true, 'token': 'tok', 'paymentUrl': 'u'},
      );
      final api = _api(adapter);

      await api.createPenaltyDebtPayment(debtId: debtId, amount: 750);

      expect(adapter.lastData?['amount'], 750);
    });

    test('422 montant > restant : message serveur extrait', () async {
      final adapter = _FakeAdapter(
        statusCode: 422,
        body: {
          'success': false,
          'message': 'Donnees invalides',
          'error': {
            'code': 'VALIDATION_ERROR',
            'details': [
              {
                'path': 'body.amount',
                'message': 'Le paiement ne peut pas dépasser le montant restant (1500 FCFA)',
              }
            ],
          },
        },
      );
      final api = _api(adapter);

      final result = await api.createPenaltyDebtPayment(debtId: debtId);

      expect(result['success'], false);
      expect(result['statusCode'], 422);
      expect(
        result['message'],
        'Le paiement ne peut pas dépasser le montant restant (1500 FCFA)',
      );
    });

    test('403 dette non autorisée : message générique (aucune fuite)', () async {
      final adapter = _FakeAdapter(
        statusCode: 403,
        body: {
          'success': false,
          'message': 'Cette dette ne vous appartient pas',
          'error': {'code': 'FORBIDDEN', 'details': <dynamic>[]},
        },
      );
      final api = _api(adapter);

      final result = await api.createPenaltyDebtPayment(debtId: debtId);

      expect(result['statusCode'], 403);
      expect(result['message'], isNot(contains('appartient')));
      expect(result['message'], contains('Accès refusé'));
    });

    test('422 dette déjà réglée : message serveur relayé', () async {
      final adapter = _FakeAdapter(
        statusCode: 422,
        body: {
          'success': false,
          'message': 'Donnees invalides',
          'error': {
            'code': 'VALIDATION_ERROR',
            'details': [
              {'path': 'body.debtId', 'message': 'Cette dette est déjà réglée'}
            ],
          },
        },
      );
      final api = _api(adapter);

      final result = await api.createPenaltyDebtPayment(debtId: debtId);

      expect(result['statusCode'], 422);
      expect(result['message'], 'Cette dette est déjà réglée');
    });

    test('409 conflit : état modifié', () async {
      final adapter = _FakeAdapter(
        statusCode: 409,
        body: {
          'success': false,
          'message': 'Conflit de donnees',
          'error': {'code': 'CONFLICT', 'details': <dynamic>[]},
        },
      );
      final api = _api(adapter);

      final result = await api.createPenaltyDebtPayment(debtId: debtId);

      expect(result['statusCode'], 409);
      expect(result['message'], 'Cette dette a changé d’état. Veuillez actualiser.');
    });

    test('12. token/paymentUrl manquants : échec propre', () async {
      final adapter = _FakeAdapter(
        statusCode: 200,
        body: {'success': true, 'message': 'ok'},
      );
      final api = _api(adapter);

      final result = await api.createPenaltyDebtPayment(debtId: debtId);

      expect(result['success'], false);
      expect(result['message'], 'Réponse de paiement invalide');
    });

    test('11. erreur réseau : message utilisateur propre', () async {
      final adapter = _FakeAdapter(
        statusCode: 0,
        body: const {},
        failNetwork: true,
      );
      final api = _api(adapter);

      final result = await api.createPenaltyDebtPayment(debtId: debtId);

      expect(result['success'], false);
      expect(result['message'], 'Serveur injoignable. Vérifiez votre connexion.');
    });
  });
}
