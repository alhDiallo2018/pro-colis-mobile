import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/live_journey.dart';
import 'package:procolis/widgets/live_journeys_map.dart';

Map<String, dynamic> point(String id,
    {bool reverse = false, DateTime? measured}) {
  final time = measured ?? DateTime.now();
  return {
    'advertisementId': id,
    'vehicleReference': id,
    'driverName': 'Chauffeur $id',
    'vehicleModel': 'Tata',
    'lineNumber': '45',
    'departure': {
      'zoneId': reverse ? 'b' : 'a',
      'name': reverse ? 'Keur Massar' : 'Dakar'
    },
    'arrival': {
      'zoneId': reverse ? 'a' : 'b',
      'name': reverse ? 'Dakar' : 'Keur Massar'
    },
    'departureAt': time.toIso8601String(),
    'position': {
      'latitude': 14.7333333,
      'longitude': -17.4123456,
      'accuracyMeters': 8,
      'capturedAt': time.toIso8601String(),
      'expiresAt': time.add(const Duration(seconds: 60)).toIso8601String()
    }
  };
}

void main() {
  test(
      'une mesure périmée ne reste pas en direct et la précision GPS est conservée',
      () {
    final now = DateTime.now();
    final j = LiveJourney.fromJson(point('A', measured: now))!;
    expect(j.longitude, -17.4123456);
    expect(j.accuracy, 8);
    expect(j.isFresh(now), true);
    expect(j.isFresh(now.add(const Duration(seconds: 61))), false);
    expect(
        LiveJourney.fromJson({
          'position': {'latitude': 999}
        }),
        isNull);
  });
  test('50 véhicules 45 conservent chacun leur départ et leur sens', () {
    final journeys = List.generate(50,
        (i) => LiveJourney.fromJson(point('vehicle-$i', reverse: i.isOdd))!);
    expect(journeys.map((j) => j.id).toSet().length, 50);
    expect(journeys.where((j) => j.direction == 'a:b').length, 25);
    expect(journeys.where((j) => j.direction == 'b:a').length, 25);
  });
  testWidgets(
      'la carte distingue les véhicules d’une ligne et retire les positions après une erreur réseau',
      (tester) async {
    var online = true;
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: LiveJourneysMap(
            mapBuilder: (_) => const ColoredBox(color: Colors.white),
            load: (_) async {
              if (!online) throw StateError('offline');
              return [
                point('BUS-A'),
                point('BUS-B', reverse: true),
                point('OLD',
                    measured:
                        DateTime.now().subtract(const Duration(minutes: 2)))
              ];
            })));
    await tester.pumpAndSettle();
    expect(find.text('Ligne 45 · BUS-A'), findsOneWidget);
    expect(find.text('Ligne 45 · BUS-B'), findsOneWidget);
    expect(find.text('Ligne 45 · OLD'), findsNothing);
    expect(tester.takeException(), isNull);
    online = false;
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Ligne 45 · BUS-A'), findsNothing);
    expect(
        find.text(
            'Connexion indisponible. Aucune position actuelle vérifiable.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
