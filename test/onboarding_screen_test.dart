import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/screens/accueil/onboarding_screen.dart';
import 'package:procolis/theme/app_theme.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const OnboardingScreen(),
    );
  }

  testWidgets('affiche le questionnaire à la place de la landing page',
      (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(
      find.text('Que souhaitez-vous faire sur ProColis ?'),
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

    await tester.tap(find.text('Envoyer un colis'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('C’est ma première fois'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Être guidé pas à pas'));
    await tester.tap(find.text('Afficher mon guide'));
    await tester.pumpAndSettle();

    expect(
      find.text('Envoyez votre premier colis, pas à pas'),
      findsOneWidget,
    );
    expect(find.text('Votre parcours conseillé'), findsOneWidget);
    expect(find.text('Créer un compte expéditeur'), findsOneWidget);
  });
}
