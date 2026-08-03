// Vérifie le branchement de `resolveCurrentPosition` en simulant la
// plateforme geolocator : chaque état de l'appareil doit produire l'échec
// correspondant — et surtout, une acquisition qui n'aboutit jamais doit
// s'arrêter au bout du délai au lieu de figer l'appelant.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:procolis/services/location_fix.dart';

class _FakeGeolocator extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.always,
    this.permissionAfterRequest,
    this.position,
    this.throwOnGet,
    this.neverCompletes = false,
  });

  final bool serviceEnabled;
  LocationPermission permission;
  final LocationPermission? permissionAfterRequest;
  final Position? position;
  final Object? throwOnGet;
  final bool neverCompletes;

  int requestPermissionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    if (permissionAfterRequest != null) permission = permissionAfterRequest!;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    if (neverCompletes) {
      // Reproduit un simulateur sans position simulée : la plateforme ne
      // répond jamais. Seul le `timeLimit` peut sortir de là.
      final limit = locationSettings?.timeLimit;
      if (limit == null) return Completer<Position>().future;
      return Future.delayed(limit, () => throw TimeoutException('timeout'));
    }
    if (throwOnGet != null) return Future.error(throwOnGet!);
    return Future.value(position ?? _position());
  }
}

Position _position({double lat = 14.6928, double lng = -17.4467}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  test('renvoie la position quand tout est en ordre', () async {
    GeolocatorPlatform.instance = _FakeGeolocator(position: _position());

    final position = await resolveCurrentPosition();
    expect(position.latitude, closeTo(14.6928, 0.0001));
    expect(position.longitude, closeTo(-17.4467, 0.0001));
  });

  test('service coupé → serviceDisabled, sans demander la permission',
      () async {
    final fake = _FakeGeolocator(serviceEnabled: false);
    GeolocatorPlatform.instance = fake;

    final failure = await _failureOf(resolveCurrentPosition());
    expect(failure.kind, LocationFailureKind.serviceDisabled);
    expect(fake.requestPermissionCalls, 0,
        reason: 'inutile de solliciter l’utilisateur si le GPS est coupé');
  });

  test('permission à demander : elle est demandée, puis la position arrive',
      () async {
    final fake = _FakeGeolocator(
      permission: LocationPermission.denied,
      permissionAfterRequest: LocationPermission.whileInUse,
    );
    GeolocatorPlatform.instance = fake;

    final position = await resolveCurrentPosition();
    expect(fake.requestPermissionCalls, 1);
    expect(position.latitude, closeTo(14.6928, 0.0001));
  });

  test('refus simple → permissionDenied', () async {
    GeolocatorPlatform.instance = _FakeGeolocator(
      permission: LocationPermission.denied,
      permissionAfterRequest: LocationPermission.denied,
    );

    final failure = await _failureOf(resolveCurrentPosition());
    expect(failure.kind, LocationFailureKind.permissionDenied);
    expect(failure.needsSettings, isFalse);
  });

  test('refus définitif → renvoie vers les réglages', () async {
    GeolocatorPlatform.instance =
        _FakeGeolocator(permission: LocationPermission.deniedForever);

    final failure = await _failureOf(resolveCurrentPosition());
    expect(failure.kind, LocationFailureKind.permissionDeniedForever);
    expect(failure.needsSettings, isTrue);
  });

  test('acquisition sans réponse → timeout, l’appelant n’est jamais figé',
      () async {
    GeolocatorPlatform.instance = _FakeGeolocator(neverCompletes: true);

    final failure = await _failureOf(
      resolveCurrentPosition(timeLimit: const Duration(milliseconds: 40)),
    );
    expect(failure.kind, LocationFailureKind.timeout);
  });

  test('erreur plateforme inattendue → unknown, message neutre', () async {
    GeolocatorPlatform.instance = _FakeGeolocator(
      throwOnGet: Exception('PlatformException(kCLErrorDomain, 1, null)'),
    );

    final failure = await _failureOf(resolveCurrentPosition());
    expect(failure.kind, LocationFailureKind.unknown);
    expect(failure.message, isNot(contains('kCLErrorDomain')));
  });

  test('service coupé pendant l’acquisition → serviceDisabled', () async {
    GeolocatorPlatform.instance = _FakeGeolocator(
      throwOnGet: const LocationServiceDisabledException(),
    );

    final failure = await _failureOf(resolveCurrentPosition());
    expect(failure.kind, LocationFailureKind.serviceDisabled);
  });
}

/// Attend l'échec et le renvoie, en échouant le test si l'appel réussit.
Future<LocationFailure> _failureOf(Future<Position> future) async {
  try {
    await future;
  } on LocationFailure catch (failure) {
    return failure;
  }
  fail('un LocationFailure était attendu');
}
