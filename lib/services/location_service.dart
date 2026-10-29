import 'dart:async';
import 'dart:developer' as developer;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'background_location.dart';
import 'location_fix.dart';

const Duration kLocationUploadInterval = Duration(seconds: 10);

/// Un seul flux GPS pour tous les colis transportés par le chauffeur.
/// Fermer une fiche ou livrer un colis ne coupe pas les autres livraisons.
class LocationService {
  LocationService._internal() : _api = ApiService();

  /// Injection destinée aux tests du flux natif et des réponses métier.
  LocationService.forTesting(ApiService api) : _api = api;
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  final ApiService _api;
  final Set<String> _parcelIds = {};
  StreamSubscription<Position>? _positions;
  Timer? _gpsRetry;
  Future<void>? _starting;
  int _generation = 0;
  int? _uploadingGeneration;
  DateTime? _lastSent;

  String? get activeParcelId => _parcelIds.firstOrNull;
  Set<String> get activeParcelIds => Set.unmodifiable(_parcelIds);
  bool get isTracking => _positions != null;

  Future<Position> getCurrentPosition() => resolveCurrentPosition();
  Stream<Position> getPositionStream() => Geolocator.getPositionStream(
        locationSettings: backgroundLocationSettings(
          title: 'ProColis · livraison en cours',
          text: 'La position de vos colis est partagée jusqu’à leur livraison.',
        ),
      );

  Future<void> updateLocationOnServer(
          {required String parcelId,
          required double latitude,
          required double longitude,
          double? accuracy,
          DateTime? capturedAt}) =>
      _api.updateDriverLocation(
          parcelId: parcelId,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          capturedAt: capturedAt);

  Future<void> syncLocationTracking(
      {required Iterable<String> parcelIds}) async {
    final next = parcelIds.toSet();
    _parcelIds.removeWhere((id) => !next.contains(id));
    _parcelIds.addAll(next);
    if (_parcelIds.isEmpty) {
      stopLocationTracking();
      return;
    }
    await _ensureStarted();
  }

  Future<void> startLocationTracking({required String parcelId}) async {
    _parcelIds.add(parcelId);
    await _ensureStarted();
  }

  Future<void> _ensureStarted() async {
    if (isTracking) return;
    final starting = _starting;
    if (starting != null) return starting;
    final generation = _generation;
    final pending = _start(generation);
    _starting = pending;
    try {
      await pending;
    } finally {
      if (identical(_starting, pending)) _starting = null;
    }
  }

  Future<void> _start(int generation) async {
    try {
      final first = await resolveCurrentPosition();
      if (generation != _generation || _parcelIds.isEmpty) return;
      _positions = getPositionStream().listen(
        (p) => unawaited(_publish(p, generation)),
        onError: (Object error, StackTrace stack) {
          if (generation != _generation) return;
          _log('Flux GPS interrompu', error, stack);
          _waitForGps();
        },
        onDone: () {
          if (generation == _generation) _waitForGps();
        },
      );
      _gpsRetry?.cancel();
      _gpsRetry = null;
      await _publish(first, generation);
    } catch (error, stack) {
      if (generation == _generation) _waitForGps();
      _log('Impossible de démarrer le suivi GPS', error, stack);
      rethrow;
    }
  }

  Future<void> _publish(Position position, int generation) async {
    if (generation != _generation ||
        _uploadingGeneration == generation ||
        !isRecentPosition(position) ||
        (_lastSent != null &&
            position.timestamp.difference(_lastSent!) <
                kLocationUploadInterval)) return;
    _uploadingGeneration = generation;
    try {
      for (final id in _parcelIds.toList()) {
        if (generation != _generation || !isRecentPosition(position)) return;
        if (!_parcelIds.contains(id)) continue;
        try {
          await updateLocationOnServer(
              parcelId: id,
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              capturedAt: position.timestamp);
        } catch (error, stack) {
          _log('Envoi GPS différé', error, stack);
          // Le serveur fait autorité : une mission livrée, annulée ou réaffectée
          // est retirée même lorsque sa fiche n’est plus ouverte sur le mobile.
          if (error is ApiException &&
              {403, 404, 409}.contains(error.statusCode) &&
              generation == _generation) _parcelIds.remove(id);
        }
      }
      if (generation == _generation) {
        _lastSent = position.timestamp;
        if (_parcelIds.isEmpty) stopLocationTracking();
      }
    } finally {
      if (_uploadingGeneration == generation) _uploadingGeneration = null;
    }
  }

  /// Un tunnel ou un GPS temporairement coupé ne termine pas la mission.
  /// Les reprises automatiques utilisent seulement une permission déjà accordée.
  void _waitForGps() {
    _generation++;
    final positions = _positions;
    _positions = null;
    _starting = null;
    _lastSent = null;
    if (positions != null) unawaited(positions.cancel());
    if (_parcelIds.isEmpty) return;
    _gpsRetry ??= Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_parcelIds.isEmpty || _positions != null || _starting != null) return;
      try {
        final permission = await Geolocator.checkPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) return;
        if (!await Geolocator.isLocationServiceEnabled()) return;
        await _ensureStarted();
      } catch (error, stack) {
        _log('Reprise GPS différée', error, stack);
      }
    });
  }

  void stopLocationTracking({String? parcelId}) {
    if (parcelId != null) {
      _parcelIds.remove(parcelId);
      if (_parcelIds.isNotEmpty) return;
    }
    _generation++;
    _gpsRetry?.cancel();
    _gpsRetry = null;
    final subscription = _positions;
    _positions = null;
    _starting = null;
    _lastSent = null;
    _parcelIds.clear();
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _log(String message, Object error, StackTrace stack) =>
      developer.log(message,
          name: 'LocationService', error: error.runtimeType, stackTrace: stack);

  Future<double> calculateDistance(double startLat, double startLng,
          double endLat, double endLng) async =>
      Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;

  Future<String> getAddressFromLatLng(double latitude, double longitude) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return 'Adresse non trouvée';
      final p = places.first;
      return '${p.street ?? ''}, ${p.locality ?? ''}, ${p.country ?? ''}';
    } catch (error, stack) {
      _log('Géocodage inverse impossible', error, stack);
      return 'Adresse indisponible pour le moment';
    }
  }
}
