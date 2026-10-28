import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_session_test.dart' show transport, jsonBody;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/services/api/client.dart';
import 'package:procolis/services/google_auth_service.dart';
import 'package:procolis/services/auth_session.dart';
import 'package:procolis/services/biometric_service.dart';

const challenge = {
  'status': 'profile_required',
  'challengeToken': 'opaque-challenge'
};

class GoogleAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(
        jsonEncode({'success': true, ...challenge}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
      'les routes Google publiques ne transportent pas une ancienne session et ne stockent aucun challenge',
      () async {
    await AuthSessionManager.instance.establish(
        {'accessToken': 'old-access', 'refreshToken': 'old-refresh'});
    final adapter = GoogleAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(SessionAuthInterceptor(dio));
    final service = GoogleAuthService(client: ApiClient(dioOverride: dio));
    await service.link('challenge', '+221771234567', '123456');
    expect(adapter.requests.single.path, '/auth/google/link');
    expect(adapter.requests.single.headers['Authorization'], isNull);
    expect(
        (await AuthSessionManager.instance.read())!.accessToken, 'old-access');
    expect(
        await const FlutterSecureStorage().read(key: 'challengeToken'), isNull);
    await AuthSessionManager.instance.clear();
  });

  test(
      'iOS initialise son client natif et transmet seulement le jeton vérifiable au serveur',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final requests = <RequestOptions>[];
    final dio = transport((o) {
      requests.add(o);
      return jsonBody(o.path.endsWith('/config')
          ? {
              'success': true,
              'enabled': true,
              'serverClientId': 'web.apps.googleusercontent.com'
            }
          : {'success': true, ...challenge});
    });
    final service = GoogleAuthService(
        client: ApiClient(dioOverride: dio),
        nativeConfiguration: () async => {
              'clientId': 'ios.apps.googleusercontent.com',
              'urlSchemeConfigured': true
            },
        authenticate: (server, client) async {
          expect(server, 'web.apps.googleusercontent.com');
          expect(client, 'ios.apps.googleusercontent.com');
          return 'google-id-token';
        });
    expect(service.supported, true);
    expect((await service.signIn())!['status'], 'profile_required');
    expect(requests.last.data, {'idToken': 'google-id-token'});
    dio.close();
  });
  test('iOS non configuré échoue proprement avant le SDK natif', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final dio = transport((_) => jsonBody({
          'success': true,
          'enabled': true,
          'serverClientId': 'web.apps.googleusercontent.com'
        }));
    var called = false;
    final service = GoogleAuthService(
        client: ApiClient(dioOverride: dio),
        nativeConfiguration: () async => {},
        authenticate: (_, __) async {
          called = true;
          return 'token';
        });
    await expectLater(
        service.signIn(),
        throwsA(isA<GoogleAuthException>().having(
            (e) => e.code, 'configuration', 'GOOGLE_IOS_NOT_CONFIGURED')));
    expect(called, false);
    dio.close();
  });
  test('Android utilise le client Web comme audience, sans client iOS',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final dio = transport((o) => jsonBody(o.path.endsWith('/config')
        ? {
            'success': true,
            'enabled': true,
            'serverClientId': 'web.apps.googleusercontent.com'
          }
        : {'success': true, ...challenge}));
    final service = GoogleAuthService(
        client: ApiClient(dioOverride: dio),
        authenticate: (server, client) async {
          expect(client, isNull);
          expect(server, 'web.apps.googleusercontent.com');
          return 'token';
        });
    expect((await service.signIn())!['status'], 'profile_required');
    dio.close();
  });

  test(
      'un autre compte Google efface la biométrie précédente et garde le PIN comme repli',
      () async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'saved_identifier', value: '+221770000000');
    await BiometricService.enable('123456');
    final auth = AuthNotifier();
    addTearDown(auth.dispose);
    await auth.completeGoogleLogin({
      'status': 'authenticated',
      'accessToken': 'google-access',
      'refreshToken': 'google-refresh',
      'user': {
        'id': 'google-user',
        'phone': '+221771234567',
        'fullName': 'Client Google',
        'role': 'client'
      }
    });
    expect(await BiometricService.isEnabled(), isFalse);
    expect(await auth.getSavedIdentifier(), '+221771234567');
    expect(auth.state.isAuthenticated, isTrue);
    await AuthSessionManager.instance.clear();
  });
}
