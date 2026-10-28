import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/auth_session.dart';
import 'package:procolis/services/offline_access.dart';

import 'auth_session_test.dart' show transport, jsonBody;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthSessionManager sessions;
  late OfflineAccess access;
  late Dio dio;
  var offline = false;
  var status = 200;
  var writes = 0;
  const profile = {
    'user': {
      'id': 'alice',
      'fullName': 'Alice',
      'role': 'client',
      'pin': '123456'
    },
  };

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    sessions = AuthSessionManager();
    access = OfflineAccess();
    offline = false;
    status = 200;
    writes = 0;
    await sessions.establish({'accessToken': 'a', 'refreshToken': 'r'});
    dio = transport((options) {
      if (options.method != 'GET') writes++;
      if (offline) {
        throw DioException(
            requestOptions: options, type: DioExceptionType.connectionError);
      }
      return jsonBody(
          options.path == '/auth/me'
              ? profile
              : {
                  'parcels': [
                    {
                      'id': options.queryParameters['filter'] ?? 'parcel',
                      'otp': 'secret'
                    }
                  ],
                },
          status);
    });
    dio.interceptors.addAll([
      SessionAuthInterceptor(dio, sessions: sessions),
      OfflineAccessInterceptor(sessions: sessions, access: access),
    ]);
  });

  tearDown(() {
    dio.close();
    access.dispose();
  });

  test('profil restauré depuis le stockage après un redémarrage hors ligne',
      () async {
    await dio.get('/auth/me');
    // Une nouvelle instance ne doit dépendre d'aucune liste en mémoire.
    final restarted = AuthSessionManager();
    dio.interceptors.clear();
    dio.interceptors.addAll([
      SessionAuthInterceptor(dio, sessions: restarted),
      OfflineAccessInterceptor(sessions: restarted, access: access),
    ]);
    offline = true;
    final response = await dio.get('/auth/me');
    expect(response.data['user']['id'], 'alice');
    expect(response.data['user'].containsKey('pin'), false);
    expect(response.extra['offlineCache'], true);
    expect(access.value.disconnected, true);
    expect(access.value.savedAt, isNotNull);
  });

  test('listes envoyées/reçues isolées et secrets retirés', () async {
    for (final filter in ['sent', 'received']) {
      await dio.get('/client/parcels/my-parcels',
          queryParameters: {'filter': filter});
    }
    offline = true;
    for (final filter in ['received', 'sent']) {
      final response = await dio.get('/client/parcels/my-parcels',
          queryParameters: {'filter': filter});
      expect(response.data['parcels'].single['id'], filter);
      expect(response.data['parcels'].single.containsKey('otp'), false);
    }
  });

  test('cache absent signale une indisponibilité, jamais une liste vide',
      () async {
    offline = true;
    await expectLater(
        dio.get('/driver/parcels'),
        throwsA(isA<DioException>().having(
            (e) => e.error, 'message explicite', isA<OfflineUnavailable>())));
    expect(access.value.disconnected, true);
  });

  test('paiements et mutations ne sont pas envoyés en mode hors ligne',
      () async {
    await dio.get('/auth/me');
    offline = true;
    await dio.get('/auth/me');
    await expectLater(dio.post('/payments', data: {'amount': 100}),
        throwsA(isA<DioException>()));
    expect(writes, 0);
  });

  test(
      'le retour du réseau requiert une vérification et conserve les dates des listes anciennes',
      () async {
    await dio.get('/auth/me');
    await dio.get('/driver/parcels');
    offline = true;
    await dio.get('/auth/me');
    await dio.get('/driver/parcels');
    offline = false;
    await dio.get('/auth/me',
        options: Options(extra: {OfflineAccessInterceptor.onlineOnly: true}));
    expect(access.value.disconnected, false);
    expect(access.value.savedAt, isNotNull);
    await dio.get('/driver/parcels');
    expect(access.value.showNotice, false);
  });

  for (final refusal in [403, 404, 503]) {
    test('un refus HTTP $refusal ne devient pas une réussite depuis le cache',
        () async {
      await dio.get('/auth/me');
      status = refusal;
      if (refusal == 503) {
        await expectLater(dio.get('/auth/me'), throwsA(isA<DioException>()));
      } else {
        final response = await dio.get('/auth/me');
        expect(response.statusCode, refusal);
        expect(response.extra['offlineCache'], isNull);
        offline = true;
        await expectLater(dio.get('/auth/me'), throwsA(isA<DioException>()));
      }
    });
  }

  test('un changement de compte ou une déconnexion invalide les copies',
      () async {
    await dio.get('/auth/me');
    final previous = (await sessions.read())!;
    await sessions
        .establish({'accessToken': 'bob', 'refreshToken': 'bob-refresh'});
    expect(await sessions.readCachedResponse(previous.generation, '/auth/me'),
        isNull);
    offline = true;
    await expectLater(dio.get('/auth/me'), throwsA(isA<DioException>()));
    await sessions.clear();
    expect(
        await const FlutterSecureStorage()
            .read(key: AuthSessionManager.offlineCacheKey),
        isNull);
    // Une sauvegarde retardataire de l'ancien compte ne recrée rien.
    await sessions.saveCachedResponse(previous.generation, '/auth/me', profile);
    expect(
        await const FlutterSecureStorage()
            .read(key: AuthSessionManager.offlineCacheKey),
        isNull);
  });

  test('une copie de plus de 30 jours ou corrompue est ignorée', () async {
    final session = (await sessions.read())!;
    const storage = FlutterSecureStorage();
    await storage.write(
        key: AuthSessionManager.offlineCacheKey,
        value: jsonEncode({
          'generation': session.generation,
          'entries': {
            '/auth/me': {
              'savedAt': DateTime.now()
                  .subtract(const Duration(days: 31))
                  .toIso8601String(),
              'data': profile
            }
          },
        }));
    expect(await sessions.readCachedResponse(session.generation, '/auth/me'),
        isNull);
    await storage.write(
        key: AuthSessionManager.offlineCacheKey, value: 'corrompu');
    expect(await sessions.readCachedResponse(session.generation, '/auth/me'),
        isNull);
  });

  test('un accès expiré avec refresh sans réseau permet encore la consultation',
      () async {
    sessions = AuthSessionManager(refreshDio: transport((options) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }));
    final session = (await sessions.read())!;
    await sessions.saveCachedResponse(session.generation, '/auth/me', profile);
    final expiredDio = transport((_) => jsonBody({}, 401));
    expiredDio.interceptors.addAll([
      SessionAuthInterceptor(expiredDio, sessions: sessions),
      OfflineAccessInterceptor(sessions: sessions, access: access),
    ]);
    final result = await expiredDio.get('/auth/me');
    expect(result.data['user']['id'], 'alice');
    expect(access.value.disconnected, true);
    expect(await sessions.read(), isNotNull);
    expiredDio.close();
  });

  test(
      'les espaces administrateurs ne sont pas mis en cache',
      () async {
    await dio.get('/super-admin/wallets');
    offline = true;
    await expectLater(
        dio.get('/super-admin/wallets'), throwsA(isA<DioException>()));
    expect(
        await const FlutterSecureStorage()
            .read(key: AuthSessionManager.offlineCacheKey),
        isNull);
  });
}
