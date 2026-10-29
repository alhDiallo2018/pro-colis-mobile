import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/providers/parcel_provider.dart';
import 'package:procolis/screens/parcel/track_parcel_screen.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/widgets/parcel_tracking_summary.dart';

Parcel shipment(
        {ParcelStatus status = ParcelStatus.inTransit,
        String description =
            'Documents administratifs dans une enveloppe renforcée'}) =>
    Parcel(
        id: 'parcel-visible',
        trackingNumber: 'PC-20261029-ABCD',
        senderName: 'Awa',
        senderPhone: '',
        receiverName: 'Mamadou Ndiaye',
        receiverPhone: '',
        description: description,
        weight: 2.5,
        type: ParcelType.document,
        status: status,
        departureZoneId: 'dakar',
        departureZoneName: 'Dakar · Plateau',
        arrivalZoneName: 'Saint-Louis · Sor',
        createdAt: DateTime.utc(2026, 10, 29));

class TrackingNotifier extends ParcelNotifier {
  @override
  Future<Parcel?> trackParcel(String trackingNumber) async => shipment();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    for (final channel in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });
  for (final width in [320.0, 390.0]) {
    for (final dark in [false, true]) {
      testWidgets(
          'fiche entière à ${width}px, thème ${dark ? 'sombre' : 'clair'}',
          (tester) async {
        AppTheme.applyBrightness(dark ? Brightness.dark : Brightness.light);
        addTearDown(() => AppTheme.applyBrightness(Brightness.light));
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var details = 0;
        await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ParcelTrackingSummary(
                        parcel: shipment(),
                        onDetails: () => details++,
                        onReceipt: () {},
                        onShare: () {})))));
        expect(tester.takeException(), isNull);
        expect(find.text('Dakar · Plateau'), findsOneWidget);
        expect(find.text('Saint-Louis · Sor'), findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(
            find.byKey(const ValueKey('tracking-parcel-description')));
        expect(paragraph.didExceedMaxLines, false);
        await tester.ensureVisible(find.text('Détails du colis'));
        await tester.tap(find.text('Détails du colis'));
        expect(details, 1);
      });
    }
  }
  testWidgets('grands caractères, description et lieux longs sans troncature',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SingleChildScrollView(
                    child: ParcelTrackingSummary(
                        parcel: shipment(
                            description:
                                'Matériel de bureau et documents à remettre directement au destinataire à son arrivée'),
                        onDetails: () {},
                        onReceipt: () {},
                        onShare: () {}))))));
    expect(tester.takeException(), isNull);
    final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('tracking-parcel-description')));
    expect(paragraph.didExceedMaxLines, false);
  });
  testWidgets(
      'le colis trouvé remplace la recherche et reste visible en haut de page',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          parcelProvider.overrideWith((ref) => TrackingNotifier()),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const TrackParcelScreen(
                embedded: true, trackingNumber: 'PC-20261029-ABCD'))));
    await tester.pumpAndSettle();
    expect(find.byType(ParcelTrackingSummary), findsOneWidget);
    expect(find.text('Suivre un colis'), findsNothing);
    expect(tester.getTopLeft(find.text('Votre colis')).dy, lessThan(180));
    expect(find.text('Documents administratifs dans une enveloppe renforcée'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Suivre le colis sur la carte'));
    await tester.tap(find.text('Suivre le colis sur la carte'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('parcel-gps-card'))).dy,
        lessThan(740));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
