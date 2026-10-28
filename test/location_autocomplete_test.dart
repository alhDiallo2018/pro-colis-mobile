import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:procolis/widgets/location_autocomplete.dart';

final requests = <Uri>[];
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    HttpOverrides.global = _PlacesHttpOverrides();
  });
  tearDown(() => HttpOverrides.global = null);
  Future<void> mount(
      WidgetTester tester, TextEditingController controller) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      LocationAutocomplete(
          controller: controller, label: 'Ville', showGeolocate: false),
      const TextField(decoration: InputDecoration(labelText: 'Autre champ')),
    ]))));
  }

  testWidgets('ne recherche pas une ville enregistrée au montage ou au focus',
      (tester) async {
    final controller = TextEditingController(text: 'Dakar, Sénégal');
    await mount(tester, controller);
    await tester.tap(find.byType(TextFormField));
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests, isEmpty);
    expect(controller.text, 'Dakar, Sénégal');
    expect(find.text('Recherche du lieu…'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('ne recherche pas une ville renseignée par un autre champ',
      (tester) async {
    final controller = TextEditingController();
    await mount(tester, controller);
    controller.text = 'Thiès, Sénégal';
    await tester.pump(const Duration(milliseconds: 500));
    expect(requests, isEmpty);
    expect(controller.text, 'Thiès, Sénégal');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
      'cherche une saisie puis ferme définitivement les choix après sélection',
      (tester) async {
    final controller = TextEditingController();
    await mount(tester, controller);
    await tester.enterText(find.byType(TextFormField), 'Daka');
    await tester.pump(const Duration(milliseconds: 310));
    await tester.pumpAndSettle();
    expect(
        requests.where((u) => u.path.endsWith('/autocomplete')), hasLength(1));
    expect(find.text('Dakar'), findsOneWidget);
    await tester.tap(find.text('Dakar'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Dakar, Sénégal');
    await tester.tap(find.widgetWithText(TextField, 'Autre champ'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byType(TextFormField));
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
        requests.where((u) => u.path.endsWith('/autocomplete')), hasLength(1));
    expect(find.text('Dakar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

class _PlacesHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add(url);
    return _FakeHttpRequest();
  }

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
        utf8.encode(jsonEncode({
          'success': true,
          'data': [
            {
              'place_id': 'dakar',
              'description': 'Dakar, Sénégal',
              'structured_formatting': {
                'main_text': 'Dakar',
                'secondary_text': 'Sénégal'
              }
            }
          ]
        })),
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
