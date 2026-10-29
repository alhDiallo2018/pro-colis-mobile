import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/services/background_location.dart';
import 'package:procolis/services/location_service.dart';

Position fix(int secondsAgo) => Position(
    latitude: 14.7,
    longitude: -17.4,
    timestamp: DateTime.now().subtract(Duration(seconds: secondsAgo)),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0);

class Gps extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  final positions = StreamController<Position>.broadcast();
  Completer<Position>? acquisition;
  LocationSettings? settings;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      acquisition == null ? fix(30) : await acquisition!.future;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return positions.stream;
  }
}

class DeliveryApi extends ApiService {
  final sent = <String>[];
  final failures = <String, int>{};
  @override
  Future<void> updateDriverLocation(
      {required String parcelId,
      required double latitude,
      required double longitude,
      double? accuracy,
      DateTime? capturedAt}) async {
    sent.add(parcelId);
    if (failures.containsKey(parcelId))
      throw ApiException('test', failures[parcelId]!);
  }
}

Future<void> flush() async {
  for (var i = 0; i < 5; i++) await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Gps gps;
  late DeliveryApi api;
  late LocationService service;
  final previous = GeolocatorPlatform.instance;
  setUp(() {
    gps = Gps();
    GeolocatorPlatform.instance = gps;
    api = DeliveryApi();
    service = LocationService.forTesting(api);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() async {
    service.stopLocationTracking();
    await gps.positions.close();
    GeolocatorPlatform.instance = previous;
    debugDefaultTargetPlatformOverride = null;
  });
  test(
      'Android conserve un service natif avec notification et verrou de veille',
      () async {
    await service.syncLocationTracking(parcelIds: ['a', 'b']);
    final settings = gps.settings as AndroidSettings;
    expect(settings.foregroundNotificationConfig!.enableWakeLock, true);
    expect(settings.foregroundNotificationConfig!.setOngoing, true);
    expect(api.sent, ['a', 'b']);
    service.stopLocationTracking(parcelId: 'a');
    expect(service.isTracking, true);
    gps.positions.add(fix(15));
    await flush();
    expect(api.sent, ['a', 'b', 'b']);
  });
  test('une livraison achevée est retirée, les autres colis continuent',
      () async {
    await service.syncLocationTracking(parcelIds: ['a', 'b']);
    api.failures['a'] = 409;
    gps.positions.add(fix(15));
    await flush();
    expect(service.activeParcelIds, {'b'});
    api.failures['b'] = 409;
    gps.positions.add(fix(0));
    await flush();
    expect(service.isTracking, false);
  });
  test('429 conserve le suivi et la prochaine mesure réessaie', () async {
    api.failures['a'] = 429;
    await service.startLocationTracking(parcelId: 'a');
    expect(service.isTracking, true);
    api.failures.clear();
    gps.positions.add(fix(10));
    await flush();
    expect(api.sent, ['a', 'a']);
    expect(service.activeParcelIds, {'a'});
  });
  test('arrêter pendant l’acquisition empêche tout envoi et redémarrage tardif',
      () async {
    gps.acquisition = Completer<Position>();
    final start = service.startLocationTracking(parcelId: 'a');
    await flush();
    service.stopLocationTracking();
    gps.acquisition!.complete(fix(0));
    await start;
    expect(service.isTracking, false);
    expect(api.sent, isEmpty);
  });
  test('mesures anciennes ou futures et événements après déconnexion ignorés',
      () async {
    await service.startLocationTracking(parcelId: 'a');
    gps.positions.add(fix(120));
    gps.positions.add(fix(-20));
    await flush();
    service.stopLocationTracking();
    gps.positions.add(fix(0));
    await flush();
    expect(api.sent, ['a']);
  });
  testWidgets('une interruption GPS reprend sans perdre les colis suivis',
      (tester) async {
    await service.syncLocationTracking(parcelIds: ['a', 'b']);
    gps.positions
        .addError(const LocationServiceDisabledException(), StackTrace.current);
    await tester.pump();
    expect(service.activeParcelIds, {'a', 'b'});
    expect(service.isTracking, false);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(service.isTracking, true);
    expect(api.sent, ['a', 'b', 'a', 'b']);
    debugDefaultTargetPlatformOverride = null;
  });
  test('iOS continue sans pause automatique avec indicateur système', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final settings = backgroundLocationSettings(title: 'test', text: 'test')
        as AppleSettings;
    expect(settings.pauseLocationUpdatesAutomatically, false);
    expect(settings.allowBackgroundLocationUpdates, true);
    expect(settings.showBackgroundLocationIndicator, true);
  });
}
