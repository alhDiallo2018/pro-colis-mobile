import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/driver_discovery.dart';
import 'package:procolis/models/garage.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/widgets/delivery_discovery_view.dart';

Garage place(String id, double lat) => Garage(
    id: id,
    name: id,
    city: 'Dakar',
    region: 'Dakar',
    latitude: lat,
    longitude: -17.45,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026));
NearbyDriver driver(String id, {String type = 'motorcycle', DateTime? date}) =>
    NearbyDriver(
        user: User(
            id: id,
            email: '',
            phone: '',
            fullName: id,
            role: UserRole.driver,
            driverStatus: DriverStatus.available,
            vehicleType: type,
            vehicleCapacity: 25,
            distanceKm: .4,
            rating: 4.8,
            createdAt: DateTime.utc(2026)),
        latitude: 14.701,
        longitude: -17.451,
        updatedAt: date ?? DateTime.now());
DriverMapResult result([String id = 'Awa']) => DriverMapResult(
    drivers: [driver(id)],
    counts: const {'motorcycle': 1, 'truck': 0},
    total: 1);

void main() {
  // La liste des chauffeurs vit dans un ListView paresseux (DraggableScrollableSheet
  // ou panneau compact selon la hauteur). On fait défiler jusqu'au driver au
  // lieu d'`ensureVisible`, qui ne peut rien contre une entrée pas encore bâtie.
  Future<void> revealDriver(WidgetTester tester, String name) async {
    final scrollable = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    try {
      await tester.scrollUntilVisible(find.text(name), 120,
          scrollable: scrollable);
    } catch (_) {
      // Déjà visible ou pas dans cette liste : laisser le test lever lui-même.
    }
    // Laisse le scrollable libérer son hold avant la prochaine interaction :
    // sans ces frames, un tap/rebuild immédiat déclenche l'assert `_hold == null`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> mount(WidgetTester tester,
      {Garage? pickup,
      required Future<DriverMapResult> Function(DriverDiscoveryQuery) load,
      ValueChanged<DeliveryDiscoverySelection>? onChanged,
      double textScale = 1}) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(
                size: const Size(430, 900),
                textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
                body: DeliveryDiscoveryView(
              zones: [place('Retrait', 14.7), place('Arrivée', 14.8)],
              initial: DeliveryDiscoverySelection(
                  pickup: pickup, destination: place('Arrivée', 14.8)),
              onChanged: onChanged ?? (_) {},
              loadDrivers: load,
              mapBuilder: (_) => const ColoredBox(color: Color(0xffe7eeeb)),
            )))));
    // Timer.periodic(30s) empêche pumpAndSettle : on fait tourner les
    // microtâches et la première recherche sans jamais atteindre les 30s.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('aucune position inventée, aucun appel avant le choix du retrait',
      (tester) async {
    var calls = 0;
    await mount(tester, load: (_) async {
      calls++;
      return result();
    });
    expect(calls, 0);
    expect(find.text('Où récupérer le colis ?'), findsOneWidget);
    expect(find.text('Un véhicule pour votre colis'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'recherche autour du retrait, sélection unique et offre non envoyée',
      (tester) async {
    DriverDiscoveryQuery? query;
    DeliveryDiscoverySelection? selection;
    await mount(tester,
        pickup: place('Retrait', 14.7),
        load: (q) async {
          query = q;
          return result();
        },
        onChanged: (v) => selection = v);
    expect(query!.latitude, 14.7);
    expect(query!.radiusKm, 10);
    await revealDriver(tester, 'Awa');
    await tester.tap(find.text('Awa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(selection!.driver!.id, 'Awa');
    expect(selection!.openForOffers, false);
    expect(find.text('Votre chauffeur'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('un ancien résultat ne remplace pas le nouveau filtre',
      (tester) async {
    final truck = Completer<DriverMapResult>();
    final moto = Completer<DriverMapResult>();
    var calls = 0;
    await mount(tester, pickup: place('Retrait', 14.7), load: (q) {
      calls++;
      if (q.vehicleType == 'truck') return truck.future;
      if (q.vehicleType == 'motorcycle') return moto.future;
      return Future.value(result());
    });
    await tester.tap(find.text('Camion'));
    await tester.pump();
    await tester.tap(find.text('Moto'));
    await tester.pump();
    moto.complete(result('Nouveau'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    truck.complete(result('Ancien'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 3);
    await revealDriver(tester, 'Nouveau');
    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.text('Ancien'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'une erreur réseau retire les résultats et propose une nouvelle vérification',
      (tester) async {
    var online = true;
    DeliveryDiscoverySelection? selection;
    await mount(tester,
        pickup: place('Retrait', 14.7),
        load: (_) async {
          if (!online) throw StateError('network');
          return result();
        },
        onChanged: (v) => selection = v);
    await revealDriver(tester, 'Awa');
    await tester.tap(find.text('Awa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    online = false;
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(selection!.driver, isNull);
    expect(find.text('Awa'), findsNothing);
    expect(
        find.text(
            'Connexion indisponible. Actualisez pour vérifier les chauffeurs.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('grands caractères : liste lisible sans débordement',
      (tester) async {
    await mount(tester,
        pickup: place('Retrait', 14.7),
        load: (_) async => result(),
        textScale: 2);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test(
      'les points invalides et périmés ne deviennent pas des chauffeurs sur carte',
      () {
    expect(
        NearbyDriver.fromJson({
          'mapPosition': {'latitude': 120, 'longitude': 0},
          'locationUpdatedAt': DateTime.now().toIso8601String()
        }),
        isNull);
    final old = driver('old',
        date: DateTime.now().subtract(const Duration(minutes: 11)));
    expect(old.isFresh(DateTime.now()), false);
  });
}
