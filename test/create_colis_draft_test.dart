// Parcours brouillon du formulaire « Nouveau colis ».
//
// Le formulaire instancie l'enregistreur audio et le lecteur : les tests se
// limitent donc à ce qui n'a pas besoin de ces plugins — bandeau de reprise,
// restauration des champs, confirmation de sortie.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/screens/parcel/create_colis_sheet.dart';
import 'package:procolis/services/form_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCreateColisSheet(context),
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

Map<String, dynamic> _draftData({String receiverName = 'Awa Ndiaye'}) => {
      'step': 0,
      'receiverName': receiverName,
      'receiverPhone': '+221770001111',
      'receiverAddress': 'Sacré-Cœur 3',
      'weight': '7',
      'description': 'carton de livres',
      'type': 'fragile',
      'urgent': true,
      'insurance': false,
      'price': '18000',
      'priceEdited': true,
      'mode': 'free',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sans brouillon, aucun bandeau de reprise', (tester) async {
    await _openSheet(tester);

    expect(find.text('Nouveau colis'), findsOneWidget);
    expect(find.text('Reprendre votre saisie ?'), findsNothing);
  });

  testWidgets('un brouillon existant est proposé à la réouverture',
      (tester) async {
    await FormDraftStore(slot: 'colis').save(_draftData());
    await _openSheet(tester);

    expect(find.text('Reprendre votre saisie ?'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Repartir à zéro'), findsOneWidget);
  });

  testWidgets('« Reprendre » réinjecte les champs du destinataire',
      (tester) async {
    await FormDraftStore(slot: 'colis').save(_draftData());
    await _openSheet(tester);

    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre votre saisie ?'), findsNothing);
    expect(find.text('Awa Ndiaye'), findsOneWidget);
    expect(find.text('+221770001111'), findsOneWidget);
    expect(find.text('Sacré-Cœur 3'), findsOneWidget);
  });

  testWidgets('« Repartir à zéro » efface le brouillon proposé',
      (tester) async {
    await FormDraftStore(slot: 'colis').save(_draftData());
    await _openSheet(tester);

    await tester.tap(find.text('Repartir à zéro'));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre votre saisie ?'), findsNothing);
    expect(await FormDraftStore(slot: 'colis').load(), isNull);
  });

  testWidgets('fermer un formulaire vide ne pose aucune question',
      (tester) async {
    await _openSheet(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Quitter le formulaire ?'), findsNothing);
    expect(find.text('Nouveau colis'), findsNothing);
  });

  testWidgets('fermer une saisie reprise propose de garder le brouillon',
      (tester) async {
    await FormDraftStore(slot: 'colis').save(_draftData());
    await _openSheet(tester);
    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Quitter le formulaire ?'), findsOneWidget);
  });

  testWidgets('« Garder » conserve une saisie faite bandeau encore affiché',
      (tester) async {
    // Régression : la saisie en cours doit primer sur le brouillon proposé.
    // Tant que le bandeau était affiché, la garde de pause annulait l'écriture
    // et « Garder le brouillon » ne gardait rien.
    await FormDraftStore(slot: 'colis')
        .save(_draftData(receiverName: 'Ancien'));
    await _openSheet(tester);

    expect(find.text('Reprendre votre saisie ?'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Ex : Awa Ndiaye'), 'Nouveau');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garder le brouillon'));
    await tester.pumpAndSettle();

    final draft = await FormDraftStore(slot: 'colis').load();
    expect(draft, isNotNull);
    expect(draft!.data['receiverName'], 'Nouveau');
  });
}
