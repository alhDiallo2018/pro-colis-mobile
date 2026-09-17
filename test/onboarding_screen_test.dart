import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/screens/accueil/onboarding_screen.dart';
import 'package:procolis/theme/app_theme.dart';

void main() {
  Widget buildSubject() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OnboardingScreen(),
      ),
    );
  }

  testWidgets('affiche le questionnaire à la place de la landing page',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(
      find.text('Que souhaitez-vous faire sur Send ProColis ?'),
      findsOneWidget,
    );
    expect(find.text('Envoyer un colis'), findsOneWidget);
    expect(find.text('Livrer des colis'), findsOneWidget);
    expect(find.text('Suivre un colis'), findsNothing);
    expect(find.text('Gérer un garage'), findsNothing);
  });

  testWidgets('construit un guide personnalisé pour un expéditeur',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    // Le bouton « Continuer » n'est actif qu'une fois le choix enregistré :
    // il faut un `pump()` entre la sélection et la validation, sinon le tap
    // atteint encore le bouton désactivé du rendu précédent.
    await tester.tap(find.text('Envoyer un colis'));
    await tester.pump();
    await _tapWhenVisible(tester, 'Continuer');
    await tester.pumpAndSettle();

    await tester.tap(find.text('C’est ma première fois'));
    await tester.pump();
    await _tapWhenVisible(tester, 'Continuer');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Être guidé pas à pas'));
    await tester.pump();
    await _tapWhenVisible(tester, 'Afficher mon guide');
    await tester.pumpAndSettle();

    expect(
      find.text('Envoyez votre premier colis, pas à pas'),
      findsOneWidget,
    );
    expect(find.text('Votre parcours conseillé'), findsOneWidget);
    expect(find.text('Créer un compte expéditeur'), findsOneWidget);
  });
}

/// Fait défiler jusqu'au bouton demandé avant de le toucher.
///
/// Le questionnaire (`OnboardingScreen`) est contenu dans un
/// `SingleChildScrollView` : sur le viewport de test (800x600), les étapes
/// « expérience » et « priorité » placent leur bouton de validation sous la
/// ligne de flottaison. Un `tap()` direct dérive alors un `Offset` hors de la
/// zone de hit-test et le bouton n'est jamais déclenché. Dérouler jusqu'au
/// bouton reproduit le geste réel d'un utilisateur qui fait défiler l'écran
/// avant de valider.
Future<void> _tapWhenVisible(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
}
