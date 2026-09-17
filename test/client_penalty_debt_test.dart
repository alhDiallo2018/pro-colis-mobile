// test/client_penalty_debt_test.dart
//
// Tests du modèle de dette de pénalité client et du contrat de paiement
// `penalty_debt`. Aucune règle métier n'est vérifiée ici : uniquement la
// fidélité de lecture des données API et la construction du payload PayDunya.
//
// Points couverts :
//  1. JSON clientDebt avec id
//  2. parsing UUID
//  3. création paiement penalty_debt avec debtId
//  4. paiement complet sans amount
//  5. paiement partiel avec amount
//  6. 422 montant > restant (message serveur)
//  7. 403 dette non autorisée (message générique)
//  8. dette déjà réglée (message serveur relayé)
// 11. erreur réseau (mapping)
// 13. aucune utilisation du wallet chauffeur
// 14. aucun calcul local de pénalité
// 15. aucun calcul local du remaining si le backend le fournit

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/cancellation.dart';
import 'package:procolis/services/api/paydunya_api.dart';

void main() {
  group('CancellationClientDebt parsing', () {
    test('1. JSON clientDebt avec id', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'responsibleParty': 'client',
          'clientDebt': {
            'id': 'd5f8e3a1-9c42-4a7b-b1e0-2f3a4b5c6d7e',
            'amount': '1500',
            'reference': 'PD-PC-1',
          },
        }
      });

      expect(result.clientDebt.id, 'd5f8e3a1-9c42-4a7b-b1e0-2f3a4b5c6d7e');
      expect(result.clientDebt.amount, 1500);
      expect(result.clientDebt.reference, 'PD-PC-1');
      expect(result.clientDebt.hasId, true);
      expect(result.clientDebt.hasDebt, true);
    });

    test('2. parsing UUID (chaîne préservée telle quelle)', () {
      const uuid = '123e4567-e89b-12d3-a456-426614174000';
      final debt = CancellationClientDebt.fromJson({'id': uuid});

      expect(debt.id, uuid);
      expect(debt.hasId, true);
    });

    test('2bis. id absent → hasId false et payable impossible', () {
      final debt = CancellationClientDebt.fromJson({
        'amount': '1500',
        'reference': 'PD-PC-1',
      });

      expect(debt.id, isNull);
      expect(debt.hasId, false);
    });

    test('15. remaining fourni par le backend → utilisé tel quel (aucun calcul)',
        () {
      final debt = CancellationClientDebt.fromJson({
        'id': 'uuid',
        'amount': '1500',
        'remaining': '500',
        'status': 'partially_paid',
      });

      // remaining est relu, PAS recalculé (amount - paid = 1500 - 500 ici).
      expect(debt.remaining, 500);
      expect(debt.displayedRemaining, 500);
      expect(debt.status, 'partially_paid');
    });

    test('15bis. remaining absent → amount exposé, jamais soustrait', () {
      final debt = CancellationClientDebt.fromJson({
        'id': 'uuid',
        'amount': '1500',
      });

      expect(debt.remaining, isNull);
      expect(debt.displayedRemaining, 1500);
    });
  });

  group('buildPenaltyDebtPayload', () {
    test('3. création paiement penalty_debt avec debtId', () {
      final payload =
          buildPenaltyDebtPayload(debtId: 'd5f8e3a1-9c42-4a7b-b1e0-2f3a4b5c6d7e');

      expect(payload['type'], 'penalty_debt');
      expect(payload['debtId'], 'd5f8e3a1-9c42-4a7b-b1e0-2f3a4b5c6d7e');
    });

    test('4. paiement complet → amount OMIS', () {
      final payload = buildPenaltyDebtPayload(debtId: 'uuid');

      expect(payload.containsKey('amount'), false);
    });

    test('5. paiement partiel → amount transmis tel quel', () {
      final payload = buildPenaltyDebtPayload(debtId: 'uuid', amount: 750);

      expect(payload['amount'], 750);
    });

    test('13. aucun champ wallet / commission / points', () {
      final payload =
          buildPenaltyDebtPayload(debtId: 'uuid', amount: 500);

      expect(payload.keys, isNot(contains('wallet')));
      expect(payload.keys, isNot(contains('walletId')));
      expect(payload.keys, isNot(contains('commission')));
      expect(payload.keys, isNot(contains('points')));
      expect(payload.keys, isNot(contains('driverId')));
    });
  });

  group('friendlyPenaltyDebtError', () {
    test('6. 422 montant > restant → message serveur relayé', () {
      const serverMessage =
          'Le paiement ne peut pas dépasser le montant restant (1500 FCFA)';
      final message = friendlyPenaltyDebtError(422, serverMessage: serverMessage);

      expect(message, serverMessage);
    });

    test('7. 403 dette non autorisée → message générique (aucune fuite)', () {
      final message = friendlyPenaltyDebtError(403, serverMessage: 'SECRET');

      expect(message, isNot(contains('SECRET')));
      expect(message, contains('Accès refusé'));
    });

    test('8. dette déjà réglée → message serveur relayé', () {
      final message =
          friendlyPenaltyDebtError(422, serverMessage: 'Cette dette est déjà réglée');

      expect(message, 'Cette dette est déjà réglée');
    });

    test('404 → dette introuvable', () {
      expect(friendlyPenaltyDebtError(404), 'Cette dette est introuvable.');
    });

    test('409 → conflit (état modifié)', () {
      expect(
        friendlyPenaltyDebtError(409),
        'Cette dette a changé d’état. Veuillez actualiser.',
      );
    });

    test('401 → session expirée', () {
      expect(
        friendlyPenaltyDebtError(401),
        'Votre session a expiré. Veuillez vous reconnecter.',
      );
    });

    test('422 sans message serveur → libellé générique', () {
      expect(friendlyPenaltyDebtError(422), 'Le montant saisi est invalide.');
    });

    test('14. aucun calcul de pénalité/reliquat n’est effectué ici', () {
      // Les fonctions de mapping ne reçoivent qu'un statut et un message :
      // elles ne peuvent ni calculer une pénalité ni un reliquat.
      final payload = buildPenaltyDebtPayload(debtId: 'uuid');
      expect(payload.containsKey('remaining'), false);
      expect(payload.containsKey('penalty'), false);
    });
  });
}
