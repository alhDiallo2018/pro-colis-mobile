import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/screens/experience/workspace_screen.dart';
import 'package:procolis/services/api/experience_api.dart';
import 'package:procolis/models/public_config.dart';
import 'package:procolis/models/parcel.dart';

void main() {
  test('préparation de lot bornée, poids décimal et aucun engagement copié',
      () {
    final row = parseShipmentLines('Awa;+221770000000;Documents;1,5').single;
    expect(row['data']['weight'], 1.5);
    expect(row['data'].containsKey('price'), false);
    expect(() => parseShipmentLines('Awa;770000000;Documents;-1'),
        throwsFormatException);
    expect(
        () => parseShipmentLines(
            List.filled(51, 'A;770000000;Colis;1').join('\n')),
        throwsFormatException);
  });
  test('les offres conservent les données de comparaison dans le cache', () {
    final bid = Bid.fromJson({
      'id': 'b',
      'driverVehicleType': 'car',
      'driverAvailability': 'busy',
      'lastMessageAt': '2026-10-28T10:00:00Z',
      'price': '2000',
      'lastPrice': '1800'
    });
    final restored = Bid.fromJson(bid.toJson());
    expect(restored.currentPrice, 1800);
    expect(restored.driverAvailability, 'busy');
    expect(restored.driverVehicleType, 'car');
    expect(restored.lastMessageAt, DateTime.utc(2026, 10, 28, 10));
  });
  test('guides multilingues et reçu sans données bancaires', () {
    final guide = HelpGuide.fromJson({
      'id': 'a',
      'language': 'wo',
      'title': 'Guide',
      'text': 'Texte validé',
      'audioUrl': 'https://example.com/audio.mp3'
    });
    expect(guide.language, 'wo');
    expect(
        receiptText({
          'id': 'p',
          'amount': 2000,
          'method': 'cash',
          'createdAt': '2026-10-28'
        }, 'SP-001'),
        contains('SP-001'));
    expect(experienceMoney(null), 'À confirmer');
  });
}
