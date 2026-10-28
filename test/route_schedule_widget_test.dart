import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:procolis/screens/driver/route_templates_screen.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/services/route_schedule_store.dart';

void main() {
  const template = {
    'id': 'template',
    'name': 'Ligne 45 · Dakar → Keur Massar',
    'data': {
      'availableWeight': 20,
      'proposedPrice': 500,
      'itinerary': {
        'lineNumber': '45',
        'serviceType': 'shuttle',
        'stops': [
          {'zoneId': 'a', 'name': 'Dakar', 'offsetMinutes': 0},
          {'zoneId': 'b', 'name': 'Keur Massar', 'offsetMinutes': 10}
        ]
      }
    }
  };
  testWidgets(
      'publier 50 départs exige le bouton final et une reprise conserve la même demande',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Map<String, dynamic>>[];
    int? published;
    final store = RouteScheduleStore('test-driver');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    child: const Text('Planifier'),
                    onPressed: () async {
                      published = await showModalBottomSheet<int>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => RouteScheduleSheet(
                              template: template,
                              store: store,
                              multiple: true,
                              publish: (id, payload) async {
                                requests
                                    .add(Map<String, dynamic>.from(payload));
                                if (requests.length == 1)
                                  throw const ApiException(
                                      'Réponse perdue', 503);
                                return {'count': 50};
                              }));
                    })))));
    await tester.tap(find.text('Planifier'));
    await tester.pumpAndSettle();
    final count = find.byWidgetPredicate((w) =>
        w is TextField &&
        w.decoration?.labelText == 'Nombre de départs (1 à 100)');
    await tester.ensureVisible(count);
    await tester.enterText(count, '50');
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.text('Publier 50 départs'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Publier 50 départs'));
    await tester.pumpAndSettle();
    expect(requests.length, 1);
    expect(await store.load(), isNotNull);
    expect(find.text('Vérifier / réessayer'), findsOneWidget);
    await tester.tap(find.text('Vérifier / réessayer'));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(requests[0], requests[1]);
    expect((requests[0]['departures'] as List).length, 50);
    expect(requests[0]['proposedPrice'], isNull);
    expect(published, 50);
    expect(await store.load(), isNull);
    expect(tester.takeException(), isNull);
  });
}
