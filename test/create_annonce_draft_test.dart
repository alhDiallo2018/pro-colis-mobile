// Parcours brouillon du formulaire « Créer une annonce » : ce qui doit rester
// vrai, c'est qu'une saisie non publiée ne disparaît pas quand on ferme.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/screens/driver/create_annonce_sheet.dart';
import 'package:procolis/services/form_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ouvre la feuille de création d'annonce dans un décor minimal.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCreateAnnonceSheet(context),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

/// Amène le formulaire à l'étape 2, seule étape où des champs texte sont
/// rendus : sans garages (l'API n'est pas jointe en test), l'étape 1 n'affiche
/// aucun `TextField`. Passer par la reprise d'un brouillon donne à la fois le
/// contenu et la bonne étape.
Future<void> _openSheetWithContent(WidgetTester tester,
    {String description = 'départ confirmé'}) async {
  await FormDraftStore(slot: 'annonce').save({
    'step': 1,
    'description': description,
    'weight': '40',
    'price': '9000',
  });
  await _openSheet(tester);
  await tester.tap(find.text('Reprendre'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('fermer une saisie renseignée propose de garder le brouillon',
      (tester) async {
    await _openSheetWithContent(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Quitter le formulaire ?'), findsOneWidget);
    expect(find.text('Garder le brouillon'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('« Annuler » laisse l’utilisateur dans le formulaire',
      (tester) async {
    await _openSheetWithContent(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Créer une annonce'), findsOneWidget,
        reason: 'annuler ne doit pas fermer la feuille');
  });

  testWidgets('« Garder le brouillon » écrit la saisie en cours et ferme',
      (tester) async {
    await _openSheetWithContent(tester);

    // Une modification postérieure à la reprise doit elle aussi être gardée.
    await tester.enterText(
        find.widgetWithText(TextField, 'départ confirmé'), 'départ retardé');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garder le brouillon'));
    await tester.pumpAndSettle();

    expect(find.text('Créer une annonce'), findsNothing);
    final draft = await FormDraftStore(slot: 'annonce').load();
    expect(draft, isNotNull);
    expect(draft!.data['description'], 'départ retardé');
  });

  testWidgets('« Supprimer » ferme sans rien conserver', (tester) async {
    await _openSheetWithContent(tester, description: 'à jeter');

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Créer une annonce'), findsNothing);
    expect(await FormDraftStore(slot: 'annonce').load(), isNull);
  });

  testWidgets('fermer un formulaire vide ne pose aucune question',
      (tester) async {
    await _openSheet(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Quitter le formulaire ?'), findsNothing);
    expect(find.text('Créer une annonce'), findsNothing);
  });

  testWidgets('un brouillon existant est proposé à la réouverture',
      (tester) async {
    await FormDraftStore(slot: 'annonce').save({
      'step': 0,
      'description': 'reprise attendue',
      'weight': '40',
      'price': '9000',
    });

    await _openSheet(tester);

    expect(find.text('Reprendre votre saisie ?'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Repartir à zéro'), findsOneWidget);
  });

  testWidgets('« Reprendre » réinjecte la saisie enregistrée', (tester) async {
    await FormDraftStore(slot: 'annonce').save({
      'step': 1,
      'description': 'reprise attendue',
      'weight': '40',
      'price': '9000',
    });

    await _openSheet(tester);
    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre votre saisie ?'), findsNothing);
    expect(find.text('reprise attendue'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('9000'), findsOneWidget);
  });

  testWidgets('« Repartir à zéro » efface le brouillon proposé',
      (tester) async {
    await FormDraftStore(slot: 'annonce').save({
      'step': 0,
      'description': 'à oublier',
    });

    await _openSheet(tester);
    await tester.tap(find.text('Repartir à zéro'));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre votre saisie ?'), findsNothing);
    expect(await FormDraftStore(slot: 'annonce').load(), isNull);
  });
}
