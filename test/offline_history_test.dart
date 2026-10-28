import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/auth_session.dart';
import 'package:procolis/services/offline_access.dart';

class HistoryAdapter implements HttpClientAdapter {
  bool disconnected = false;
  int status = 200;
  int requests = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests++;
    if (disconnected) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(
        jsonEncode({
          'success': status == 200,
          'items': [options.uri.toString()],
          'deliveryCode': '123456',
        }),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthSessionManager sessions;
  late OfflineAccess access;
  late HistoryAdapter adapter;
  late Dio dio;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    sessions = AuthSessionManager();
    await sessions
        .establish({'accessToken': 'access', 'refreshToken': 'refresh'});
    access = OfflineAccess();
    adapter = HistoryAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://offline.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      options.extra['authSession'] = await sessions.read();
      handler.next(options);
    }));
    dio.interceptors
        .add(OfflineAccessInterceptor(sessions: sessions, access: access));
  });

  tearDown(() {
    dio.close();
    access.dispose();
  });

  for (final path in [
    '/client/parcels/my-parcels',
    '/driver/parcels',
    '/client/parcels/parcel-1',
    '/driver/parcels/parcel-1',
    '/parcels/parcel-1/timeline',
    '/users/stats',
    '/driver/stats',
    '/client/bids/received',
    '/driver/bids/sent',
    '/driver/proposals',
    '/payments/history',
    '/driver/wallet',
    '/driver/cash-declarations',
    '/client/debts',
    '/score/history',
    '/notifications',
    '/addresses',
    '/favorites/zones',
    '/driver/vehicle',
  ]) {
    test('consulte $path hors ligne après chargement', () async {
      await dio.get(path);
      adapter.disconnected = true;
      final cached = await dio.get(path);
      expect(cached.extra['offlineCache'], true);
      expect(cached.data['items'], isNotEmpty);
      expect(cached.data.containsKey('deliveryCode'), false);
      expect(access.value.disconnected, true);
      expect(access.value.savedAt, isNotNull);
    });
  }

  test('ne confond pas les pages et refuse les écritures sans réseau',
      () async {
    await dio.get('/payments/history', queryParameters: {'page': 1});
    adapter.disconnected = true;
    await dio.get('/payments/history', queryParameters: {'page': 1});
    final before = adapter.requests;
    await expectLater(
        dio.get('/payments/history', queryParameters: {'page': 2}),
        throwsA(isA<DioException>()));
    await expectLater(
        dio.post('/payments/history'), throwsA(isA<DioException>()));
    expect(adapter.requests, before);
  });

  for (final path in [
    '/super-admin/users',
    '/client/parcels/p1/delivery-code',
    '/driver/parcels/p1/commission',
    '/public/parcels/free'
  ]) {
    test('ne met pas $path en cache', () async {
      await dio.get(path);
      adapter.disconnected = true;
      await expectLater(dio.get(path), throwsA(isA<DioException>()));
    });
  }

  for (final status in [401, 403, 404, 500]) {
    test('ne masque pas un refus HTTP $status avec le cache', () async {
      await dio.get('/payments/history');
      adapter.status = status;
      await expectLater(
          dio.get('/payments/history'), throwsA(isA<DioException>()));
      expect(access.value.showNotice, false);
    });
  }

  test('une nouvelle session ne peut pas relire les données précédentes',
      () async {
    await dio.get('/payments/history');
    await sessions
        .establish({'accessToken': 'other', 'refreshToken': 'other-refresh'});
    adapter.disconnected = true;
    await expectLater(
        dio.get('/payments/history'), throwsA(isA<DioException>()));
  });
}
