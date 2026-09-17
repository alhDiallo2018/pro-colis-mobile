// test/helpers/mock_http.dart
//
// Override HTTP factice pour les tests de widgets. `flutter_test` bloque le
// vrai réseau en renvoyant un corps vide (400), ce qui fait échouer
// `jsonDecode('')` dans `ApiService.getAllZones` (FormatException). On fournit
// ici une réponse JSON 200 valide, conforme au contrat de `GET /public/zones`.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('HttpClient.${invocation.memberName}');
}

class _FakeHttpRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  Future<HttpClientResponse> close() async => _FakeHttpResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('HttpClientRequest.${invocation.memberName}');
}

class _FakeHttpResponse implements HttpClientResponse {
  final Stream<Uint8List> _body = Stream<Uint8List>.fromIterable(
    <Uint8List>[
      Uint8List.fromList(
        utf8.encode('{"success":true,"message":"Zones actives","data":[]}'),
      ),
    ],
  );

  @override
  int get statusCode => 200;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  String get reasonPhrase => 'OK';

  @override
  X509Certificate? get certificate => null;

  @override
  Stream<R> cast<R>() => _body.cast<R>();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('HttpClientResponse.${invocation.memberName}');
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('HttpHeaders.${invocation.memberName}');
}
