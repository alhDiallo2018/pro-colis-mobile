// test/cancellation_test.dart
//
// Tests du modèle de résultat d'annulation : parsing tolérant, routage par rôle
// (confidentialité), exonération et valeurs dynamiques. Aucune règle métier
// n'est vérifiée ici — uniquement la fidélité de lecture des données API.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/cancellation.dart';
import 'package:procolis/models/parcel.dart';

void main() {
  Map<String, dynamic> sharedResponse() => {
        'success': true,
        'message': 'Colis annulé',
        'cancellation': {
          'allowed': true,
          'penalized': true,
          'responsibleParty': 'shared',
          'penalty': {
            'amount': '3000',
            'currency': 'XOF',
            'label': 'Pénalité d’annulation',
            'applied': true,
            'clientShare': '1200',
            'driverShare': '1800',
          },
          'refund': {
            'initialAmount': '10000',
            'fees': '200',
            'paydunyaFee': '100',
            'penaltyAmount': '1200',
            'refundedAmount': '8500',
            'status': 'completed',
          },
          'wallet': {'before': '5000', 'deduction': '1800', 'after': '3200'},
          'points': {'before': 100, 'deduction': 50, 'after': 50},
          'debt': {'before': '0', 'created': '0', 'after': '0'},
        },
      };

  group('CancellationResult parsing', () {
    test('parses a nested cancellation block', () {
      final result = CancellationResult.fromResponse(sharedResponse());

      expect(result.penalized, true);
      expect(result.party, CancellationParty.shared);
      expect(result.isSharedResponsibility, true);
      expect(result.penalty.amount, 3000);
      expect(result.penalty.clientShare, 1200);
      expect(result.penalty.driverShare, 1800);
      expect(result.refund.initialAmount, 10000);
      expect(result.refund.refundedAmount, 8500);
      expect(result.refund.paydunyaFee, 100);
      expect(result.wallet.deduction, 1800);
      expect(result.wallet.after, 3200);
      expect(result.points.deduction, 50);
      expect(result.debt.created, 0);
      expect(result.message, 'Colis annulé');
    });

    test('falls back to a flat response without a cancellation block', () {
      final result = CancellationResult.fromResponse({
        'success': true,
        'message': 'Opération effectuée',
        'penalized': false,
        'allowed': true,
      });

      expect(result.penalized, false);
      expect(result.party, isNull);
      expect(result.hasAnyEffect, false);
      expect(result.message, 'Opération effectuée');
    });

    test('client responsible routes the penalty to the client only', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'responsibleParty': 'client',
          'penalty': {'amount': '500'},
          'refund': {'refundedAmount': '4500', 'status': 'pending'},
        }
      });

      expect(result.party, CancellationParty.client);
      expect(result.penaltyForClient, 500);
      expect(result.penaltyForDriver, isNull);
      expect(result.hasClientImpact, true);
      expect(result.hasDriverImpact, false);
    });

    test('driver responsible hides client financial info', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'responsibleParty': 'driver',
          'penalty': {'amount': '500'},
          'wallet': {'deduction': '500'},
        }
      });

      expect(result.party, CancellationParty.driver);
      expect(result.penaltyForDriver, 500);
      expect(result.penaltyForClient, isNull);
      expect(result.hasDriverImpact, true);
      expect(result.hasClientImpact, false);
      expect(result.hasRefund, false);
    });

    test('shared responsibility never assumes a 50/50 split', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'responsibleParty': 'shared',
          'penalty': {'amount': '3000', 'clientShare': '500', 'driverShare': '2500'},
        }
      });

      expect(result.penaltyForClient, 500);
      expect(result.penaltyForDriver, 2500);
    });

    test('exoneration yields no effects', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {'allowed': true, 'penalized': false}
      });

      expect(result.penalized, false);
      expect(result.hasPenalty, false);
      expect(result.hasRefund, false);
      expect(result.hasAnyEffect, false);
    });

    test('penalty and refund amounts are dynamic, never recomputed', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'penalty': {'amount': '42'},
          'refund': {'refundedAmount': '958'},
        }
      });

      expect(result.penalty.amount, 42);
      expect(result.refund.refundedAmount, 958);
    });

    test('tolerates string-encoded numeric values', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'responsibleParty': 'client',
          'penalty': {'amount': '1250.50'},
          'points': {'before': '120', 'deduction': '30', 'after': '90'},
        }
      });

      expect(result.penalty.amount, 1250.50);
      expect(result.points.before, 120);
      expect(result.points.after, 90);
    });

    test('exempt cancellation with zero-filled blocks exposes no consequence',
        () {
      // Le backend émet toujours les blocs (avec 0) même en cas d'exonération :
      // le mobile ne doit pas les transformer en « pénalité 0 FCFA ».
      final result = CancellationResult.fromResponse({
        'success': true,
        'message': 'Colis annulé sans pénalité.',
        'cancellation': {
          'allowed': true,
          'penalized': false,
          'responsibleParty': 'exempt',
          'penalty': {
            'amount': 0,
            'currency': 'XOF',
            'label': null,
            'applied': false,
            'clientShare': 0,
            'driverShare': 0,
          },
          'refund': {
            'initialAmount': 0,
            'fees': 0,
            'paydunyaFee': 0,
            'penaltyAmount': 0,
            'refundedAmount': 0,
            'status': 'none',
          },
          'wallet': {'before': null, 'deduction': 0, 'after': null},
          'points': {'before': null, 'deduction': 0, 'after': null},
          'debt': {'before': null, 'created': 0, 'after': null},
        },
      });

      expect(result.isExempt, true);
      expect(result.party, CancellationParty.exempt);
      expect(result.penalized, false);
      expect(result.hasPenalty, false);
      expect(result.hasRefund, false);
      expect(result.hasWalletEffect, false);
      expect(result.hasPointsEffect, false);
      expect(result.hasDebtEffect, false);
      expect(result.penaltyForClient, isNull);
      expect(result.penaltyForDriver, isNull);
      expect(result.hasClientImpact, false);
      expect(result.hasDriverImpact, false);
      expect(result.hasAnyEffect, false);
    });

    test('zero penalty share does not surface a penalty for that party', () {
      // Responsabilité partagée avec part client nulle : le client ne doit
      // voir aucune pénalité, le chauffeur voit la sienne.
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'allowed': true,
          'penalized': true,
          'responsibleParty': 'shared',
          'penalty': {
            'amount': 3000,
            'currency': 'XOF',
            'applied': true,
            'clientShare': 0,
            'driverShare': 3000,
          },
        }
      });

      expect(result.hasPenalty, true);
      expect(result.penaltyForClient, isNull);
      expect(result.penaltyForDriver, 3000);
      expect(result.hasClientImpact, false);
      expect(result.hasDriverImpact, true);
    });

    test('preserves refund status across pending/completed/failed', () {
      String parse(String status) => CancellationResult.fromResponse({
            'cancellation': {
              'refund': {'initialAmount': '10000', 'refundedAmount': '5000', 'status': status},
            }
          }).refund.status!;

      expect(parse('pending'), 'pending');
      expect(parse('completed'), 'completed');
      expect(parse('failed'), 'failed');
    });

    test('partially absent blocks keep null and do not invent values', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'allowed': true,
          'penalized': true,
          'responsibleParty': 'driver',
          'penalty': {'amount': '500'},
          // refund absent, wallet absent, points absent, debt absent
        }
      });

      expect(result.penalty.amount, 500);
      expect(result.penaltyForDriver, 500);
      expect(result.refund.initialAmount, isNull);
      expect(result.refund.refundedAmount, isNull);
      expect(result.hasRefund, false);
      expect(result.hasWalletEffect, false);
      expect(result.hasPointsEffect, false);
      expect(result.hasDebtEffect, false);
    });

    test('parses the client penalty debt block (amount + reference)', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'allowed': true,
          'penalized': true,
          'responsibleParty': 'client',
          'penalty': {'amount': '2000', 'clientShare': '2000'},
          'clientDebt': {'amount': '1500', 'reference': 'PD-PC-1'},
        }
      });

      expect(result.clientDebt.amount, 1500);
      expect(result.clientDebt.reference, 'PD-PC-1');
      expect(result.hasClientDebt, true);
      expect(result.hasClientImpact, true);
    });

    test('zero client debt is not surfaced as a debt', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {
          'clientDebt': {'amount': 0, 'reference': null},
        }
      });

      expect(result.hasClientDebt, false);
      expect(result.clientDebt.amount, 0);
    });

    test('missing clientDebt block keeps it empty', () {
      final result = CancellationResult.fromResponse({
        'cancellation': {'allowed': true},
      });

      expect(result.clientDebt.amount, isNull);
      expect(result.clientDebt.reference, isNull);
      expect(result.hasClientDebt, false);
    });
  });

  group('CancellationReason', () {
    test('parses value/label pairs from the API', () {
      final reason = CancellationReason.fromJson(
          {'value': 'client_change_of_mind', 'label': 'Changement d’avis'});

      expect(reason.value, 'client_change_of_mind');
      expect(reason.label, 'Changement d’avis');
      expect(reason.isValid, true);
    });

    test('falls back label to value when label is missing', () {
      final reason =
          CancellationReason.fromJson({'value': 'driver_no_show'});

      expect(reason.value, 'driver_no_show');
      expect(reason.label, 'driver_no_show');
      expect(reason.isValid, true);
    });

    test('empty value is invalid', () {
      final reason = CancellationReason.fromJson({'value': ''});

      expect(reason.isValid, false);
    });

    test('non-map input yields an invalid reason (no crash)', () {
      final reason = CancellationReason.fromJson('not-a-map');

      expect(reason.isValid, false);
    });
  });

  group('CancellationOutcome', () {
    test('success carries a parsed result', () {
      final outcome = CancellationOutcome(
        result: CancellationResult.fromResponse(sharedResponse()),
      );

      expect(outcome.isSuccess, true);
      expect(outcome.errorMessage, isNull);
      expect(outcome.result!.penalty.driverShare, 1800);
    });

    test('failure carries an error message and code', () {
      const outcome = CancellationOutcome(
        errorMessage: 'Ce colis a déjà été annulé',
        errorCode: 'ALREADY_CANCELLED',
      );

      expect(outcome.isSuccess, false);
      expect(outcome.result, isNull);
      expect(outcome.errorCode, 'ALREADY_CANCELLED');
    });
  });

  group('Parcel cancellation integration', () {
    test('parses cancellation details when provided', () {
      final parcel = Parcel.fromJson({
        'id': 'p-1',
        'trackingNumber': 'PC-1',
        'status': 'cancelled',
        'cancellationReason': 'Annulation test',
        'cancellation': {
          'penalized': true,
          'responsibleParty': 'client',
          'penalty': {'amount': '700'},
          'refund': {'refundedAmount': '4300'},
        },
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(parcel.isCancelled, true);
      expect(parcel.cancellation, isNotNull);
      expect(parcel.cancellation!.penalty.amount, 700);
      expect(parcel.cancellation!.penaltyForClient, 700);
    });

    test('no cancellation block keeps it null', () {
      final parcel = Parcel.fromJson({
        'id': 'p-2',
        'trackingNumber': 'PC-2',
        'status': 'cancelled',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(parcel.cancellation, isNull);
    });
  });
}
