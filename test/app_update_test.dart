import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:procolis/models/app_update_policy.dart';
import 'package:procolis/providers/app_update_provider.dart';
import 'package:procolis/widgets/app_update_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> policy(
        {bool enabled = true,
        String latest = '1.1.0',
        int latestBuild = 8,
        int minimumBuild = 0,
        bool force = false}) =>
    {
      'enabled': enabled,
      'latestVersion': latest,
      'latestVersionCode': latestBuild,
      'minVersionCode': force ? latestBuild : minimumBuild,
      'remindAfterHours': 24,
      'updateUrl':
          'https://play.google.com/store/apps/details?id=com.sendprocolis.app',
      'releaseNotes': {
        'fr': 'Une meilleure expérience vous attend.',
        'en': 'A better experience awaits.'
      },
    };

AppUpdateNotifier notifier(
        {Future<Map<String, dynamic>> Function()? load,
        DateTime Function()? now,
        bool supported = true}) =>
    AppUpdateNotifier(
      loadPolicy: load ?? () async => policy(),
      loadInstalled: () async => AppRelease('1.0.0', 6),
      now: now,
      supported: supported,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('les notes suivent la langue avec un repli français', () {
    final update = AppUpdatePolicy.fromJson(policy());
    expect(update.notesFor('en'), 'A better experience awaits.');
    expect(update.notesFor('fr'), 'Une meilleure expérience vous attend.');
    expect(update.notesFor('wo'), update.notesFor('fr'));
  });

  test(
      'un code supérieur reste accepté même si le nom de version est inférieur',
      () {
    final update = AppUpdatePolicy.fromJson(
        policy(latest: '9.9.9', latestBuild: 46, minimumBuild: 40));
    expect(update.requiresUpdate(AppRelease('1.0.0', 40)), isFalse);
    expect(update.hasUpdate(AppRelease('1.0.0', 46)), isFalse);
    expect(update.requiresUpdate(AppRelease('99.0.0', 39)), isTrue);
  });

  test(
      'le délai de rappel vient de l’API et le contrôle manuel rouvre le popup',
      () async {
    var now = DateTime(2026, 10, 25);
    final service = notifier(
        now: () => now,
        load: () async => {...policy(), 'remindAfterHours': 48});
    addTearDown(service.dispose);
    await service.refresh();
    await service.dismiss();
    now = now.add(const Duration(hours: 24));
    await service.refresh();
    expect(service.state.showPrompt, isFalse);
    await service.checkNow();
    expect(service.state.showPrompt, isTrue);
    await service.dismiss();
    now = now.add(const Duration(hours: 48));
    await service.refresh();
    expect(service.state.showPrompt, isTrue);
  });

  test('relit le code installé après une installation effective', () async {
    var installed = AppRelease('1.0.0', 6);
    final service = AppUpdateNotifier(
        supported: true,
        loadInstalled: () async => installed,
        loadPolicy: () async => policy(minimumBuild: 8));
    addTearDown(service.dispose);
    await service.refresh();
    expect(service.state.mandatory, isTrue);
    installed = AppRelease('1.1.0', 8);
    await service.refresh(force: true);
    expect(service.state.mandatory, isFalse);
    expect(service.state.showPrompt, isFalse);
  });

  test('le code Android décide, indépendamment du nom commercial', () {
    expect(AppRelease('1.0.0', 10).compareTo(AppRelease('9.9.9', 9)),
        greaterThan(0));
    expect(AppRelease('1.0.0', 7).compareTo(AppRelease('1.0.0', 6)),
        greaterThan(0));
    final update =
        AppUpdatePolicy.fromJson(policy(latest: '1.0.0', latestBuild: 7));
    expect(update.hasUpdate(AppRelease('1.0.0', 6)), isTrue);
    expect(update.hasUpdate(AppRelease('1.0.0', 7)), isFalse);
    expect(update.hasUpdate(AppRelease('2.0.0', 99)), isFalse);
    expect(update.requiresUpdate(AppRelease('1.0.0', 6)), isFalse);
  });

  test('minimum exclusif et minimum égal à la dernière version', () {
    final update = AppUpdatePolicy.fromJson(policy(minimumBuild: 6));
    expect(update.requiresUpdate(AppRelease('0.9.0', 5)), isTrue);
    expect(update.requiresUpdate(AppRelease('1.0.0', 5)), isTrue);
    expect(update.requiresUpdate(AppRelease('1.0.0', 6)), isFalse);
    final forced = AppUpdatePolicy.fromJson(policy(force: true));
    expect(forced.requiresUpdate(AppRelease('1.0.0', 6)), isTrue);
    expect(forced.requiresUpdate(AppRelease('1.1.0', 8)), isFalse);
    expect(forced.requiresUpdate(AppRelease('2.0.0', 99)), isFalse);
    final disabled =
        AppUpdatePolicy.fromJson(policy(enabled: false, force: true));
    expect(disabled.requiresUpdate(AppRelease('0.9.0', 1)), isFalse);
    expect(disabled.hasUpdate(AppRelease('0.9.0', 1)), isFalse);
  });

  test(
      'rejette payload partiel, version invalide, minimum incohérent et lien dangereux',
      () {
    for (final invalid in [
      <String, dynamic>{},
      {...policy(), 'enabled': 'true'},
      {...policy(), 'latestVersion': ''},
      {...policy(), 'latestVersionCode': -1},
      {...policy(), 'minVersionCode': 9},
      {...policy(), 'updateUrl': 'http://example.com'},
      {...policy(), 'updateUrl': 'https://user:password@example.com'},
    ]) {
      expect(() => AppUpdatePolicy.fromJson(invalid), throwsFormatException);
    }
  });

  test('lit la version réellement installée via PackageInfo', () async {
    PackageInfo.setMockInitialValues(
        appName: 'ProColis',
        packageName: 'com.sendprocolis.app',
        version: '1.10.0',
        buildNumber: '42',
        buildSignature: '');
    final service =
        AppUpdateNotifier(supported: true, loadPolicy: () async => policy());
    addTearDown(service.dispose);
    await service.refresh();
    expect(service.state.installed!.id, '1.10.0+42');
    expect(service.state.showPrompt, isFalse);
  });

  test(
      'partage les vérifications concurrentes et limite les retours au premier plan',
      () async {
    var calls = 0;
    final response = Completer<Map<String, dynamic>>();
    final service = notifier(load: () {
      calls++;
      return response.future;
    });
    addTearDown(service.dispose);
    final first = service.refresh();
    final second = service.refresh(force: true);
    response.complete(policy());
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(service.state.showPrompt, isTrue);
    await service.refresh();
    expect(calls, 1);
  });

  test('un report dure 24h et persiste après redémarrage', () async {
    var now = DateTime(2026, 10, 25, 10);
    final first = notifier(now: () => now);
    addTearDown(first.dispose);
    await first.refresh();
    await first.dismiss();
    expect(first.state.showPrompt, isFalse);
    final restarted = notifier(now: () => now);
    addTearDown(restarted.dispose);
    await restarted.refresh();
    expect(restarted.state.showPrompt, isFalse);
    now = now.add(const Duration(hours: 24));
    await restarted.refresh();
    expect(restarted.state.showPrompt, isTrue);
  });

  test('une nouvelle release facultative annule le report de la précédente',
      () async {
    var current = policy();
    final service = notifier(load: () async => current);
    addTearDown(service.dispose);
    await service.refresh();
    await service.dismiss();
    current = policy(latest: '1.2.0', latestBuild: 9);
    await service.refresh(force: true);
    expect(service.state.showPrompt, isTrue);
  });

  for (final forced in [false, true]) {
    test('une obligation annule Plus tard (force=$forced)', () async {
      var current = policy();
      final service = notifier(load: () async => current);
      addTearDown(service.dispose);
      await service.refresh();
      await service.dismiss();
      current = policy(force: forced, minimumBuild: forced ? 0 : 7);
      await service.refresh(force: true);
      expect(service.state.mandatory, isTrue);
      await service.dismiss();
      expect(service.state.showPrompt, isTrue);
    });
  }

  test('reste utilisable hors ligne si aucune règle connue', () async {
    final service = notifier(load: () async => throw Exception('offline'));
    addTearDown(service.dispose);
    await service.refresh();
    expect(service.state.checkFailed, isTrue);
    expect(service.state.showPrompt, isFalse);
  });

  test(
      'conserve une obligation hors ligne après redémarrage puis accepte la désactivation',
      () async {
    final first = notifier(load: () async => policy(force: true));
    addTearDown(first.dispose);
    await first.refresh();
    var offline = true;
    final restarted = notifier(load: () async {
      if (offline) throw Exception('offline');
      return policy(enabled: false);
    });
    addTearDown(restarted.dispose);
    await restarted.refresh();
    expect(restarted.state.mandatory, isTrue);
    expect(restarted.state.checkFailed, isTrue);
    offline = false;
    await restarted.refresh(force: true);
    expect(restarted.state.showPrompt, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString(AppUpdateNotifier.cacheKey)!)['enabled'],
        isFalse);
  });

  test('un payload invalide ne lève pas une obligation existante', () async {
    var current = policy(force: true);
    final service = notifier(load: () async => current);
    addTearDown(service.dispose);
    await service.refresh();
    current = {};
    await service.refresh(force: true);
    expect(service.state.mandatory, isTrue);
    expect(service.state.checkFailed, isTrue);
  });

  test('un cache corrompu ne bloque pas la récupération réseau', () async {
    SharedPreferences.setMockInitialValues(
        {AppUpdateNotifier.cacheKey: 'bad json'});
    final service = notifier(load: () async => policy(force: true));
    addTearDown(service.dispose);
    await service.refresh();
    expect(service.state.mandatory, isTrue);
    expect(service.state.checkFailed, isFalse);
  });

  test('ne vérifie pas iOS, le web ou les autres plateformes', () async {
    var calls = 0;
    final service = notifier(
        supported: false,
        load: () async {
          calls++;
          return policy();
        });
    addTearDown(service.dispose);
    await service.refresh();
    expect(calls, 0);
    expect(service.state.showPrompt, isFalse);
  });

  Future<GoRouter> mountGate(WidgetTester tester, AppUpdateNotifier service,
      {Future<bool> Function(Uri)? openStore}) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: Center(
                  child: TextButton(
                      onPressed: () {}, child: const Text('Application')))))
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [appUpdateProvider.overrideWith((ref) => service)],
      child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => AppUpdateGate(
              backButtonDispatcher: router.backButtonDispatcher,
              openStore: openStore,
              child: child!)),
    ));
    await tester.pumpAndSettle();
    addTearDown(router.dispose);
    return router;
  }

  testWidgets('popup facultatif, Plus tard et store externe', (tester) async {
    final service = notifier();
    await service.refresh();
    Uri? opened;
    await mountGate(tester, service, openStore: (url) async {
      opened = url;
      return true;
    });
    expect(find.text('Une mise à jour est disponible'), findsOneWidget);
    expect(find.textContaining('Version installée : 1.0.0'), findsOneWidget);
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();
    expect(opened!.scheme, 'https');
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('le démarrage masque l’app jusqu’à la décision initiale',
      (tester) async {
    final response = Completer<Map<String, dynamic>>();
    final service = notifier(load: () => response.future);
    final pending = service.refresh();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Text('Application'))
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [appUpdateProvider.overrideWith((ref) => service)],
      child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => AppUpdateGate(
              backButtonDispatcher: router.backButtonDispatcher,
              child: child!)),
    ));
    await tester.pump();
    expect(find.text('Vérification de la version…'), findsOneWidget);
    expect(
        tester
            .widgetList<IgnorePointer>(find.ancestor(
                of: find.text('Application'),
                matching: find.byType(IgnorePointer)))
            .any((widget) => widget.ignoring),
        isTrue);
    response.complete(policy(enabled: false));
    await pending;
    await tester.pumpAndSettle();
    expect(find.text('Vérification de la version…'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'ouvrir le store ne lève pas le blocage et son retour force une vérification',
      (tester) async {
    var calls = 0;
    final service = notifier(load: () async {
      calls++;
      return policy(minimumBuild: 8);
    });
    await service.refresh();
    await mountGate(tester, service, openStore: (_) async => true);
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();
    expect(service.state.mandatory, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Mise à jour obligatoire'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('popup obligatoire résiste à Retour, au fond et à une navigation',
      (tester) async {
    final service = notifier(load: () async => policy(force: true));
    await service.refresh();
    final router = await mountGate(tester, service);
    expect(find.text('Plus tard'), findsNothing);
    expect(
        await router.backButtonDispatcher.invokeCallback(Future.value(false)),
        isTrue);
    await tester.binding.handlePopRoute();
    await tester.tapAt(const Offset(5, 5));
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('Mise à jour obligatoire'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'échec du store : message et possibilité de réessayer sans débloquer',
      (tester) async {
    final service = notifier(load: () async => policy(force: true));
    await service.refresh();
    var calls = 0;
    await mountGate(tester, service, openStore: (_) async {
      calls++;
      return false;
    });
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Impossible d’ouvrir le Play Store'),
        findsOneWidget);
    expect(find.text('Mise à jour obligatoire'), findsOneWidget);
    await tester.tap(find.text('Mettre à jour'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('revérification lève le popup après désactivation distante',
      (tester) async {
    var current = policy(force: true);
    final service = notifier(load: () async => current);
    await service.refresh();
    await mountGate(tester, service);
    current = policy(enabled: false);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
