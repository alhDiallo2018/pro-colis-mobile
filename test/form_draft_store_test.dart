import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/form_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FormDraftStore', () {
    test('relit ce qui a été écrit', () async {
      final store = FormDraftStore(slot: 'colis', ownerId: 'u1');
      await store.save({'receiverName': 'Awa', 'weight': '3'});

      final draft = await store.load();
      expect(draft, isNotNull);
      expect(draft!.data['receiverName'], 'Awa');
      expect(draft.data['weight'], '3');
    });

    test('renvoie null quand aucun brouillon n’a été écrit', () async {
      final store = FormDraftStore(slot: 'annonce', ownerId: 'u1');
      expect(await store.load(), isNull);
    });

    test('cloisonne les brouillons par compte', () async {
      await FormDraftStore(slot: 'colis', ownerId: 'u1')
          .save({'receiverName': 'Awa'});

      final autre = FormDraftStore(slot: 'colis', ownerId: 'u2');
      expect(await autre.load(), isNull,
          reason: 'un compte ne doit jamais voir la saisie d’un autre');
    });

    test('cloisonne les brouillons par formulaire', () async {
      await FormDraftStore(slot: 'colis', ownerId: 'u1').save({'a': 1});

      final annonce = FormDraftStore(slot: 'annonce', ownerId: 'u1');
      expect(await annonce.load(), isNull);
    });

    test('ignore et purge un brouillon plus vieux que maxAge', () async {
      const key = 'form_draft.colis.u1';
      final perime = DateTime.now()
          .subtract(FormDraftStore.maxAge + const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'savedAt': perime.toIso8601String(),
          'data': {'receiverName': 'Awa'},
        }),
      });

      final store = FormDraftStore(slot: 'colis', ownerId: 'u1');
      expect(await store.load(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull,
          reason: 'un brouillon périmé doit être effacé, pas seulement ignoré');
    });

    test('conserve un brouillon encore dans la fenêtre de validité', () async {
      const key = 'form_draft.colis.u1';
      final recent = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        key: jsonEncode({
          'savedAt': recent.toIso8601String(),
          'data': {'receiverName': 'Awa'},
        }),
      });

      final draft = await FormDraftStore(slot: 'colis', ownerId: 'u1').load();
      expect(draft, isNotNull);
      expect(draft!.data['receiverName'], 'Awa');
    });

    test('écarte et purge un contenu illisible', () async {
      const key = 'form_draft.colis.u1';
      SharedPreferences.setMockInitialValues({key: 'ceci n’est pas du JSON'});

      expect(await FormDraftStore(slot: 'colis', ownerId: 'u1').load(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(key), isNull,
          reason: 'une entrée corrompue bloquerait sinon toutes les lectures '
              'suivantes de ce formulaire');
    });

    test('clear supprime le brouillon', () async {
      final store = FormDraftStore(slot: 'colis', ownerId: 'u1');
      await store.save({'receiverName': 'Awa'});
      await store.clear();

      expect(await store.load(), isNull);
    });

    test('clearAll efface les brouillons de tous les comptes', () async {
      await FormDraftStore(slot: 'colis', ownerId: 'u1').save({'a': 1});
      await FormDraftStore(slot: 'annonce', ownerId: 'u2').save({'b': 2});

      await FormDraftStore.clearAll();

      expect(await FormDraftStore(slot: 'colis', ownerId: 'u1').load(), isNull);
      expect(
          await FormDraftStore(slot: 'annonce', ownerId: 'u2').load(), isNull);
    });

    test('clearAll épargne les autres préférences', () async {
      SharedPreferences.setMockInitialValues({'theme': 'dark'});
      await FormDraftStore(slot: 'colis', ownerId: 'u1').save({'a': 1});

      await FormDraftStore.clearAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme'), 'dark');
    });

    test('une session sans compte retombe sur un espace anonyme dédié',
        () async {
      await FormDraftStore(slot: 'colis').save({'receiverName': 'Awa'});

      expect(await FormDraftStore(slot: 'colis').load(), isNotNull);
      expect(await FormDraftStore(slot: 'colis', ownerId: 'u1').load(), isNull);
    });
  });
}
