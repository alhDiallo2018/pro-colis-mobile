import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/screens/auth/login_screen.dart';
import 'package:procolis/screens/auth/google_completion_screen.dart';
import 'package:procolis/services/google_auth_service.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/widgets/auth_fields.dart';

class CaptureAuth extends AuthNotifier {
  final logins = <List<String>>[];
  Map<String, dynamic>? googleResult;
  @override
  Future<Map<String, dynamic>> loginWithPin(
      String pin, String identifier) async {
    logins.add([identifier, pin]);
    return {'success': false, 'message': 'Identifiant ou PIN incorrect'};
  }

  @override
  Future<void> completeGoogleLogin(Map<String, dynamic> result) async {
    googleResult = result;
  }
}

class FakeGoogle extends GoogleAuthService {
  @override
  bool get supported => true;
  Map<String, dynamic>? result;
  GoogleAuthException? error;
  int sent = 0;
  Map<String, dynamic>? registered;
  @override
  Future<Map<String, dynamic>?> signIn() async {
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<Map<String, dynamic>> sendOtp(String challenge, String phone) async {
    sent++;
    return {'sent': true};
  }

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    registered = data;
    if (error != null) throw error!;
    return {'status': 'authenticated'};
  }
}

Future<GoRouter> mount(WidgetTester tester, CaptureAuth auth, FakeGoogle google,
    {Map<String, dynamic>? challenge, double scale = 1}) async {
  final router = GoRouter(initialLocation: '/login', routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(
        path: '/google-auth',
        builder: (_, state) => GoogleCompletionScreen(
            challenge: state.extra as Map<String, dynamic>)),
    GoRoute(
        path: '/forgot-pin',
        builder: (_, state) =>
            Scaffold(body: Text('Récupération : ${state.extra}'))),
    GoRoute(
        path: '/dashboard',
        builder: (_, __) => const Scaffold(body: Text('Tableau de bord'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith((_) => auth),
        googleAuthServiceProvider.overrideWithValue(google),
      ],
      child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (_, child) => MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: child!))));
  await tester.pumpAndSettle();
  if (challenge != null) {
    router.push('/google-auth', extra: challenge);
    await tester.pumpAndSettle();
  }
  return router;
}

const challenge = {
  'status': 'profile_required',
  'challengeToken': 'opaque-challenge',
  'email': 'client@example.test',
  'fullName': 'Client Test'
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
      'téléphone par défaut, changement de mode conserve les champs et efface le PIN',
      (tester) async {
    final auth = CaptureAuth();
    await mount(tester, auth, FakeGoogle());
    expect(find.byKey(const ValueKey('phone-input')), findsOneWidget);
    expect(find.text('Se connecter avec Google'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('phone-input')), '771234567');
    await tester.enterText(
        find.descendant(
            of: find.byType(AuthPinField),
            matching: find.byType(TextFormField)),
        '123456');
    await tester.pumpAndSettle();
    expect(auth.logins, isEmpty); // Pas d'envoi automatique au 6e chiffre.
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    expect(find.text('Se connecter avec Google'), findsOneWidget);
    expect(find.text('+221'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('email-input')), 'client@example.test');
    expect(
        tester.widget<AuthPinField>(find.byType(AuthPinField)).controller.text,
        isEmpty);
    await tester.tap(find.text('Téléphone'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('phone-input')))
            .controller!
            .text,
        '771234567');
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('email-input')))
            .controller!
            .text,
        'client@example.test');
  });

  testWidgets(
      'restaure un ancien numéro international et préremplit la récupération sans double indicatif',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'saved_identifier': '+221771234567', 'remember_me': true});
    await mount(tester, CaptureAuth(), FakeGoogle());
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('phone-input')))
            .controller!
            .text,
        '771234567');
    await tester.tap(find.text('Code PIN oublié ?'));
    await tester.pumpAndSettle();
    expect(find.text('Récupération : +221771234567'), findsOneWidget);
  });

  testWidgets(
      'migre un email mémorisé, valide les champs et envoie seulement email + PIN',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'saved_identifier': 'client@example.test', 'remember_me': true});
    final auth = CaptureAuth();
    await mount(tester, auth, FakeGoogle());
    final email = find.byKey(const ValueKey('email-input'));
    expect(email, findsOneWidget);
    await tester.enterText(email, 'invalide');
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Saisissez une adresse email valide'), findsOneWidget);
    expect(auth.logins, isEmpty);
    await tester.enterText(email, 'Client@Example.test');
    await tester.enterText(
        find.descendant(
            of: find.byType(AuthPinField),
            matching: find.byType(TextFormField)),
        '123456');
    await tester.ensureVisible(find.text('Se connecter'));
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(auth.logins.single, ['client@example.test', '123456']);
  });

  testWidgets('Google annulé ne navigue pas, une panne garde le formulaire',
      (tester) async {
    final google = FakeGoogle();
    final router = await mount(tester, CaptureAuth(), google);
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se connecter avec Google'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    google.error = const GoogleAuthException('Google indisponible');
    await tester.tap(find.text('Se connecter avec Google'));
    await tester.pumpAndSettle();
    expect(find.text('Google indisponible'), findsOneWidget);
    expect(find.byKey(const ValueKey('email-input')), findsOneWidget);
  });

  testWidgets(
      'Google ouvre la complétion, vérifie confirmation/conditions, limite le renvoi',
      (tester) async {
    final google = FakeGoogle()..result = challenge;
    final auth = CaptureAuth();
    await mount(tester, auth, google);
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se connecter avec Google'));
    await tester.pumpAndSettle();
    expect(find.byType(GoogleCompletionScreen), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('phone-input')), '771234567');
    await tester.ensureVisible(find.text('Recevoir le code SMS'));
    await tester.tap(find.text('Recevoir le code SMS'));
    await tester.pumpAndSettle();
    expect(google.sent, 1);
    expect(find.textContaining('Renvoyer le code dans'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('google-otp')), '123456');
    final pins = find.descendant(
        of: find.byType(AuthPinField), matching: find.byType(TextFormField));
    await tester.enterText(pins.at(0), '654321');
    await tester.enterText(pins.at(1), '111111');
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();
    expect(find.text('Les deux codes PIN sont différents'), findsOneWidget);
    expect(google.registered, isNull);
    await tester.enterText(pins.at(1), '654321');
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();
    expect(google.registered, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile).last);
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pumpAndSettle();
    expect(google.registered, containsPair('phone', '+221771234567'));
    expect(google.registered, containsPair('role', 'client'));
    expect(auth.googleResult, containsPair('status', 'authenticated'));
    expect(find.text('Tableau de bord'), findsOneWidget);
  });

  testWidgets(
      'association Google : le PIN oublié reprend le téléphone international',
      (tester) async {
    await mount(tester, CaptureAuth(), FakeGoogle(),
        challenge: {...challenge, 'status': 'link_required'});
    await tester.enterText(
        find.byKey(const ValueKey('google-link-identifier')), '771234567');
    await tester.ensureVisible(find.text('Code PIN oublié ?'));
    await tester.tap(find.text('Code PIN oublié ?'));
    await tester.pumpAndSettle();
    expect(find.text('Récupération : +221771234567'), findsOneWidget);
  });

  testWidgets('petit écran et caractères agrandis restent utilisables',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mount(tester, CaptureAuth(), FakeGoogle(), scale: 1.6);
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Se connecter'));
    expect(tester.takeException(), isNull);
  });
}
