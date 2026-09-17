// test/wallet_route_guard_test.dart
//
// Garde de navigation `/wallet` : l'écran portefeuille mobile est réservé au
// chauffeur (endpoint `GET /driver/wallet`). Aucun autre rôle ne doit y accéder
// via la navigation mobile ; l'autorisation réelle reste côté backend.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/user.dart';

User _user(String role) => User.fromJson({
      'id': 'u-1',
      'email': 'u@test.com',
      'phone': '+221771234567',
      'fullName': 'Utilisateur',
      'role': role,
      'createdAt': '2026-01-01T00:00:00.000Z',
    });

void main() {
  group('User.canAccessWallet (garde /wallet)', () {
    test('chauffeur → accès autorisé', () {
      expect(_user('driver').canAccessWallet, true);
    });

    test('chauffeur (alias chauffeur) → accès autorisé', () {
      expect(_user('chauffeur').canAccessWallet, true);
    });

    test('client → accès refusé', () {
      expect(_user('client').canAccessWallet, false);
    });

    test('admin zone → accès refusé', () {
      expect(_user('admin').canAccessWallet, false);
    });

    test('support technique → accès refusé', () {
      expect(_user('support_technique').canAccessWallet, false);
    });

    test('support commercial → accès refusé', () {
      expect(_user('support_commercial').canAccessWallet, false);
    });

    test('support → accès refusé', () {
      expect(_user('support').canAccessWallet, false);
    });

    test('super admin → accès refusé (utilise /admin/wallets)', () {
      expect(_user('super_admin').canAccessWallet, false);
    });
  });
}
