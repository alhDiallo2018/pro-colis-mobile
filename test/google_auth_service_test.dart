import 'dart:convert';
import 'dart:typed_data';
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
