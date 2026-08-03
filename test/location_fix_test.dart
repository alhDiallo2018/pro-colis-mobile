// Chaque échec de localisation doit produire un message distinct : c'est ce qui
// manquait quand l'app affichait l'exception brute — ou pire, restait bloquée
// sans rien dire.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/location_fix.dart';

void main() {
  group('LocationFailure', () {
    test('chaque cas porte un message non vide et distinct', () {
      final messages = <String>{};
      for (final kind in LocationFailureKind.values) {
        final failure = LocationFailure(kind, _messageFor(kind));
        expect(failure.message, isNotEmpty);
        messages.add(failure.message);
      }
      expect(messages.length, LocationFailureKind.values.length,
          reason: 'deux causes différentes ne doivent pas dire la même chose');
    });

    test('seul un refus définitif renvoie vers les réglages', () {
      for (final kind in LocationFailureKind.values) {
        final failure = LocationFailure(kind, 'peu importe');
        expect(
          failure.needsSettings,
          kind == LocationFailureKind.permissionDeniedForever,
          reason: 'needsSettings incorrect pour $kind',
        );
      }
    });

    test('toString reste diagnostiquable sans exposer le message seul', () {
      const failure =
          LocationFailure(LocationFailureKind.timeout, 'Position introuvable.');
      expect(failure.toString(), contains('timeout'));
      expect(failure.toString(), contains('Position introuvable.'));
    });
  });

  group('locationErrorMessage', () {
    test('reprend le message d’un LocationFailure', () {
      const failure = LocationFailure(
        LocationFailureKind.serviceDisabled,
        'Localisation désactivée.',
      );
      expect(locationErrorMessage(failure), 'Localisation désactivée.');
    });

    test('n’expose jamais une exception brute à l’utilisateur', () {
      final brute = Exception('PlatformException(kCLErrorDomain, 1, null)');
      final message = locationErrorMessage(brute);

      expect(message, 'Position indisponible pour le moment.');
      expect(message, isNot(contains('PlatformException')));
      expect(message, isNot(contains('kCLErrorDomain')));
    });

    test('couvre aussi les erreurs qui ne sont pas des Exception', () {
      expect(locationErrorMessage('boom'), isNotEmpty);
      expect(locationErrorMessage(StateError('bad')), isNotEmpty);
    });
  });

  group('délai maximum', () {
    test('est borné : sans lui la future ne se résout jamais', () {
      expect(kLocationTimeLimit, isNotNull);
      expect(kLocationTimeLimit.inSeconds, greaterThan(0));
      expect(kLocationTimeLimit.inSeconds, lessThanOrEqualTo(30),
          reason: 'un délai trop long fige l’interface aussi sûrement que '
              'l’absence de délai');
    });
  });
}

String _messageFor(LocationFailureKind kind) => switch (kind) {
      LocationFailureKind.serviceDisabled => 'Localisation désactivée.',
      LocationFailureKind.permissionDenied => 'Accès refusé.',
      LocationFailureKind.permissionDeniedForever => 'Refusé durablement.',
      LocationFailureKind.timeout => 'Position introuvable.',
      LocationFailureKind.unknown => 'Position indisponible.',
    };
