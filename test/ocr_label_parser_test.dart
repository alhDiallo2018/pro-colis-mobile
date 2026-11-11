import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/ocr_label_parser.dart';

/// Tests unitaires du parser d'étiquettes OCR. Le parser est un service pur
/// — aucun mock, aucune dépendance Flutter. Ces scénarios couvrent les
/// formats d'étiquettes vraisemblables au Sénégal.
void main() {
  group('parseOcrLabel — téléphone', () {
    test('extrait un numéro Sénégal avec +221', () {
      final r = parseOcrLabel('Mamadou Diallo\nTel: +221 77 123 45 67');
      expect(r.receiverPhone, '+221771234567');
    });

    test('extrait un numéro sans préfixe (local 9 chiffres)', () {
      final r = parseOcrLabel('Fatou Sall\n77 123 45 67');
      expect(r.receiverPhone, '+221771234567');
    });

    test('tolère les séparateurs variés (points, tirets)', () {
      final r1 = parseOcrLabel('77.123.45.67');
      final r2 = parseOcrLabel('77-123-45-67');
      expect(r1.receiverPhone, '+221771234567');
      expect(r2.receiverPhone, '+221771234567');
    });

    test('reconnaît les 5 opérateurs mobiles (70, 75, 76, 77, 78)', () {
      for (final prefix in ['70', '75', '76', '77', '78']) {
        final r = parseOcrLabel('$prefix 123 45 67');
        expect(r.receiverPhone, '+221${prefix}1234567',
            reason: 'prefix $prefix');
      }
    });

    test('ignore un numéro trop court', () {
      final r = parseOcrLabel('Numéro: 123 45');
      expect(r.receiverPhone, isNull);
    });

    test('ignore un numéro non sénégalais (ex. 06 France)', () {
      final r = parseOcrLabel('06 12 34 56 78');
      expect(r.receiverPhone, isNull);
    });
  });

  group('parseOcrLabel — poids', () {
    test('extrait "2 kg"', () {
      final r = parseOcrLabel('Poids: 2 kg');
      expect(r.weightKg, 2.0);
    });

    test('extrait "2.5 kg" et "2,5 kg" (virgule française)', () {
      expect(parseOcrLabel('2.5 kg').weightKg, 2.5);
      expect(parseOcrLabel('2,5 kg').weightKg, 2.5);
    });

    test('tolère la casse "KG", "Kg", "kG"', () {
      expect(parseOcrLabel('3 KG').weightKg, 3.0);
      expect(parseOcrLabel('3 Kg').weightKg, 3.0);
      expect(parseOcrLabel('3 kG').weightKg, 3.0);
    });

    test('accepte "kilos" ou "kilogrammes"', () {
      expect(parseOcrLabel('2 kilos').weightKg, 2.0);
      expect(parseOcrLabel('1,2 kilogrammes').weightKg, 1.2);
    });

    test('ignore une valeur aberrante (> 500 kg)', () {
      final r = parseOcrLabel('999 kg');
      expect(r.weightKg, isNull);
    });
  });

  group('parseOcrLabel — nom destinataire', () {
    test('extrait après "Destinataire:"', () {
      final r = parseOcrLabel(
          'SendProColis\nDestinataire : Awa Diop\n77 123 45 67');
      expect(r.receiverName, 'Awa Diop');
    });

    test('repli : première ligne vraisemblable avec 2+ mots capitalisés', () {
      final r = parseOcrLabel('Mamadou Diallo\n77 123 45 67\n2 kg');
      expect(r.receiverName, 'Mamadou Diallo');
    });

    test('ignore une ligne avec digits (téléphone)', () {
      final r = parseOcrLabel('77 123 45 67\nMamadou Diallo');
      expect(r.receiverName, 'Mamadou Diallo');
    });

    test('ignore un seul mot', () {
      final r = parseOcrLabel('Mamadou\n77 123 45 67');
      expect(r.receiverName, isNull);
    });
  });

  group('parseOcrLabel — adresse', () {
    test('extrait après "Adresse:"', () {
      final r = parseOcrLabel(
          'Awa Diop\n77 123 45 67\nAdresse : Rue 10, Mermoz, Dakar');
      expect(r.receiverAddress, 'Rue 10, Mermoz, Dakar');
    });

    test('repli : ligne avec mot-clé (Rue, Avenue, Quartier)', () {
      final r = parseOcrLabel(
          'Fatou Sall\n77 987 65 43\nAvenue Cheikh Anta Diop\n3 kg');
      expect(r.receiverAddress, 'Avenue Cheikh Anta Diop');
    });

    test('repli sur quartiers connus de Dakar', () {
      final r = parseOcrLabel(
          'Ibrahima Ba\n78 555 44 33\nAlmadies, villa 42\n1,5 kg');
      expect(r.receiverAddress, 'Almadies, villa 42');
    });

    test('retourne null quand aucune adresse plausible', () {
      final r = parseOcrLabel('Fatou Sall\n77 123 45 67\n2 kg');
      expect(r.receiverAddress, isNull);
    });
  });

  group('parseOcrLabel — scénarios complets', () {
    test('étiquette standard (les 4 champs détectés)', () {
      const rawText = '''
Destinataire : Awa Diop
Téléphone : +221 77 123 45 67
Adresse : Rue 10, Mermoz, Dakar
Poids : 2,5 kg
''';
      final r = parseOcrLabel(rawText);
      expect(r.receiverName, 'Awa Diop');
      expect(r.receiverPhone, '+221771234567');
      expect(r.receiverAddress, 'Rue 10, Mermoz, Dakar');
      expect(r.weightKg, 2.5);
      expect(r.hasAnyField, isTrue);
    });

    test('étiquette minimaliste (nom + téléphone seulement)', () {
      const rawText = 'Mamadou Diallo\n77 123 45 67';
      final r = parseOcrLabel(rawText);
      expect(r.receiverName, 'Mamadou Diallo');
      expect(r.receiverPhone, '+221771234567');
      expect(r.receiverAddress, isNull);
      expect(r.weightKg, isNull);
      expect(r.hasAnyField, isTrue);
    });

    test('texte vide ou illisible → résultat vide', () {
      final r = parseOcrLabel('');
      expect(r.hasAnyField, isFalse);
      expect(r.receiverName, isNull);
      expect(r.receiverPhone, isNull);
      expect(r.receiverAddress, isNull);
      expect(r.weightKg, isNull);
    });

    test('OCR bruité (lignes inutiles) : filtre les artefacts', () {
      const rawText = '''
SENDPROCOLIS
Expéditeur
Awa Diop
77 123 45 67
Almadies, villa 42
2 kg
---
''';
      final r = parseOcrLabel(rawText);
      expect(r.receiverPhone, '+221771234567');
      expect(r.weightKg, 2.0);
      // Nom : « Awa Diop » est la première ligne avec 2 mots sans digits
      // et non préfixée par un label d'adresse → OK.
      expect(r.receiverName, 'Awa Diop');
      expect(r.receiverAddress, 'Almadies, villa 42');
    });
  });
}
