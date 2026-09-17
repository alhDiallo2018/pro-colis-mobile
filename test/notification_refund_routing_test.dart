// test/notification_refund_routing_test.dart
//
// Vérifie qu'une notification de remboursement (`refund`/`remboursement`) n'est
// jamais routée vers l'écran wallet chauffeur : elle doit ouvrir le colis
// concerné (si `parcelId`) ou l'écran des notifications.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/notification_navigation.dart';

void main() {
  group('NotificationNavigation.routeFor — remboursements', () {
    test('refund avec parcelId → détail du colis', () {
      final route = NotificationNavigation.routeFor('refund', 'p123', null);
      expect(route, '/parcel/p123');
    });

    test('remboursement avec parcelId → détail du colis', () {
      final route =
          NotificationNavigation.routeFor('remboursement', 'p456', null);
      expect(route, '/parcel/p456');
    });

    test('refund sans parcelId → notifications (PAS /wallet)', () {
      final route = NotificationNavigation.routeFor('refund', null, null);
      expect(route, '/notifications');
    });

    test('refund_initiated sans parcelId → notifications (PAS /wallet)', () {
      final route =
          NotificationNavigation.routeFor('refund_initiated', null, null);
      expect(route, '/notifications');
    });

    test('remboursement_echoue sans parcelId → notifications (PAS /wallet)', () {
      final route =
          NotificationNavigation.routeFor('remboursement_echoue', null, null);
      expect(route, '/notifications');
    });
  });

  group('NotificationNavigation.routeFor — autres types financiers', () {
    test('wallet → /wallet', () {
      expect(NotificationNavigation.routeFor('wallet', null, null), '/wallet');
    });

    test('deposit → /wallet', () {
      expect(NotificationNavigation.routeFor('deposit', null, null), '/wallet');
    });

    test('withdrawal → /wallet', () {
      expect(
        NotificationNavigation.routeFor('withdrawal', null, null),
        '/wallet',
      );
    });

    test('message → /messages', () {
      expect(NotificationNavigation.routeFor('message', null, null), '/messages');
    });

    test('type inconnu → null (repli notifications)', () {
      expect(NotificationNavigation.routeFor('unknown', null, null), isNull);
    });
  });
}
