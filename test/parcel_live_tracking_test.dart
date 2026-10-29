import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/driver_location.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/widgets/parcel_live_tracking_card.dart';

final now = DateTime.utc(2026, 10, 29, 20);
Parcel parcel(
        {String number = 'PC-GPS-A',
        ParcelStatus status = ParcelStatus.inTransit,
        double? latitude = 14.7,
        DateTime? recordedAt}) =>
    Parcel(
      id: number,
      trackingNumber: number,
      senderName: 'Awa',
      senderPhone: '',
      receiverName: 'Mamadou',
      receiverPhone: '',
      description: 'Colis',
      weight: 2,
      type: ParcelType.package,
      status: status,
      departureZoneId: 'dakar',
      departureZoneName: 'Dakar',
      arrivalZoneName: 'Thiès',
      createdAt: now,
      driverLocation: latitude == null
          ? null
          : DriverLocation(
              latitude: latitude,
              longitude: -17.4,
              accuracy: 8,
              recordedAt: recordedAt ?? now),
    );

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required Future<Parcel> Function(String) load,
    Parcel? initial,
    ValueChanged<Parcel>? updated,
  }) async {
    tester.view.physicalSize = const Size(360, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: ParcelLiveTrackingCard(
          parcel: initial ?? parcel(),
          load: load,
          now: () => now,
          onUpdated: updated,
          mapBuilder: (_, location) => Text(
              location == null ? 'aucun GPS' : 'marqueur ${location.latitude}',
              key: const ValueKey('marker')),
        )))));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('la carte suit les nouvelles coordonnées puis affiche l’arrivée',
      (tester) async {
    var calls = 0;
    final updates = <ParcelStatus>[];
    await mount(tester,
        load: (_) async {
          calls++;
          return calls == 1
              ? parcel(latitude: 14.71)
              : parcel(latitude: 14.8, status: ParcelStatus.arrived);
        },
        updated: (p) => updates.add(p.status));
    expect(find.text('marqueur 14.71'), findsOneWidget);
    expect(find.text('En direct'), findsOneWidget);
    await tester.pump(kParcelTrackingRefreshInterval);
    await tester.pumpAndSettle();
    expect(find.text('marqueur 14.8'), findsOneWidget);
    expect(find.text('Colis arrivé'), findsOneWidget);
    expect(updates, [ParcelStatus.inTransit, ParcelStatus.arrived]);
    await close(tester);
  });
  testWidgets(
      'la livraison arrête le polling et masque la position du chauffeur',
      (tester) async {
    var calls = 0;
    await mount(tester, load: (_) async {
      calls++;
      return parcel(status: ParcelStatus.delivered);
    });
    expect(find.text('aucun GPS'), findsOneWidget);
    expect(find.text('En direct'), findsNothing);
    await tester.pump(const Duration(seconds: 30));
    expect(calls, 1);
    await close(tester);
  });
  testWidgets(
      'réseau coupé : dernière position conservée, retour automatique au direct',
      (tester) async {
    var online = false;
    await mount(tester, load: (_) async {
      if (!online) throw StateError('offline');
      return parcel(latitude: 14.9);
    });
    expect(find.text('Connexion interrompue'), findsOneWidget);
    expect(find.text('En direct'), findsNothing);
    expect(find.text('marqueur 14.7'), findsOneWidget);
    online = true;
    await tester.pump(kParcelTrackingRefreshInterval);
    await tester.pumpAndSettle();
    expect(find.text('En direct'), findsOneWidget);
    expect(find.text('marqueur 14.9'), findsOneWidget);
    await close(tester);
  });
  testWidgets(
      'une position ancienne ou future ne porte jamais la mention en direct',
      (tester) async {
    final old = parcel(recordedAt: now.subtract(const Duration(minutes: 3)));
    await mount(tester, initial: old, load: (_) async => old);
    expect(find.text('Dernière position connue'), findsOneWidget);
    expect(find.text('En direct'), findsNothing);
    await close(tester);
    final future = parcel(recordedAt: now.add(const Duration(minutes: 1)));
    await mount(tester, initial: future, load: (_) async => future);
    expect(find.text('En direct'), findsNothing);
    await close(tester);
  });
  testWidgets('les requêtes lentes ne se chevauchent pas', (tester) async {
    final pending = Completer<Parcel>();
    var calls = 0;
    await mount(tester, load: (_) {
      calls++;
      return pending.future;
    });
    await tester.pump(const Duration(seconds: 20));
    expect(calls, 1);
    pending.complete(parcel());
    await tester.pumpAndSettle();
    await tester.pump(kParcelTrackingRefreshInterval);
    await tester.pumpAndSettle();
    expect(calls, 2);
    await close(tester);
  });
  testWidgets('la réponse d’un ancien colis ne remplace pas le nouveau suivi',
      (tester) async {
    final pending = Completer<Parcel>();
    await mount(tester, load: (_) => pending.future);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: ParcelLiveTrackingCard(
          parcel: parcel(number: 'PC-GPS-B', latitude: 14.95),
          now: () => now,
          load: (_) async => parcel(number: 'PC-GPS-B', latitude: 14.96),
          mapBuilder: (_, location) => Text('nouveau ${location?.latitude}'),
        )))));
    await tester.pumpAndSettle();
    pending.complete(parcel(latitude: 14.1));
    await tester.pumpAndSettle();
    expect(find.text('nouveau 14.96'), findsOneWidget);
    expect(find.text('marqueur 14.1'), findsNothing);
    await close(tester);
  });
  testWidgets('sans GPS aucune coordonnée fictive n’est affichée',
      (tester) async {
    await mount(tester,
        initial: parcel(latitude: null),
        load: (_) async => parcel(latitude: null));
    expect(find.text('aucun GPS'), findsOneWidget);
    expect(find.text('En attente du GPS'), findsOneWidget);
    expect(find.textContaining('GPS :'), findsNothing);
    await close(tester);
  });
  testWidgets('la fraîcheur expire aussi pendant une requête bloquée',
      (tester) async {
    var clock = now;
    final pending = Completer<Parcel>();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: ParcelLiveTrackingCard(
          parcel: parcel(),
          now: () => clock,
          load: (_) => pending.future,
          mapBuilder: (_, location) => const SizedBox(),
        )))));
    await tester.pumpAndSettle();
    expect(find.text('En direct'), findsOneWidget);
    clock = now.add(const Duration(minutes: 3));
    await tester.pump(kParcelTrackingRefreshInterval);
    await tester.pumpAndSettle();
    expect(find.text('En direct'), findsNothing);
    expect(find.text('Dernière position connue'), findsOneWidget);
    await close(tester);
    pending.complete(parcel());
    await tester.pump();
  });
}
