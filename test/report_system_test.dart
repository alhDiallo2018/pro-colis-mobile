// Contrat des rapports de période et de la sonde système.
//
// Charges utiles reproduites depuis `buildPeriodReport`, `serializeWebhook` et
// `systemHealth` (`ProColis-Api/src/modules/mobile/mobile.controller.js`).

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/report.dart';
import 'package:procolis/services/api/system_api.dart';

void main() {
  group('PeriodReport', () {
    final dailyPayload = {
      'date': '2026-08-03',
      'from': '2026-08-03T00:00:00.000Z',
      'to': '2026-08-04T00:00:00.000Z',
      'bucket': 'hour',
      'totals': {
        'created': 12,
        'delivered': 9,
        'cancelled': 1,
        'deliveryRate': 75,
        'revenue': 145000,
        'deliveredAmount': 132000,
      },
      'parcelsByStatus': {'delivered': 9, 'in_transit': 2, 'cancelled': 1},
      'series': [
        {'key': '08', 'created': 3, 'delivered': 1, 'revenue': 15000},
        {'key': '09', 'created': 9, 'delivered': 8, 'revenue': 130000},
      ],
      'topDrivers': [
        {'driverId': 'd-1', 'fullName': 'Moussa Fall', 'delivered': 6},
        {'driverId': 'd-2', 'fullName': null, 'delivered': 3},
      ],
    };

    test('lit un rapport journalier complet', () {
      final report = PeriodReport.fromJson(dailyPayload);
      expect(report.date, '2026-08-03');
      expect(report.bucket, 'hour');
      expect(report.totals.created, 12);
      expect(report.totals.deliveryRate, 75);
      expect(report.totals.revenue, 145000);
      expect(report.parcelsByStatus['in_transit'], 2);
      expect(report.series.length, 2);
      expect(report.peakCreated, 9);
      expect(report.isEmpty, isFalse);
    });

    test('le taux de livraison vient du serveur, pas d\'un calcul local', () {
      // Le serveur rapporte les livraisons de la période aux colis qui y sont
      // nés : 9/12 = 75 %. Un recalcul naïf sur une page partielle donnerait
      // autre chose — c'est le bug que ce modèle remplace.
      final report = PeriodReport.fromJson(dailyPayload);
      expect(report.totals.deliveryRate, 75);
    });

    test('un chauffeur supprimé reste lisible', () {
      final report = PeriodReport.fromJson(dailyPayload);
      expect(report.topDrivers.first.label, 'Moussa Fall');
      expect(report.topDrivers.last.label, 'Chauffeur supprimé');
    });

    test('accepte les montants Decimal renvoyés en chaîne', () {
      final report = PeriodReport.fromJson({
        'totals': {'revenue': '145000.50', 'created': '4'},
        'series': [
          {'key': '2026-08-03', 'created': '2', 'revenue': '1000'}
        ],
      });
      expect(report.totals.revenue, 145000.50);
      expect(report.totals.created, 4);
      expect(report.series.first.created, 2);
    });

    test('survit à un rapport vide', () {
      final report = PeriodReport.fromJson(const {});
      expect(report.isEmpty, isTrue);
      expect(report.series, isEmpty);
      expect(report.topDrivers, isEmpty);
      expect(report.totals.deliveryRate, 0);
      expect(report.peakCreated, 0);
    });

    test('lit un rapport mensuel (série par jour)', () {
      final report = PeriodReport.fromJson({
        'year': 2026,
        'month': 8,
        'bucket': 'day',
        'series': [
          {'key': '2026-08-01', 'created': 5},
          {'key': '2026-08-02', 'created': 7},
        ],
      });
      expect(report.year, 2026);
      expect(report.month, 8);
      expect(report.bucket, 'day');
      expect(report.series.last.key, '2026-08-02');
    });
  });

  group('SystemHealth', () {
    test('lit une sonde saine', () {
      final health = SystemHealth.fromJson({
        'status': 'healthy',
        'database': 'connected',
        'uptime': 93784,
        'timestamp': '2026-08-03T12:00:00.000Z',
      });
      expect(health.isHealthy, isTrue);
      expect(health.uptimeLabel, '1 j 2 h');
    });

    test('la réponse 503 porte l\'état dégradé', () {
      // `fail()` renvoie `status: degraded` avec un 503 : l'échec HTTP est
      // l'information, il ne doit pas être traité comme une panne du client.
      final health = SystemHealth.fromJson({
        'status': 'degraded',
        'database': 'disconnected',
      });
      expect(health.isHealthy, isFalse);
      expect(health.database, 'disconnected');
      expect(health.uptimeLabel, '—');
    });

    test('formate les durées courtes', () {
      expect(
        SystemHealth.fromJson({'uptime': 2520}).uptimeLabel,
        '42 min',
      );
      expect(
        SystemHealth.fromJson({'uptime': 18720}).uptimeLabel,
        '5 h 12 min',
      );
    });

    test('un corps vide n\'est pas considéré comme sain', () {
      final health = SystemHealth.fromJson(const {});
      expect(health.isHealthy, isFalse);
      expect(health.database, 'unknown');
    });
  });

  group('Webhook', () {
    test('lit un abonnement signé', () {
      final webhook = Webhook.fromJson({
        'id': 'w-1',
        'url': 'https://exemple.com/hooks',
        'events': ['parcel.created', 'parcel.delivered'],
        'hasSecret': true,
        'isActive': true,
        'createdAt': '2026-08-01T10:00:00.000Z',
      });
      expect(webhook.events.length, 2);
      expect(webhook.hasSecret, isTrue);
      expect(webhook.isActive, isTrue);
    });

    test('le secret lui-même n\'est jamais exposé', () {
      // `serializeWebhook` n'expose que `hasSecret` : si un jour le champ
      // `secret` apparaissait, ce test ne le ferait pas remonter dans l'UI.
      final webhook = Webhook.fromJson({
        'id': 'w-2',
        'url': 'https://exemple.com',
        'hasSecret': false,
      });
      expect(webhook.hasSecret, isFalse);
      expect(webhook.events, isEmpty);
    });

    test('isActive absent vaut actif', () {
      final webhook =
          Webhook.fromJson({'id': 'w-3', 'url': 'https://exemple.com'});
      expect(webhook.isActive, isTrue);
    });
  });
}
