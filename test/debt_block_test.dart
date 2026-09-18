import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/utils/debt_block.dart';

void main() {
  test('extrait la dette payable jointe au refus de création', () {
    final error = ApiException.fromResponse({
      'success': false,
      'message': 'Dette à régler',
      'error': {
        'code': clientDebtLimitErrorCode,
        'details': [
          {
            'path': 'clientDebt',
            'debtAmount': 1500,
            'debtLimit': 1000,
            'debts': [
              {
                'id': 'debt-1',
                'amount': 1500,
                'remaining': 900,
                'reference': 'PD-PC-1',
                'status': 'partially_paid',
              }
            ],
          }
        ],
      },
    }, 403);

    final debt = payableClientDebtFrom(error);
    expect(error.code, clientDebtLimitErrorCode);
    expect(debt?.id, 'debt-1');
    expect(debt?.displayedRemaining, 900);
  });

  test('ne confond pas une dette chauffeur avec une dette client', () {
    const error = ApiException(
      'Dette chauffeur',
      403,
      code: driverDebtLimitErrorCode,
    );
    expect(payableClientDebtFrom(error), isNull);
  });

  test('reconnaît le refus de nouvelle mission chauffeur', () {
    expect(
      isDriverDebtBlockResponse({
        'success': false,
        'error': {'code': driverDebtLimitErrorCode},
      }),
      isTrue,
    );
  });
}
