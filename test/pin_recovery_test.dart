import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/routes/app_router.dart';
import 'package:procolis/screens/auth/forgot_pin_screen.dart';
import 'package:procolis/screens/auth/login_screen.dart';
import 'package:procolis/screens/auth/register_page.dart';
import 'package:procolis/services/api/client.dart';
import 'package:procolis/services/pin_recovery_service.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecoveryAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Map<String, dynamic> body = {'success': true};

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

PinRecoveryService service(RecoveryAdapter adapter,
    {Future<void> Function()? clearBiometrics}) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.example.test/api/v1',
    validateStatus: (status) => (status ?? 500) < 500,
  ))
    ..httpClientAdapter = adapter;
  return PinRecoveryService(
    client: ApiClient(dioOverride: dio),
    clearBiometrics: clearBiometrics ?? () async {},
  );
}

Future<void> mountRecovery(WidgetTester tester, PinRecoveryService recovery,
    {String identifier = '+221771234567'}) async {
  final router = GoRouter(initialLocation: '/forgot-pin', routes: [
    GoRoute(
        path: '/forgot-pin',
        builder: (_, __) => ForgotPinScreen(
              initialIdentifier: identifier,
            )),
    GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(
              body: Text('Connexion de test'),
            )),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [pinRecoveryServiceProvider.overrideWithValue(recovery)],
    child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('connexion → inscription → déjà un compte revient à la connexion',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(authProvider);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    final router = AppRouter.router();
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child:
          MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    router.go('/login');
    await tester.pumpAndSettle();
    final registerLink =
        find.text('Pas encore de compte ? Créer un compte', findRichText: true);
    await tester.ensureVisible(registerLink);
    await tester.tap(registerLink);
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);
    final loginLink =
        find.text('Déjà un compte ? Se connecter', findRichText: true);
    await tester.ensureVisible(loginLink);
    await tester.tap(loginLink);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/login');
    await tester.pumpWidget(const SizedBox());
  });

  test('respecte le contrat OTP et ne change la biométrie qu’après succès',
      () async {
    final adapter = RecoveryAdapter();
    var cleared = 0;
    final recovery = service(adapter, clearBiometrics: () async => cleared++);
    await recovery.requestCode('+221771234567');
    expect(cleared, 0);
    expect(adapter.requests.single.path, '/auth/forgot-password');
    expect(adapter.requests.single.data, {'identifier': '+221771234567'});
    await recovery.resetPin(
        identifier: '+221771234567', otpCode: '123456', newPin: '654321');
    expect(adapter.requests.last.path, '/auth/reset-password');
    expect(adapter.requests.last.data, {
      'identifier': '+221771234567',
      'otpCode': '123456',
      'newPin': '654321',
    });
    expect(cleared, 1);
  });

  test('un OTP expiré ne modifie pas le secret biométrique', () async {
    final adapter = RecoveryAdapter()
      ..status = 422
      ..body = {
        'success': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'details': [
            {'path': 'body.otpCode', 'message': 'Code invalide ou expire'},
          ]
        }
      };
    var cleared = false;
    final recovery =
        service(adapter, clearBiometrics: () async => cleared = true);
    await expectLater(
      recovery.resetPin(
          identifier: 'client@example.test',
          otpCode: '123456',
          newPin: '654321'),
      throwsA(isA<PinRecoveryException>()
          .having((e) => e.message, 'message', contains('expiré'))),
    );
    expect(cleared, false);
  });

  test('explique la limitation de tentatives sans exposer la réponse brute',
      () async {
    final adapter = RecoveryAdapter()..status = 429;
    await expectLater(
        service(adapter).requestCode('client@example.test'),
        throwsA(isA<PinRecoveryException>().having(
            (e) => e.message, 'message', contains('Trop de tentatives'))));
  });

  test('une panne du stockage ne transforme pas un reset réussi en échec',
      () async {
    final recovery = service(RecoveryAdapter(), clearBiometrics: () async {
      throw StateError('stockage indisponible');
    });
    await expectLater(
        recovery.resetPin(
            identifier: 'client@example.test',
            otpCode: '123456',
            newPin: '654321'),
        completes);
  });

  testWidgets(
      'valide la confirmation, garde le formulaire après OTP refusé et revient à la connexion',
      (tester) async {
    final adapter = RecoveryAdapter();
    await mountRecovery(tester, service(adapter));
    await tester.tap(find.text('Recevoir un code'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez votre nouveau PIN'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), '654321');
    await tester.enterText(fields.at(2), '654322');
    await tester.ensureVisible(find.text('Réinitialiser mon PIN'));
    await tester.tap(find.text('Réinitialiser mon PIN'));
    await tester.pumpAndSettle();
    expect(
        find.text('Les deux codes PIN ne correspondent pas.'), findsOneWidget);
    expect(adapter.requests, hasLength(1));

    await tester.enterText(fields.at(2), '654321');
    adapter.status = 422;
    adapter.body = {
      'success': false,
      'error': {
        'code': 'VALIDATION_ERROR',
        'details': [
          {'path': 'body.otpCode', 'message': 'Code invalide ou expire'},
        ],
      },
    };
    await tester.ensureVisible(find.text('Réinitialiser mon PIN'));
    await tester.tap(find.text('Réinitialiser mon PIN'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Code de vérification invalide'), findsOneWidget);
    expect(find.text('Votre code PIN a été réinitialisé'), findsNothing);

    adapter.status = 200;
    adapter.body = {'success': true, 'pinReset': true};
    await tester.ensureVisible(find.text('Réinitialiser mon PIN'));
    await tester.tap(find.text('Réinitialiser mon PIN'));
    await tester.pumpAndSettle();
    expect(find.text('Votre code PIN a été réinitialisé'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Retour à la connexion'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion de test'), findsOneWidget);
  });

  testWidgets('limite le renvoi et permet de corriger l’identifiant',
      (tester) async {
    final adapter = RecoveryAdapter();
    await mountRecovery(tester, service(adapter),
        identifier: 'client@example.test');
    await tester.tap(find.text('Recevoir un code'));
    await tester.pumpAndSettle();
    final disabled = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Renvoyer le code dans 60s'));
    expect(disabled.onPressed, isNull);
    await tester.pump(const Duration(seconds: 60));
    await tester.ensureVisible(find.text('Renvoyer le code'));
    await tester.tap(find.text('Renvoyer le code'));
    await tester.pumpAndSettle();
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.data, {'identifier': 'client@example.test'});
    await tester.ensureVisible(find.text('Modifier l’email ou le téléphone'));
    await tester.tap(find.text('Modifier l’email ou le téléphone'));
    await tester.pumpAndSettle();
    expect(find.text('Recevoir un code'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'le lien de connexion ouvre la vraie route publique avec le téléphone prérempli',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues(
        {'saved_identifier': '+221771234567'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(authProvider);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    final router = AppRouter.router();
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child:
          MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    router.go('/login');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Code PIN oublié ?'));
    await tester.tap(find.text('Code PIN oublié ?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPinScreen), findsOneWidget);
    expect(find.text('+221771234567'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
