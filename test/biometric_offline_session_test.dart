import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/auth_session.dart';
import 'package:procolis/services/biometric_service.dart';
import 'package:procolis/services/offline_access.dart';
import 'auth_session_test.dart' show transport;
import 'package:dio/dio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const user = {
    'id': 'alice',
    'role': 'client',
    'fullName': 'Alice',
    'status': 'active'
  };
  const path = 'https://session.test/client/parcels/my-parcels';
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthSessionManager.instance
        .establish({'accessToken': 'a', 'refreshToken': 'r', 'user': user});
    final session = (await AuthSessionManager.instance.read())!;
    await AuthSessionManager.instance
        .saveCachedResponse(session.generation, '/auth/me', {'user': user});
    await AuthSessionManager.instance
        .saveCachedResponse(session.generation, path, {
      'parcels': [
        {
          'id': 'real-parcel-123',
          'trackingNumber': 'PC-123',
          'status': 'delivered',
          'weight': 12
        }
      ]
    });
  });
  test(
      'activer la biométrie ne renouvelle pas les jetons et garde les vrais colis',
      () async {
    final before = (await AuthSessionManager.instance.read())!;
    await BiometricService.enableForSession('alice');
    expect(await BiometricService.isEnabled(), true);
    expect((await AuthSessionManager.instance.read())!.generation,
        before.generation);
    expect(await BiometricService.readPin(), isNull);
    expect(
        (await AuthSessionManager.instance.readCachedResponse(
            before.generation, path))!['data']['parcels'][0]['id'],
        'real-parcel-123');
  });
  test(
      'une reconnexion du même compte conserve le cache mais invalide les anciennes requêtes',
      () async {
    final before = (await AuthSessionManager.instance.read())!;
    await BiometricService.enableForSession('alice');
    await AuthSessionManager.instance.establish(
        {'accessToken': 'new-a', 'refreshToken': 'new-r', 'user': user});
    final after = (await AuthSessionManager.instance.read())!;
    expect(after.generation, isNot(before.generation));
    expect(await BiometricService.isEnabled(), true);
    expect(
        await AuthSessionManager.instance
            .readCachedResponse(before.generation, path),
        isNull);
    final restarted = AuthSessionManager();
    expect(
        (await restarted.readCachedResponse(after.generation, path))!['data']
            ['parcels'][0]['trackingNumber'],
        'PC-123');
  });
  test(
      'un autre compte ne voit jamais les colis ou le réglage biométrique précédent',
      () async {
    await BiometricService.enableForSession('alice');
    await AuthSessionManager.instance.establish({
      'accessToken': 'b',
      'refreshToken': 'br',
      'user': {'id': 'bob', 'role': 'client'}
    });
    final session = (await AuthSessionManager.instance.read())!;
    await AuthSessionManager.instance
        .saveCachedResponse(session.generation, '/auth/me', {
      'user': {'id': 'bob', 'role': 'client'}
    });
    expect(await BiometricService.isEnabled(), false);
    expect(
        await AuthSessionManager.instance
            .readCachedResponse(session.generation, path),
        isNull);
  });
  test(
      'redémarrage sans Internet : les données réelles restent identiques et datées',
      () async {
    await BiometricService.enableForSession('alice');
    final sessions = AuthSessionManager(), access = OfflineAccess();
    final dio = transport((options) => throw DioException(
        requestOptions: options, type: DioExceptionType.connectionError));
    dio.interceptors.addAll([
      SessionAuthInterceptor(dio, sessions: sessions),
      OfflineAccessInterceptor(sessions: sessions, access: access)
    ]);
    final response = await dio.get('/client/parcels/my-parcels');
    expect(
        jsonEncode(response.data),
        jsonEncode({
          'parcels': [
            {
              'id': 'real-parcel-123',
              'trackingNumber': 'PC-123',
              'status': 'delivered',
              'weight': 12
            }
          ]
        }));
    expect(access.value.savedAt, isNotNull);
    expect(response.extra['offlineCache'], true);
    expect(await BiometricService.isEnabled(), true);
    dio.close();
    access.dispose();
  });
}
