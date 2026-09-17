// test/cancellation_routing_test.dart
//
// Vérifie le routage des endpoints d'annulation par rôle. Le mobile ne doit
// jamais mélanger les acteurs : chaque rôle possède son propre endpoint, et le
// backend reste la seule source de vérité (aucune règle financière n'est
// re-testée ici, uniquement la séparation des chemins).

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/api_service.dart';

void main() {
  group('routage des endpoints d’annulation par rôle', () {
    test('client → /client/parcels/:id/cancel', () {
      expect(ApiService.clientCancelPath('p-1'), '/client/parcels/p-1/cancel');
    });

    test('chauffeur (mission assignée) → /driver/parcels/:id/cancel', () {
      expect(ApiService.driverCancelPath('p-1'), '/driver/parcels/p-1/cancel');
    });

    test('admin zone (statut) → /garage-admin/parcels/:id/status', () {
      expect(
        ApiService.garageAdminParcelStatusPath('p-1'),
        '/garage-admin/parcels/p-1/status',
      );
    });

    test('super admin → /super-admin/parcels/:id (inchangé)', () {
      expect(ApiService.superAdminParcelPath('p-1'), '/super-admin/parcels/p-1');
    });

    test('les quatre chemins sont distincts (isolation des rôles)', () {
      final paths = <String>{
        ApiService.clientCancelPath('p-1'),
        ApiService.driverCancelPath('p-1'),
        ApiService.garageAdminParcelStatusPath('p-1'),
        ApiService.superAdminParcelPath('p-1'),
      };
      expect(paths, hasLength(4));
    });

    test('cancelParcel ne devient jamais l’endpoint chauffeur', () {
      expect(
        ApiService.clientCancelPath('p-1'),
        isNot(ApiService.driverCancelPath('p-1')),
      );
    });
  });
}
