import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/parcel.dart';

/// Parsing de `ParcelEta` depuis le payload du backend. Doit rester **tolérant** :
/// aucune exception ne doit remonter jusqu'à l'affichage tracking.
void main() {
  group('ParcelEta.fromJson', () {
    test('parse un payload complet (confidence high, moving)', () {
      final eta = ParcelEta.fromJson({
        'etaMinutes': 15,
        'arrivalAt': '2026-11-11T13:45:00.000Z',
        'minMinutes': 12,
        'maxMinutes': 18,
        'distanceRemainingKm': 7.3,
        'confidence': 'high',
        'movingState': 'moving',
        'computedAt': '2026-11-11T13:30:00.000Z',
      });

      expect(eta, isNotNull);
      expect(eta!.etaMinutes, 15);
      expect(eta.minMinutes, 12);
      expect(eta.maxMinutes, 18);
      expect(eta.distanceRemainingKm, 7.3);
      expect(eta.confidence, EtaConfidence.high);
      expect(eta.movingState, EtaMovingState.moving);
      expect(eta.arrivalAt.isAfter(eta.computedAt), isTrue);
    });

    test('parse un payload chauffeur à l\'arrêt (confidence medium)', () {
      final eta = ParcelEta.fromJson({
        'etaMinutes': 24,
        'arrivalAt': '2026-11-11T13:54:00.000Z',
        'minMinutes': 15,
        'maxMinutes': 32,
        'distanceRemainingKm': 6.0,
        'confidence': 'medium',
        'movingState': 'stopped',
        'computedAt': '2026-11-11T13:30:00.000Z',
      });

      expect(eta, isNotNull);
      expect(eta!.movingState, EtaMovingState.stopped);
      expect(eta.confidence, EtaConfidence.medium);
    });

    test('parse un payload low confidence avec moving unknown', () {
      final eta = ParcelEta.fromJson({
        'etaMinutes': 20,
        'arrivalAt': '2026-11-11T13:50:00.000Z',
        'minMinutes': 10,
        'maxMinutes': 30,
        'distanceRemainingKm': 8.0,
        'confidence': 'low',
        'movingState': 'unknown',
        'computedAt': '2026-11-11T13:30:00.000Z',
      });

      expect(eta, isNotNull);
      expect(eta!.confidence, EtaConfidence.low);
      expect(eta.movingState, EtaMovingState.unknown);
    });

    test('retourne null sur payload null', () {
      expect(ParcelEta.fromJson(null), isNull);
    });

    test('retourne null sur payload non-Map', () {
      expect(ParcelEta.fromJson('not a map'), isNull);
      expect(ParcelEta.fromJson(42), isNull);
      expect(ParcelEta.fromJson([1, 2, 3]), isNull);
    });

    test('retourne null si champ obligatoire manquant', () {
      final eta = ParcelEta.fromJson({
        // arrivalAt absent
        'etaMinutes': 10,
        'minMinutes': 8,
        'maxMinutes': 12,
        'distanceRemainingKm': 5.0,
        'confidence': 'medium',
        'movingState': 'moving',
        'computedAt': '2026-11-11T13:30:00.000Z',
      });
      expect(eta, isNull);
    });

    test('tolère etaMinutes en string numérique', () {
      final eta = ParcelEta.fromJson({
        'etaMinutes': '15',
        'arrivalAt': '2026-11-11T13:45:00.000Z',
        'minMinutes': '12',
        'maxMinutes': '18',
        'distanceRemainingKm': '7.3',
        'confidence': 'high',
        'movingState': 'moving',
        'computedAt': '2026-11-11T13:30:00.000Z',
      });

      expect(eta, isNotNull);
      expect(eta!.etaMinutes, 15);
      expect(eta.distanceRemainingKm, 7.3);
    });

    test('tombe sur medium/unknown pour valeurs enum inconnues', () {
      final eta = ParcelEta.fromJson({
        'etaMinutes': 10,
        'arrivalAt': '2026-11-11T13:45:00.000Z',
        'minMinutes': 8,
        'maxMinutes': 12,
        'distanceRemainingKm': 5.0,
        'confidence': 'cosmic', // inconnu
        'movingState': 'teleporting', // inconnu
        'computedAt': '2026-11-11T13:30:00.000Z',
      });
      expect(eta, isNotNull);
      expect(eta!.confidence, EtaConfidence.medium);
      expect(eta.movingState, EtaMovingState.unknown);
    });

    test('round-trip toJson/fromJson préserve les valeurs', () {
      final original = ParcelEta(
        etaMinutes: 20,
        arrivalAt: DateTime.utc(2026, 11, 11, 13, 50),
        minMinutes: 16,
        maxMinutes: 24,
        distanceRemainingKm: 9.8,
        confidence: EtaConfidence.high,
        movingState: EtaMovingState.moving,
        computedAt: DateTime.utc(2026, 11, 11, 13, 30),
      );

      final roundTripped = ParcelEta.fromJson(original.toJson());
      expect(roundTripped, isNotNull);
      expect(roundTripped!.etaMinutes, 20);
      expect(roundTripped.minMinutes, 16);
      expect(roundTripped.maxMinutes, 24);
      expect(roundTripped.distanceRemainingKm, 9.8);
      expect(roundTripped.confidence, EtaConfidence.high);
      expect(roundTripped.movingState, EtaMovingState.moving);
      expect(roundTripped.arrivalAt.toUtc(), original.arrivalAt);
      expect(roundTripped.computedAt.toUtc(), original.computedAt);
    });
  });

  group('ParcelEta.remainingMinutesFrom', () {
    test('retourne les minutes restantes pour une arrivée future', () {
      final eta = ParcelEta(
        etaMinutes: 20,
        arrivalAt: DateTime.utc(2026, 11, 11, 13, 50),
        minMinutes: 16,
        maxMinutes: 24,
        distanceRemainingKm: 9.8,
        confidence: EtaConfidence.high,
        movingState: EtaMovingState.moving,
        computedAt: DateTime.utc(2026, 11, 11, 13, 30),
      );
      final now = DateTime.utc(2026, 11, 11, 13, 35);
      expect(eta.remainingMinutesFrom(now), 15);
    });

    test('clamp à 0 quand l\'arrivée est passée', () {
      final eta = ParcelEta(
        etaMinutes: 10,
        arrivalAt: DateTime.utc(2026, 11, 11, 13, 30),
        minMinutes: 8,
        maxMinutes: 12,
        distanceRemainingKm: 5.0,
        confidence: EtaConfidence.medium,
        movingState: EtaMovingState.moving,
        computedAt: DateTime.utc(2026, 11, 11, 13, 20),
      );
      final now = DateTime.utc(2026, 11, 11, 13, 45);
      expect(eta.remainingMinutesFrom(now), 0);
    });
  });

  group('ParcelAnomaly.fromJson', () {
    test('parse un payload gps_silence warning', () {
      final a = ParcelAnomaly.fromJson({
        'type': 'gps_silence',
        'severity': 'warning',
        'detectedAt': '2026-11-11T13:30:00.000Z',
        'details': {'silenceMinutes': 22},
      });
      expect(a, isNotNull);
      expect(a!.type, 'gps_silence');
      expect(a.severity, AnomalySeverity.warning);
      expect(a.label, 'Position perdue');
      expect(a.details['silenceMinutes'], 22);
    });

    test('parse un payload prolonged_stop critical', () {
      final a = ParcelAnomaly.fromJson({
        'type': 'prolonged_stop',
        'severity': 'critical',
        'detectedAt': '2026-11-11T13:30:00.000Z',
        'details': {'stoppedSinceMinutes': 45},
      });
      expect(a!.severity, AnomalySeverity.critical);
      expect(a.label, 'Arrêt prolongé');
    });

    test('tombe sur warning pour severity inconnue', () {
      final a = ParcelAnomaly.fromJson({
        'type': 'route_deviation',
        'severity': 'cosmic',
        'detectedAt': '2026-11-11T13:30:00.000Z',
      });
      expect(a!.severity, AnomalySeverity.warning);
    });

    test('retourne null si type absent', () {
      final a = ParcelAnomaly.fromJson({
        'severity': 'warning',
        'detectedAt': '2026-11-11T13:30:00.000Z',
      });
      expect(a, isNull);
    });

    test('ParcelAnomaly.listFromJson filtre les entrées invalides', () {
      final list = ParcelAnomaly.listFromJson([
        {
          'type': 'gps_silence',
          'detectedAt': '2026-11-11T13:30:00.000Z',
        },
        null,
        'invalid',
        {'severity': 'critical'}, // sans type
      ]);
      expect(list.length, 1);
      expect(list.first.type, 'gps_silence');
    });

    test('listFromJson retourne [] pour un non-List', () {
      expect(ParcelAnomaly.listFromJson(null), isEmpty);
      expect(ParcelAnomaly.listFromJson('not a list'), isEmpty);
    });
  });

  group('Parcel.fromJson anomalies integration', () {
    test('Parcel.fromJson lit anomalies array', () {
      final json = {
        'id': 'parcel-1',
        'trackingNumber': 'PC-XYZ',
        'senderName': 'Expéditeur',
        'senderPhone': '+221770000001',
        'receiverName': 'Destinataire',
        'receiverPhone': '+221770000002',
        'description': 'Test',
        'weight': 2.5,
        'type': 'package',
        'status': 'in_transit',
        'departureZoneId': 'z1',
        'departureZoneName': 'Dakar',
        'createdAt': '2026-11-11T12:00:00.000Z',
        'anomalies': [
          {
            'type': 'gps_silence',
            'severity': 'warning',
            'detectedAt': '2026-11-11T13:30:00.000Z',
          },
          {
            'type': 'prolonged_stop',
            'severity': 'critical',
            'detectedAt': '2026-11-11T13:35:00.000Z',
          },
        ],
      };
      final parcel = Parcel.fromJson(json);
      expect(parcel.anomalies.length, 2);
      expect(parcel.anomalies[1].severity, AnomalySeverity.critical);
    });

    test('Parcel.fromJson accepte l\'absence de anomalies', () {
      final json = {
        'id': 'parcel-1',
        'trackingNumber': 'PC-XYZ',
        'senderName': 'Expéditeur',
        'senderPhone': '+221770000001',
        'receiverName': 'Destinataire',
        'receiverPhone': '+221770000002',
        'description': 'Test',
        'weight': 2.5,
        'type': 'package',
        'status': 'pending',
        'departureZoneId': 'z1',
        'departureZoneName': 'Dakar',
        'createdAt': '2026-11-11T12:00:00.000Z',
      };
      final parcel = Parcel.fromJson(json);
      expect(parcel.anomalies, isEmpty);
    });
  });

  group('Parcel.fromJson eta integration', () {
    test('Parcel.fromJson lit eta à la racine du parcel JSON', () {
      final json = {
        'id': 'parcel-1',
        'trackingNumber': 'PC-XYZ',
        'senderName': 'Expéditeur',
        'senderPhone': '+221770000001',
        'receiverName': 'Destinataire',
        'receiverPhone': '+221770000002',
        'description': 'Test',
        'weight': 2.5,
        'type': 'package',
        'status': 'in_transit',
        'departureZoneId': 'z1',
        'departureZoneName': 'Dakar',
        'createdAt': '2026-11-11T12:00:00.000Z',
        'eta': {
          'etaMinutes': 15,
          'arrivalAt': '2026-11-11T13:45:00.000Z',
          'minMinutes': 12,
          'maxMinutes': 18,
          'distanceRemainingKm': 7.3,
          'confidence': 'high',
          'movingState': 'moving',
          'computedAt': '2026-11-11T13:30:00.000Z',
        },
      };

      final parcel = Parcel.fromJson(json);
      expect(parcel.eta, isNotNull);
      expect(parcel.eta!.etaMinutes, 15);
      expect(parcel.eta!.confidence, EtaConfidence.high);
    });

    test('Parcel.fromJson accepte l\'absence de eta (fallback statique)', () {
      final json = {
        'id': 'parcel-1',
        'trackingNumber': 'PC-XYZ',
        'senderName': 'Expéditeur',
        'senderPhone': '+221770000001',
        'receiverName': 'Destinataire',
        'receiverPhone': '+221770000002',
        'description': 'Test',
        'weight': 2.5,
        'type': 'package',
        'status': 'pending',
        'departureZoneId': 'z1',
        'departureZoneName': 'Dakar',
        'createdAt': '2026-11-11T12:00:00.000Z',
        // eta absent
      };

      final parcel = Parcel.fromJson(json);
      expect(parcel.eta, isNull);
    });

    test('Parcel.fromJson accepte eta: null explicite', () {
      final json = {
        'id': 'parcel-1',
        'trackingNumber': 'PC-XYZ',
        'senderName': 'Expéditeur',
        'senderPhone': '+221770000001',
        'receiverName': 'Destinataire',
        'receiverPhone': '+221770000002',
        'description': 'Test',
        'weight': 2.5,
        'type': 'package',
        'status': 'delivered',
        'departureZoneId': 'z1',
        'departureZoneName': 'Dakar',
        'createdAt': '2026-11-11T12:00:00.000Z',
        'eta': null,
      };

      final parcel = Parcel.fromJson(json);
      expect(parcel.eta, isNull);
    });
  });
}
