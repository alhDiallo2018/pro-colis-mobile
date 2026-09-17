// test/driver_cancellation_test.dart
//
// Annulation chauffeur : vérifie la lecture fidèle de la réponse de
// `POST /driver/parcels/:id/cancel` (contrat mobile `serializeCancellationMobile`).
// Le mobile ne calcule aucun montant et ne suppose aucune répartition : il ne
// fait que relire la pénalité / wallet / points / dette décidées par le backend.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/cancellation.dart';

void main() {
  Map<String, dynamic> driverCancelResponse() => {
        'success': true,
        'message': 'Colis annulé (pénalité chauffeur 1800 FCFA).',
        'cancellation': {
          'allowed': true,
          'penalized': true,
          'responsibleParty': 'driver',
          'penalty': {
            'amount': 1800,
            'currency': 'XOF',
            'label': "Pénalité d'annulation (driver)",
            'applied': true,
            'clientShare': 0,
            'driverShare': 1800,
          },
          // Vue chauffeur : le backend masque les montants privés du client.
          'refund': null,
          'wallet': {'before': 5000, 'deduction': 1800, 'after': 3200},
          'points': {'before': 100, 'deduction': 0, 'after': 100},
          'debt': {'before': 0, 'created': 0, 'after': 0},
        },
      };

  group('annulation chauffeur — parsing de la réponse', () {
    test('responsabilité chauffeur → pénalité imputée au chauffeur seul', () {
      final result =
          CancellationResult.fromResponse(driverCancelResponse());

      expect(result.party, CancellationParty.driver);
      expect(result.penaltyForDriver, 1800);
      expect(result.penaltyForClient, isNull);
      expect(result.hasDriverImpact, true);
      expect(result.hasClientImpact, false);
    });

    test('wallet prélevé par le backend → effet affiché, jamais recalculé', () {
      final result =
          CancellationResult.fromResponse(driverCancelResponse());

      expect(result.wallet.deduction, 1800);
      expect(result.wallet.before, 5000);
      expect(result.wallet.after, 3200);
      expect(result.hasWalletEffect, true);
    });

    test('points non prélevés (déduction 0) → aucun faux effet points', () {
      final result =
          CancellationResult.fromResponse(driverCancelResponse());

      expect(result.points.deduction, 0);
      expect(result.hasPointsEffect, false);
    });

    test('refund masqué côté chauffeur → aucun remboursement affiché', () {
      final result =
          CancellationResult.fromResponse(driverCancelResponse());

      expect(result.refund.refundedAmount, isNull);
      expect(result.hasRefund, false);
    });

    test('aucune répartition 50/50 supposée : lecture stricte des parts', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'responsibleParty': 'shared',
          'penalty': {
            'amount': 3000,
            'clientShare': 700,
            'driverShare': 2300,
          },
        }
      });

      expect(result.penaltyForClient, 700);
      expect(result.penaltyForDriver, 2300);
      // 3000 / 2 = 1500 : si une règle 50/50 avait été supposée, le test
      // échouerait ici.
      expect(result.penaltyForClient, isNot(1500));
      expect(result.penaltyForDriver, isNot(1500));
    });

    test('part inconnue (responsabilité absente) → aucun montant inventé', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'allowed': true,
          'penalized': true,
          'penalty': {'amount': 1500},
        }
      });

      // Sans désignation de responsable, ni le client ni le chauffeur ne se
      // voit attribuer la pénalité : on ne devine pas l'auteur.
      expect(result.party, isNull);
      expect(result.penaltyForClient, isNull);
      expect(result.penaltyForDriver, isNull);
    });
  });

  group('statuts de remboursement', () {
    test('pending / completed / failed / none sont préservés', () {
      String parse(String status) => CancellationResult.fromResponse({
            'cancellation': {
              'refund': {
                'initialAmount': '5000',
                'refundedAmount': '5000',
                'status': status,
              },
            }
          }).refund.status!;

      expect(parse('pending'), 'pending');
      expect(parse('completed'), 'completed');
      expect(parse('failed'), 'failed');
      expect(parse('none'), 'none');
    });

    test('remboursement nul (0) → hasRefund faux, pas de « remboursé 0 FCFA »',
        () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'refund': {
            'initialAmount': 0,
            'refundedAmount': 0,
            'status': 'none',
          },
        }
      });

      expect(result.hasRefund, false);
      expect(result.refund.refundedAmount, 0);
    });
  });
}
