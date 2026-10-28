import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/providers/auth_provider.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/services/auth_session.dart';
import 'package:procolis/services/api_service.dart';

class CallbackAdapter implements HttpClientAdapter {
  CallbackAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object data, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(data), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Dio transport(FutureOr<ResponseBody> Function(RequestOptions) respond) =>
    Dio(BaseOptions(
        baseUrl: 'https://session.test',
        validateStatus: (status) => status != null && status < 500))
      ..httpClientAdapter = CallbackAdapter(respond);

class OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const SocketException('Test offline');
}

class RestoreApi extends ApiService {
  RestoreApi(this.load);
  Future<User> Function() load;
  @override
  Future<User> getCurrentUser() => load();
  @override
  Future<User> reconnectUser() => load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<SessionTokens> establish(AuthSessionManager manager,
      [String suffix = 'old']) async {
    await manager.establish(
        {'accessToken': 'access-$suffix', 'refreshToken': 'refresh-$suffix'});
    return (await manager.read())!;
  }

  test(
      'migre les anciennes cles et conserve un couple atomique puis un tombstone au logout',
      () async {
    FlutterSecureStorage.setMockInitialValues(
        {'token': 'access-old', 'refresh_token': 'refresh-old'});
    final manager = AuthSessionManager();
    expect((await manager.read())!.refreshToken, 'refresh-old');
    expect(await storage.read(key: 'token'), isNull);
    expect(await storage.read(key: AuthSessionManager.storageKey),
        contains('refresh-old'));
    await manager.clear();
    // Meme une ancienne cle residuelle ne doit pas restaurer une deconnexion.
    await storage.write(key: 'token', value: 'stale');
    expect(await manager.read(), isNull);
  });

  test('deux clients HTTP partagent un seul refresh et rejouent /auth/me',
      () async {
    var refreshes = 0;
    final manager = AuthSessionManager(refreshDio: transport((_) {
      refreshes++;
      return jsonBody(
          {'accessToken': 'access-new', 'refreshToken': 'refresh-new'});
    }));
    await establish(manager);
    Dio client() {
      final dio = transport((options) =>
          options.headers['Authorization'] == 'Bearer access-old'
              ? jsonBody({}, 401)
              : jsonBody({'success': true}));
      dio.interceptors.add(SessionAuthInterceptor(dio, sessions: manager));
      return dio;
    }

    final responses = await Future.wait(
        [client().get('/auth/me'), client().get('/client/parcels')]);
    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(refreshes, 1);
    expect((await manager.read())!.refreshToken, 'refresh-new');
  });

  test('un 401 tardif reutilise le couple deja renouvele', () async {
    var refreshes = 0;
    final manager = AuthSessionManager(refreshDio: transport((_) {
      refreshes++;
      return jsonBody(
          {'accessToken': 'access-new', 'refreshToken': 'refresh-new'});
    }));
    final old = await establish(manager);
    await manager.refresh(old);
    expect((await manager.refresh(old)).accessToken, 'access-new');
    expect(refreshes, 1);
  });

  for (final failure in [429, 503, 0]) {
    test('une erreur temporaire $failure preserve les jetons', () async {
      final manager = AuthSessionManager(refreshDio: transport((options) {
        if (failure == 0)
          throw DioException(
              requestOptions: options, type: DioExceptionType.connectionError);
        return jsonBody({}, failure);
      }));
      final old = await establish(manager);
      await expectLater(manager.refresh(old), throwsA(isA<DioException>()));
      expect((await manager.read())!.refreshToken, 'refresh-old');
    });
  }

  test('un refresh definitivement refuse ferme la session une fois', () async {
    final manager =
        AuthSessionManager(refreshDio: transport((_) => jsonBody({}, 401)));
    var expired = 0;
    manager.onExpired = () => expired++;
    final old = await establish(manager);
    await expectLater(Future.wait([manager.refresh(old), manager.refresh(old)]),
        throwsA(isA<SessionExpiredException>()));
    expect(await manager.read(), isNull);
    expect(expired, 1);
  });

  test('une reponse malformee preserve les jetons', () async {
    final manager =
        AuthSessionManager(refreshDio: transport((_) => jsonBody({})));
    final old = await establish(manager);
    await expectLater(manager.refresh(old), throwsA(isA<FormatException>()));
    expect((await manager.read())!.refreshToken, 'refresh-old');
  });

  test('une reponse de refresh tardive ne ressuscite pas un logout', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final manager = AuthSessionManager(refreshDio: transport((_) async {
      started.complete();
      await release.future;
      return jsonBody(
          {'accessToken': 'access-new', 'refreshToken': 'refresh-new'});
    }));
    final old = await establish(manager);
    final pending = expectLater(
        manager.refresh(old), throwsA(isA<SessionChangedException>()));
    await started.future;
    await manager.clear();
    release.complete();
    await pending;
    expect(await manager.read(), isNull);
  });

  test('un ancien refresh refuse ne ferme pas une nouvelle connexion',
      () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final manager = AuthSessionManager(refreshDio: transport((_) async {
      started.complete();
      await release.future;
      return jsonBody({}, 401);
    }));
    final old = await establish(manager);
    final pending = expectLater(
        manager.refresh(old), throwsA(isA<SessionChangedException>()));
    await started.future;
    await establish(manager, 'other-user');
    release.complete();
    await pending;
    expect((await manager.read())!.refreshToken, 'refresh-other-user');
  });

  test('la restauration reprend sans PIN apres le retour du reseau', () async {
    await establish(AuthSessionManager.instance);
    final api = RestoreApi(() async => throw const SocketException('offline'));
    final notifier = AuthNotifier(apiService: api);
    try {
      for (var i = 0; i < 100 && notifier.state.isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(notifier.state.hasPendingSession, true);
      api.load = () async => User.fromJson({
            'id': 'user-a',
            'fullName': 'Test',
            'phone': '770000000',
            'role': 'client'
          });
      await notifier.retrySessionRestoration();
      expect(notifier.state.isAuthenticated, true);
      expect(notifier.state.hasPendingSession, false);
      expect((await AuthSessionManager.instance.read())!.refreshToken,
          'refresh-old');
    } finally {
      notifier.dispose();
      ApiService.onSessionExpired = null;
    }
  });

  test('le demarrage hors ligne propose de reessayer sans effacer la session',
      () async {
    final previous = HttpOverrides.current;
    HttpOverrides.global = OfflineHttpOverrides();
    await establish(AuthSessionManager.instance);
    final notifier = AuthNotifier();
    try {
      for (var i = 0; i < 100 && notifier.state.isLoading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(notifier.state.hasPendingSession, true);
      expect(notifier.state.isAuthenticated, false);
      expect((await AuthSessionManager.instance.read())!.refreshToken,
          'refresh-old');
      await notifier.retrySessionRestoration();
      expect(notifier.state.hasPendingSession, true);
      expect((await AuthSessionManager.instance.read())!.refreshToken,
          'refresh-old');
    } finally {
      notifier.dispose();
      ApiService.onSessionExpired = null;
      HttpOverrides.global = previous;
    }
  });
}
