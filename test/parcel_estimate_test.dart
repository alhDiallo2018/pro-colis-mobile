import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/api/parcels_api.dart';

void main() {
  group('ParcelEstimate', () {
    test('conserve le barème détaillé renvoyé par le serveur', () {
      final estimate = ParcelEstimate.fromJson({
        'amount': '4750',
        'currency': 'XOF',
        'baseFee': 1000,
        'pricePerKg': 500,
        'urgentFee': 1000,
        'insuranceFee': 250,
      });

      expect(estimate.isValid, isTrue);
      expect(estimate.amount, 4750);
      expect(estimate.urgentFee, 1000);
      expect(estimate.insuranceFee, 250);
    });

    test('refuse un prix nul plutôt que de l’afficher comme estimation', () {
      final estimate = ParcelEstimate.fromJson({'amount': 0});

      expect(estimate.isValid, isFalse);
    });
  });
}
