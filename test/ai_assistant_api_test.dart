import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/api/ai_api.dart';

/// Tests du parsing de la réponse `POST /ai/assistant`. Zero network :
/// on injecte directement les Map renvoyées par le backend.
void main() {
  group('AiParcelDraft.fromJson', () {
    test('parse un draft complet create_parcel', () {
      final draft = AiParcelDraft.fromJson({
        'senderCity': 'Dakar',
        'receiverCity': 'Thiès',
        'receiverName': 'Awa Diop',
        'receiverPhone': '+221771234567',
        'weightKg': 5.0,
        'type': 'package',
        'isUrgent': false,
        'notes': null,
      });
      expect(draft, isNotNull);
      expect(draft!.senderCity, 'Dakar');
      expect(draft.weightKg, 5.0);
      expect(draft.type, 'package');
      expect(draft.isUrgent, isFalse);
    });

    test('tolère weightKg en string numérique', () {
      final draft = AiParcelDraft.fromJson({
        'senderCity': 'Dakar',
        'weightKg': '2.5',
      });
      expect(draft!.weightKg, 2.5);
    });

    test('retourne null si payload non-Map', () {
      expect(AiParcelDraft.fromJson(null), isNull);
      expect(AiParcelDraft.fromJson('not a map'), isNull);
    });

    test('tolère les chaînes vides en les convertissant en null', () {
      final draft = AiParcelDraft.fromJson({
        'senderCity': '',
        'receiverName': '',
      });
      expect(draft!.senderCity, isNull);
      expect(draft.receiverName, isNull);
    });
  });

  group('AiAssistantResult.fromResponse', () {
    test('parse un résultat complet de création colis', () {
      final r = AiAssistantResult.fromResponse({
        'success': true,
        'message': 'Reponse assistant',
        'data': {
          'configured': true,
          'result': {
            'intent': 'create_parcel',
            'draft': {
              'senderCity': 'Dakar',
              'receiverCity': 'Thiès',
              'weightKg': 3,
              'type': 'package',
              'isUrgent': false,
            },
            'trackingNumber': null,
            'answerText': 'Je prépare votre colis Dakar → Thiès.',
          },
        },
      });

      expect(r.intent, 'create_parcel');
      expect(r.configured, isTrue);
      expect(r.isCreateParcel, isTrue);
      expect(r.isTrackParcel, isFalse);
      expect(r.draft!.receiverCity, 'Thiès');
      expect(r.answerText, contains('Dakar'));
    });

    test('parse un résultat track_parcel', () {
      final r = AiAssistantResult.fromResponse({
        'success': true,
        'data': {
          'configured': true,
          'result': {
            'intent': 'track_parcel',
            'draft': null,
            'trackingNumber': 'PC-ABC-123',
            'answerText': 'Je récupère votre suivi.',
          },
        },
      });

      expect(r.isTrackParcel, isTrue);
      expect(r.trackingNumber, 'PC-ABC-123');
      expect(r.draft, isNull);
    });

    test('tolère une réponse quasi-vide (fallback backend)', () {
      final r = AiAssistantResult.fromResponse({'success': true});
      expect(r.intent, 'unknown');
      expect(r.answerText, isNotNull);
      expect(r.configured, isFalse);
    });

    test("tolère data sans result", () {
      final r = AiAssistantResult.fromResponse({'data': {'configured': false}});
      expect(r.intent, 'unknown');
      expect(r.configured, isFalse);
    });
  });
}
