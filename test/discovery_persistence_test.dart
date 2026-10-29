import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/services/auth_session.dart';
import 'package:procolis/services/driver_discovery_service.dart';
import 'background_tracking_test.dart' show Gps, fix, flush;

class DiscoveryApi extends ApiService {
  final sent = <bool>[];
  bool fail = false;
  @override
  Future<void> shareDiscoveryPosition(
      {required bool enabled,
      required SessionTokens session,
      double? latitude,
      double? longitude}) async {
    sent.add(enabled);
    if (fail) throw ApiException('offline', 503);
  }
}

class ToggleGps extends Gps {
  bool enabled = true;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ToggleGps gps;
  late DiscoveryApi api;
  late DriverDiscoveryService sharing;
  final oldGps = GeolocatorPlatform.instance;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await AuthSessionManager.instance
        .establish({'accessToken': 'a', 'refreshToken': 'r'});
    gps = ToggleGps();
    GeolocatorPlatform.instance = gps;
    api = DiscoveryApi();
    sharing = DriverDiscoveryService.forTesting(api);
  });
  tearDown(() async {
    await sharing.suspend();
    sharing.dispose();
    await gps.positions.close();
    GeolocatorPlatform.instance = oldGps;
    await AuthSessionManager.instance.clear();
  });
  test('le choix reste mémorisé après suspension et réouverture', () async {
    await sharing.start(userId: 'driver-a');
    expect(sharing.value, true);
    expect(
        (await SharedPreferences.getInstance())
            .getBool(DriverDiscoveryService.preferenceKey('driver-a')),
        true);
    await sharing.suspend();
    final reopened = DriverDiscoveryService.forTesting(api);
    await reopened.restoreForUser('driver-a', available: true);
    expect(reopened.value, true);
    expect(api.sent.where((value) => value).length, 2);
    await reopened.suspend();
    reopened.dispose();
  });
  test('une désactivation manuelle persiste et aucune reprise ne republie',
      () async {
    await sharing.start(userId: 'driver-a');
    await sharing.stop();
    expect(sharing.value, false);
    final before = api.sent.length;
    await sharing.resume();
    await sharing.restoreForUser('driver-a', available: true);
    expect(sharing.value, false);
    expect(api.sent.length, before);
    expect(
        (await SharedPreferences.getInstance())
            .getBool(DriverDiscoveryService.preferenceKey('driver-a')),
        false);
  });
  test('GPS coupé : activation conservée et reprise automatique', () async {
    gps.enabled = false;
    await sharing.start(userId: 'driver-a');
    expect(sharing.value, true);
    expect(sharing.error, contains('Partage activé'));
    expect(api.sent, isEmpty);
    gps.enabled = true;
    await sharing.resume();
    expect(sharing.value, true);
    expect(sharing.error, isNull);
    expect(api.sent, [true]);
  });
  test('erreur réseau : le choix et le flux restent actifs', () async {
    api.fail = true;
    await sharing.start(userId: 'driver-a');
    expect(sharing.value, true);
    api.fail = false;
    gps.positions.add(fix(0));
    await flush();
    expect(sharing.value, true);
    expect(sharing.error, isNull);
    expect(api.sent, [true, true]);
  });
  test('la préférence d’un compte ne se transmet pas à un autre', () async {
    await sharing.start(userId: 'driver-a');
    await sharing.restoreForUser('driver-b', available: true);
    expect(sharing.value, false);
    expect(
        (await SharedPreferences.getInstance())
            .getBool(DriverDiscoveryService.preferenceKey('driver-a')),
        true);
    final before = api.sent.where((value) => value).length;
    gps.positions.add(fix(0));
    await flush();
    expect(api.sent.where((value) => value).length, before);
  });
  test('indisponibilité temporaire et déconnexion ne suppriment pas le choix',
      () async {
    await sharing.start(userId: 'driver-a');
    await sharing.restoreForUser('driver-a', available: false);
    expect(sharing.value, true);
    await sharing.restoreForUser(null, available: false);
    expect(sharing.value, false);
    await sharing.restoreForUser('driver-a', available: true);
    expect(sharing.value, true);
  });
}
