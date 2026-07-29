import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/widgets/phone_contact_picker.dart';

void main() {
  group('normalizeContactPhoneNumber', () {
    test('retire les séparateurs usuels', () {
      expect(
        normalizeContactPhoneNumber('77 123-45-67'),
        '771234567',
      );
    });

    test('conserve le préfixe international placé au début', () {
      expect(
        normalizeContactPhoneNumber('+221 (77) 123 45 67'),
        '+221771234567',
      );
    });

    test('ne conserve pas un signe plus mal placé', () {
      expect(
        normalizeContactPhoneNumber('221+77 123 45 67'),
        '221771234567',
      );
    });

    test('renvoie une valeur vide sans chiffre exploitable', () {
      expect(normalizeContactPhoneNumber(null), isEmpty);
      expect(normalizeContactPhoneNumber('  -  '), isEmpty);
    });
  });
}
