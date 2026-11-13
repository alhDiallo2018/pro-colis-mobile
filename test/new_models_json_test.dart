// Tests de sérialisation JSON des modèles introduits dans cette itération.
// Ces modèles sont toujours tolérants : un champ manquant doit donner une
// valeur par défaut raisonnable, jamais une exception.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/api/business_shipper_api.dart';
import 'package:procolis/services/api/disputes_api.dart';
import 'package:procolis/services/api/referral_api.dart';
import 'package:procolis/services/api/shipment_batch_api.dart';
import 'package:procolis/services/api/support_api.dart';

void main() {
  group('BusinessShipperInvoice.fromJson', () {
    test('parse un payload complet', () {
      final invoice = BusinessShipperInvoice.fromJson({
        'id': 'inv-1',
        'number': 'INV-0001',
        'issuedAt': '2026-01-15T00:00:00Z',
        'amount': 150000,
        'currency': 'XOF',
        'status': 'paid',
        'pdfUrl': '/invoices/inv-1.pdf',
      });
      expect(invoice.id, 'inv-1');
      expect(invoice.number, 'INV-0001');
      expect(invoice.amount, 150000);
      expect(invoice.currency, 'XOF');
      expect(invoice.status, 'paid');
      expect(invoice.pdfUrl, '/invoices/inv-1.pdf');
      expect(invoice.issuedAt, isNotNull);
    });

    test('tombe sur des valeurs par défaut quand les champs manquent', () {
      final invoice = BusinessShipperInvoice.fromJson({});
      expect(invoice.id, '');
      expect(invoice.amount, 0);
      expect(invoice.status, 'pending');
      expect(invoice.issuedAt, isNull);
      expect(invoice.pdfUrl, isNull);
    });
  });

  group('ShipmentBatchStopEvent.fromJson', () {
    test('mappe les champs normaux', () {
      final event = ShipmentBatchStopEvent.fromJson({
        'id': 'evt-1',
        'type': 'arrival',
        'label': 'Arrivée Thiès',
        'description': 'Chauffeur arrivé',
        'occurredAt': '2026-01-15T10:00:00Z',
        'parcelId': 'p-1',
        'stopLabel': 'Thiès centre',
      });
      expect(event.id, 'evt-1');
      expect(event.type, 'arrival');
      expect(event.label, 'Arrivée Thiès');
      expect(event.stopLabel, 'Thiès centre');
      expect(event.occurredAt, isNotNull);
    });

    test('utilise `event` comme type par défaut', () {
      final event = ShipmentBatchStopEvent.fromJson({'id': 'x'});
      expect(event.type, 'event');
    });
  });

  group('ReferralRewards.fromJson', () {
    test('parse tous les champs', () {
      final rewards = ReferralRewards.fromJson({
        'totalInvites': 10,
        'confirmedInvites': 7,
        'bonusEarned': 7000,
        'bonusAvailable': 5000,
        'currency': 'XOF',
      });
      expect(rewards.totalInvites, 10);
      expect(rewards.confirmedInvites, 7);
      expect(rewards.bonusEarned, 7000);
      expect(rewards.bonusAvailable, 5000);
      expect(rewards.currency, 'XOF');
    });

    test('tombe sur 0 pour les compteurs manquants', () {
      final rewards = ReferralRewards.fromJson({});
      expect(rewards.totalInvites, 0);
      expect(rewards.bonusEarned, 0);
      expect(rewards.currency, isNull);
    });
  });

  group('SupportSlaOverview.fromJson', () {
    test('parse les compteurs de SLA', () {
      final sla = SupportSlaOverview.fromJson({
        'technicalAtRisk': 3,
        'technicalBreached': 1,
        'commercialDelayed': 2,
        'chatExceeded': 0,
        'chatAvgFirstResponseMinutes': 4.2,
        'technicalAvgResolutionHours': 12.5,
      });
      expect(sla.technicalAtRisk, 3);
      expect(sla.technicalBreached, 1);
      expect(sla.commercialDelayed, 2);
      expect(sla.chatExceeded, 0);
      expect(sla.chatAvgFirstResponseMinutes, 4.2);
      expect(sla.technicalAvgResolutionHours, 12.5);
    });

    test('tolère un payload vide', () {
      final sla = SupportSlaOverview.fromJson({});
      expect(sla.technicalAtRisk, 0);
      expect(sla.chatAvgFirstResponseMinutes, isNull);
    });
  });

  group('Dispute.fromJson', () {
    test('détecte les statuts ouverts/résolus/rejetés', () {
      final open = Dispute.fromJson({
        'id': 'd-1',
        'parcelId': 'p-1',
        'status': 'open',
        'category': 'damage',
        'description': 'Colis endommagé',
      });
      expect(open.isOpen, true);
      expect(open.isResolved, false);
      expect(open.isRejected, false);

      final inReview = Dispute.fromJson({
        'id': 'd-2',
        'parcelId': 'p-1',
        'status': 'in_review',
        'category': 'damage',
        'description': '...',
      });
      expect(inReview.isOpen, true);

      final resolved = Dispute.fromJson({
        'id': 'd-3',
        'parcelId': 'p-1',
        'status': 'resolved',
        'category': 'damage',
        'description': '...',
        'resolutionNote': 'Remboursé 15000 XOF',
      });
      expect(resolved.isOpen, false);
      expect(resolved.isResolved, true);
      expect(resolved.resolutionNote, 'Remboursé 15000 XOF');

      final rejected = Dispute.fromJson({
        'id': 'd-4',
        'parcelId': 'p-1',
        'status': 'rejected',
        'category': 'other',
        'description': '...',
      });
      expect(rejected.isRejected, true);
    });

    test('parse les événements et les pièces jointes', () {
      final dispute = Dispute.fromJson({
        'id': 'd-5',
        'parcelId': 'p-1',
        'status': 'open',
        'category': 'lost',
        'description': 'Colis perdu',
        'attachments': ['/uploads/photo1.jpg', '/uploads/photo2.jpg'],
        'events': [
          {
            'id': 'e-1',
            'type': 'created',
            'actorName': 'Awa',
            'occurredAt': '2026-01-15T09:00:00Z',
          },
          {
            'id': 'e-2',
            'type': 'comment',
            'actorName': 'Support',
            'message': 'Enquête en cours',
          },
        ],
      });
      expect(dispute.attachments.length, 2);
      expect(dispute.events.length, 2);
      expect(dispute.events.first.type, 'created');
      expect(dispute.events.last.message, 'Enquête en cours');
    });

    test('tolère un claimedAmount absent', () {
      final dispute = Dispute.fromJson({
        'id': 'd-6',
        'parcelId': 'p-1',
        'status': 'open',
        'category': 'delay',
        'description': 'Retard important',
      });
      expect(dispute.claimedAmount, isNull);
    });
  });
}
