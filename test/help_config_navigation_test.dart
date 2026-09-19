import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:procolis/providers/public_config_provider.dart';
import 'package:procolis/screens/help/help_screen.dart';
import 'package:procolis/screens/legal/cgu_page.dart';
import 'package:procolis/screens/legal/confidentialite_page.dart';
import 'package:procolis/screens/settings/settings_screen.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _config({String suffix = ''}) => {
      'help': {
        'topics': [
          for (final icon in [
            'person',
            'inventory_2',
            'local_shipping',
            'location_on',
            'payments',
            'cancel',
            'directions_car',
            'verified_user',
            'support_agent',
          ])
            {'icon': icon, 'title': 'Catégorie $icon$suffix'},
        ],
        'faqs': [
          for (var i = 1; i <= 15; i++)
            {'question': 'Question $i ?$suffix', 'answer': 'Réponse $i$suffix'},
        ],
      },
    };

Widget _scope(PublicConfigNotifier notifier, Widget child) => ProviderScope(
      overrides: [publicConfigProvider.overrideWith((ref) => notifier)],
      child: child,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/local_auth'),
      (call) async => false,
    );
  });

  test('partage le chargement et conserve la configuration en cas d’échec',
      () async {
    final response = Completer<Map<String, dynamic>>();
    var calls = 0;
    final notifier = PublicConfigNotifier(loadConfig: () {
      calls++;
      return calls == 1 ? response.future : Future.value({});
    });
    addTearDown(notifier.dispose);
    final first = notifier.load();
    final second = notifier.load();
    expect(calls, 1);
    response.complete(_config());
    expect(await first, true);
    expect(await second, true);
    final previous = notifier.state;
    expect(previous!.helpTopics.length, 9);
    expect(previous.helpFaqs.length, 15);
    expect(await notifier.load(), false);
    expect(notifier.state, same(previous));
  });

  testWidgets('actualise les 9 catégories et 15 FAQ à l’ouverture',
      (tester) async {
    var response = _config(suffix: ' ancien');
    final notifier = PublicConfigNotifier(loadConfig: () async => response);
    await notifier.load();
    response = _config();
    await tester.pumpWidget(_scope(
      notifier,
      MaterialApp(theme: AppTheme.lightTheme, home: const HelpScreen()),
    ));
    await tester.pumpAndSettle();
    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.childrenDelegate.estimatedChildCount, 9);
    expect(find.textContaining('ancien'), findsNothing);
    expect(
        find.descendant(
            of: find.byType(GridView),
            matching: find.byIcon(Icons.inventory_2_rounded)),
        findsOneWidget);

    await tester.scrollUntilVisible(find.text('Questions fréquentes'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(
        find.textContaining(RegExp(r'^Question \d+ \?$')), findsNWidgets(15));

    // Une liste vidée côté administration doit aussi vider l'écran mobile.
    response = {
      'help': {'topics': [], 'faqs': []}
    };
    await tester.tap(find.byTooltip('Actualiser'));
    await tester.pumpAndSettle();
    expect(find.text('Le contenu d’aide n’est pas encore configuré.'),
        findsOneWidget);
    expect(find.textContaining(RegExp(r'^Question \d+ \?$')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permet de réessayer après un démarrage hors ligne',
      (tester) async {
    var online = false;
    final notifier = PublicConfigNotifier(
      loadConfig: () async => online ? _config() : {},
    );
    await tester.pumpWidget(_scope(
      notifier,
      MaterialApp(theme: AppTheme.lightTheme, home: const HelpScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsOneWidget);
    online = true;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Réessayer'), findsNothing);
    expect(find.text('Catégorie person'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Les paramètres sont ouverts soit par GoRouter, soit par Navigator depuis
  // les profils. Vérifie le vrai lien de l'écran dans les deux historiques.
  for (final imperative in [false, true]) {
    for (final legal in ['Confidentialité', 'Conditions d’utilisation']) {
      for (final systemBack in [false, true]) {
        testWidgets(
            '$legal : retour ${systemBack ? "système" : "flèche"}, '
            'paramètres ${imperative ? "Navigator" : "GoRouter"}',
            (tester) async {
          final notifier =
              PublicConfigNotifier(loadConfig: () async => _config());
          final router = GoRouter(
            initialLocation: imperative ? '/profile' : '/settings',
            routes: [
              GoRoute(
                  path: '/',
                  builder: (_, __) =>
                      const Scaffold(body: Text('Page accueil racine'))),
              GoRoute(
                  path: '/profile',
                  builder: (context, _) => Scaffold(
                        body: TextButton(
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          )),
                          child: const Text('Ouvrir les paramètres'),
                        ),
                      )),
              GoRoute(
                  path: '/settings',
                  builder: (_, __) => const SettingsScreen()),
              GoRoute(path: '/cgu', builder: (_, __) => const CGUPage()),
              GoRoute(
                  path: '/confidentialite',
                  builder: (_, __) => const ConfidentialitePage()),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(_scope(
            notifier,
            MaterialApp.router(
                theme: AppTheme.lightTheme, routerConfig: router),
          ));
          await tester.pumpAndSettle();
          if (imperative) {
            await tester.tap(find.text('Ouvrir les paramètres'));
            await tester.pumpAndSettle();
          }
          final previous = tester.element(find.byType(SettingsScreen));
          await tester.scrollUntilVisible(find.text(legal), 300,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(legal));
          await tester.pumpAndSettle();
          expect(
              find.byType(
                  legal == 'Confidentialité' ? ConfidentialitePage : CGUPage),
              findsOneWidget);
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byTooltip('Retour'));
          }
          await tester.pumpAndSettle();
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(tester.element(find.byType(SettingsScreen)), same(previous));
          expect(find.text('Page accueil racine'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
