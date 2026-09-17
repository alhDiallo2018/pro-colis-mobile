// test/cancellation_reasons_test.dart
//
// Alignement F5 (annulation) : le mobile récupère les motifs d'annulation
// dynamiquement depuis l'API (devis client ou configuration publique) et
// n'entretient aucune liste métier indépendante. Aucune règle financière n'est
// re-testée ici : uniquement le routage et la lecture fidèle des motifs.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/cancellation.dart';
import 'package:procolis/models/public_config.dart';
import 'package:procolis/services/api_service.dart';

void main() {
  group('routage du devis d’annulation client', () {
    test('client → /client/parcels/:id/cancel/quote', () {
      expect(
        ApiService.clientCancelQuotePath('p-1'),
        '/client/parcels/p-1/cancel/quote',
      );
    });

    test('le devis est distinct de l’annulation effective', () {
      expect(
        ApiService.clientCancelQuotePath('p-1'),
        isNot(ApiService.clientCancelPath('p-1')),
      );
    });
  });

  group('motifs d’annulation depuis la configuration publique', () {
    test('parse cancellation.reasons (value/label uniquement)', () {
      final config = PublicConfig.fromJson({
        'cancellation': {
          'reasons': [
            {'value': 'client_change_of_mind', 'label': 'Changement d’avis'},
            {'value': 'client_unreachable', 'label': 'Client injoignable'},
            {'value': 'mutual_agreement', 'label': 'Accord mutuel'},
          ],
        },
      });

      expect(config.cancellationReasons, hasLength(3));
      expect(config.cancellationReasons.first.value, 'client_change_of_mind');
      expect(config.cancellationReasons.first.label, 'Changement d’avis');
    });

    test('filtre les motifs sans value (entrées invalides)', () {
      final config = PublicConfig.fromJson({
        'cancellation': {
          'reasons': [
            {'value': 'driver_no_show', 'label': 'Chauffeur absent'},
            {'value': '', 'label': 'vide'},
            {'label': 'sans value'},
          ],
        },
      });

      expect(config.cancellationReasons, hasLength(1));
      expect(config.cancellationReasons.single.value, 'driver_no_show');
    });

    test('absence de cancellation.reasons → liste vide (pas de crash)', () {
      final config = PublicConfig.fromJson({});
      expect(config.cancellationReasons, isEmpty);
    });
  });

  group('le mobile n’invente aucune règle financière', () {
    test('les motifs ne portent aucun pourcentage ni responsabilité', () {
      final reason = CancellationReason.fromJson({
        'value': 'driver_abandonment',
        'label': 'Abandon de mission',
        // Même si le backend fournissait des champs supplémentaires, le mobile
        // n'expose que value/label et ignore le reste.
        'exempt': true,
        'responsibility': 'driver',
        'penaltyPercent': 10,
      });

      expect(reason.value, 'driver_abandonment');
      expect(reason.label, 'Abandon de mission');
      // Aucun accès à une quelconque règle financière via ce modèle.
      expect(reason.isValid, true);
    });
  });
}
