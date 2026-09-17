// test/financial_balance_test.dart
//
// Vérifie qu'une erreur réseau / une réponse invalide ne peut jamais être
// confondue avec une valeur financière réelle (0 FCFA / 0 point). Les parseurs
// `parseScoreBalance` et `parseWallet` sont exposés comme fonctions pures pour
// être testés sans réseau.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/api_service.dart';

void main() {
  group('parseScoreBalance', () {
    test('solde réel → valeur retournée', () {
      final result = ApiService.parseScoreBalance({
        'success': true,
        'message': 'Solde points',
        'balance': 250,
      }, 200);
      expect(result, 250.0);
    });

    test('solde réel = 0 → 0 (et non une erreur)', () {
      final result = ApiService.parseScoreBalance({
        'success': true,
        'balance': 0,
      }, 200);
      expect(result, 0.0);
    });

    test('solde transmis en chaîne → converti', () {
      final result = ApiService.parseScoreBalance({
        'success': true,
        'balance': '12.5',
      }, 200);
      expect(result, 12.5);
    });

    test('erreur serveur (status >= 400) → ApiException', () {
      expect(
        () => ApiService.parseScoreBalance({
          'success': false,
          'message': 'Erreur serveur',
        }, 500),
        throwsA(isA<ApiException>()),
      );
    });

    test('success:false → ApiException', () {
      expect(
        () => ApiService.parseScoreBalance({
          'success': false,
          'message': 'Non autorisé',
        }, 200),
        throwsA(isA<ApiException>()),
      );
    });

    test('réponse sans clé balance → ApiException (PAS 0)', () {
      expect(
        () => ApiService.parseScoreBalance({
          'success': true,
          'message': 'vide',
        }, 200),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('parseWallet', () {
    test('portefeuille réel → solde correct', () {
      final wallet = ApiService.parseWallet({
        'success': true,
        'wallet': {
          'id': 'w1',
          'userId': 'u1',
          'balance': 5000,
        },
        'transactions': <dynamic>[],
      }, 200);
      expect(wallet.balance, 5000.0);
    });

    test('solde réel = 0 → 0 (et non une erreur)', () {
      final wallet = ApiService.parseWallet({
        'success': true,
        'wallet': {
          'id': 'w1',
          'userId': 'u1',
          'balance': 0,
        },
        'transactions': <dynamic>[],
      }, 200);
      expect(wallet.balance, 0.0);
    });

    test('erreur serveur → ApiException', () {
      expect(
        () => ApiService.parseWallet({
          'success': false,
          'message': 'Session expirée',
        }, 401),
        throwsA(isA<ApiException>()),
      );
    });

    test('réponse sans clé wallet → ApiException (PAS wallet vide)', () {
      expect(
        () => ApiService.parseWallet({
          'success': true,
          'message': 'Portefeuille',
        }, 200),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
