import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/services/auth_session.dart';
import 'package:procolis/services/offline_access.dart';
import 'auth_session_test.dart' show transport, jsonBody;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthSessionManager.instance
        .establish({'accessToken': 'a', 'refreshToken': 'r'});
    final session = (await AuthSessionManager.instance.read())!;
    OfflineAccess.instance.useSession(session.generation);
    OfflineAccess.instance.failed();
  });
  tearDown(() async {
    await AuthSessionManager.instance.clear();
    OfflineAccess.instance.useSession(null);
  });
  test(
      'GPS du chauffeur et liste des missions réessaient après une coupure réseau',
      () async {
    final requests = <String>[];
    final capturedAt = DateTime.now().toUtc();
    final dio = transport((options) {
      requests.add(options.path);
      expect(options.extra[OfflineAccessInterceptor.onlineOnly], true);
      if (options.path == '/driver/location') {
        expect(options.data['capturedAt'], capturedAt.toIso8601String());
      }
      return jsonBody({
        'success': true,
        'parcelIds': ['a', 'b']
      });
    });
    final api = ApiService(dioOverride: dio);
    await api.updateDriverLocation(
        parcelId: 'a',
        latitude: 14.7,
        longitude: -17.4,
        capturedAt: capturedAt);
    expect(await api.getActiveTrackingParcelIds(), ['a', 'b']);
    final session = (await AuthSessionManager.instance.read())!;
    await api.shareDiscoveryPosition(
        enabled: true, session: session, latitude: 14.7, longitude: -17.4);
    expect(requests, [
      '/driver/location',
      '/driver/tracking-parcels',
      '/driver/discovery-location'
    ]);
    dio.close();
  });
  test(
      'le suivi léger conserve les détails locaux et efface le GPS à la livraison',
      () async {
    final original = Parcel(
        id: 'a',
        trackingNumber: 'PC-A',
        senderName: 'Awa',
        senderPhone: '',
        receiverName: 'Mamadou',
        receiverPhone: '',
        description: 'Documents',
        weight: 2,
        type: ParcelType.document,
        status: ParcelStatus.inTransit,
        departureZoneId: 'd',
        departureZoneName: 'Dakar',
        createdAt: DateTime.now());
    var delivered = false;
    final dio = transport((options) => jsonBody({
          'success': true,
          'trackingNumber': 'PC-A',
          'status': delivered ? 'delivered' : 'in_transit',
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'driverLocation': delivered
              ? {'available': false}
              : {
                  'available': true,
                  'latitude': 14.8,
                  'longitude': -17.4,
                  'updatedAt': DateTime.now().toUtc().toIso8601String()
                },
        }));
    final api = ApiService(dioOverride: dio);
    final inTransit = await api.trackParcelPosition(original);
    expect(inTransit.description, 'Documents');
    expect(inTransit.driverLocation!.latitude, 14.8);
    delivered = true;
    final finished = await api.trackParcelPosition(inTransit);
    expect(finished.status, ParcelStatus.delivered);
    expect(finished.driverLocation, isNull);
    dio.close();
  });
}
