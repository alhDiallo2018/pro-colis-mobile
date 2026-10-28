import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:procolis/services/auth_session.dart';
import 'auth_session_test.dart' show transport, jsonBody;
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/models/vehicle_type.dart';
import 'package:procolis/utils/driver_visibility.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  User driver(String id, double? distance,
          {bool verified = false,
          DriverStatus status = DriverStatus.available}) =>
      User(
          id: id,
          email: '',
          phone: '',
          fullName: id,
          role: UserRole.driver,
          distanceKm: distance,
          driverStatus: status,
          isVerified: verified,
          createdAt: DateTime.utc(2026));
  test('proximité avant réputation, positions inconnues en dernier', () {
    final result = visibleDrivers([
      driver('unknown', null, verified: true),
      driver('far', 10, verified: true),
      driver('near', 0.5),
      driver('busy', 0.1, status: DriverStatus.busy),
    ], availableOnly: true, nearestFirst: true);
    expect(result.map((d) => d.id), ['near', 'far', 'unknown']);
  });
  test('filtre vérifié combiné à disponibilité et proximité', () {
    final result = visibleDrivers([
      driver('near', 0.5),
      driver('far', 10, verified: true),
      driver('offline', 0.1, verified: true, status: DriverStatus.offline),
    ], availableOnly: true, verifiedOnly: true, nearestFirst: true);
    expect(result.map((d) => d.id), ['far']);
  });
  test('six catégories et compatibilité avec les anciennes saisies', () {
    expect(vehicleTypes.length, 6);
    expect(vehicleTypeCode('Moto'), 'motorcycle');
    expect(vehicleTypeLabel('van'), 'Fourgonnette');
    expect(vehicleTypeCode('Tata'), 'bus');
    expect(vehicleTypeCode('horaire'), 'bus');
    expect(vehicleTypeCode('GP'), 'gp');
  });
  test('le partage GPS renouvelle un jeton expiré sans fermer la session',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final manager = AuthSessionManager(
        refreshDio: transport((_) => jsonBody(
            {'accessToken': 'fresh', 'refreshToken': 'fresh-refresh'})));
    await manager
        .establish({'accessToken': 'old', 'refreshToken': 'old-refresh'});
    final session = await manager.read();
    final dio = transport((options) =>
        options.headers['Authorization'] == 'Bearer old'
            ? jsonBody({}, 401)
            : jsonBody({'success': true}));
    dio.interceptors.add(SessionAuthInterceptor(dio, sessions: manager));
    final response = await dio.put('/driver/discovery-location',
        options: Options(
            extra: {'authSession': session, 'authSessionPinned': true}));
    expect(response.statusCode, 200);
    expect((await manager.read())?.accessToken, 'fresh');
    dio.close();
  });
  test('un envoi GPS ancien ne touche pas le nouveau compte', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final manager = AuthSessionManager();
    await manager
        .establish({'accessToken': 'old', 'refreshToken': 'old-refresh'});
    final old = await manager.read();
    await manager
        .establish({'accessToken': 'other', 'refreshToken': 'other-refresh'});
    var calls = 0;
    final dio = transport((_) {
      calls++;
      return jsonBody({'success': true});
    });
    dio.interceptors.add(SessionAuthInterceptor(dio, sessions: manager));
    await expectLater(
        dio.put('/driver/discovery-location',
            options: Options(
                extra: {'authSession': old, 'authSessionPinned': true})),
        throwsA(isA<DioException>()));
    expect(calls, 0);
    expect((await manager.read())?.accessToken, 'other');
    dio.close();
  });
}
