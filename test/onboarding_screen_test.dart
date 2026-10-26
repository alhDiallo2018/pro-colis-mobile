import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:procolis/screens/accueil/onboarding_screen.dart';
import 'package:procolis/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Le ProviderScope restaure une session : aucun canal natif en attente.
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

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

  testWidgets('une seule présentation même sans terminer le questionnaire',
      (tester) async {
    GoRouter makeRouter() => GoRouter(initialLocation: '/landing', routes: [
          GoRoute(
              path: '/landing', builder: (_, __) => const OnboardingScreen()),
          GoRoute(
              path: '/login',
              builder: (_, __) => const Scaffold(body: Text('Connexion test'))),
        ]);
    final firstRouter = makeRouter();
    addTearDown(firstRouter.dispose);
    await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: firstRouter)));
    await tester.pumpAndSettle();
    expect(find.text('Envoyer un colis'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('onboarding_seen'),
        isTrue);

    // La mémorisation ne doit pas interrompre le questionnaire affiché.
    firstRouter.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Envoyer un colis'), findsOneWidget);
    firstRouter.go('/login');
    await tester.pumpAndSettle();
    firstRouter.go('/landing');
    await tester.pumpAndSettle();
    expect(find.text('Connexion test'), findsOneWidget);
    expect(find.text('Envoyer un colis'), findsNothing);

    // Une nouvelle instance conserve la préférence, comme au redémarrage.
    await tester.pumpWidget(const SizedBox.shrink());
    final secondRouter = makeRouter();
    addTearDown(secondRouter.dispose);
    await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: secondRouter)));
    await tester.pumpAndSettle();
    expect(find.text('Connexion test'), findsOneWidget);
    expect(find.text('Envoyer un colis'), findsNothing);
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
