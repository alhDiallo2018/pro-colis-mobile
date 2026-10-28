import 'package:procolis/models/user.dart';
import 'package:procolis/utils/parcel_offer_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/advertisement.dart';
import 'package:procolis/widgets/trip_plan_editor.dart';
import 'package:procolis/widgets/journey_stops_card.dart';

void main() {
  final stops = List.generate(
      3,
      (i) => {
            'zoneId': '$i',
            'name': ['Keur Massar', 'Arrêt A', 'Parcelles'][i],
            'offsetMinutes': i * 30,
            'scheduledAt': DateTime.now()
                .add(Duration(hours: 2, minutes: i * 30))
                .toIso8601String()
          });
  final data = {
    'id': 'trip',
    'availableWeight': 10,
    'itinerary': {'serviceType': 'shuttle', 'lineNumber': '45', 'stops': stops}
  };
  test('ma zone inclut les arrêts intermédiaires', () {
    final user = User(
        id: 'u',
        email: '',
        phone: '',
        fullName: 'Client',
        role: UserRole.client,
        city: 'Arrêt A',
        createdAt: DateTime.now());
    expect(advertisementMatchesUserZone(Advertisement.fromJson(data), user),
        isTrue);
  });
  test('navette : recherche dans le sens des arrêts et contrôle du poids', () {
    final ad = Advertisement.fromJson(data);
    expect(ad.serviceLabel, 'Navette · ligne 45');
    expect(ad.serves('1', '2', weight: 6), isTrue);
    expect(ad.serves('2', '1', weight: 6), isFalse);
    expect(ad.serves('1', '2', weight: 11), isFalse);
    expect(ad.serves('unknown', '2'), isFalse);
  });
  test('restauration du formulaire conserve les escales et les horaires', () {
    final plan = tripPlanFromItinerary(data['itinerary'])!;
    final restored = itineraryFromTripPlan(plan, '0', '2');
    expect(restored['lineNumber'], '45');
    expect((restored['stops'] as List).map((s) => s['zoneId']).toList(),
        ['0', '1', '2']);
    expect((restored['stops'] as List).last['offsetMinutes'], 60);
    expect(tripPlanFromItinerary(null), isNull);
  });
  testWidgets(
      'le détail affiche les trois arrêts et la ligne sans inventer de GPS',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child:
                    JourneyStopsCard(journey: Advertisement.fromJson(data))))));
    expect(find.text('Navette · ligne 45'), findsOneWidget);
    expect(find.text('Arrêt A'), findsOneWidget);
    expect(find.text('Voir les arrêts sur la carte'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('la catégorie GP du profil est affichée sans être redemandée',
      (tester) async {
    Map<String, dynamic>? changed;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TripPlanEditor(
                    value: const {'serviceType': 'gp'},
                    zones: const [],
                    onChanged: (v) => changed = v)))));
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('GP · transport de colis'), findsOneWidget);
    expect(changed, isNull);
    expect(tester.takeException(), isNull);
  });
}
