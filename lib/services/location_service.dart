import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';
import 'location_fix.dart';

/// Fréquence d'envoi de la position GPS du chauffeur vers l'API.
///
/// Une position par minute est un bon compromis : assez frais pour le suivi
/// client, sans multiplier inutilement les appels réseau ni vider la batterie.
const Duration kLocationUploadInterval = Duration(seconds: 60);

/// Envoie la position GPS réelle du chauffeur au backend pendant le transport
/// d'un colis.
///
/// Le [parcelId] est obligatoire : sans lui, la position ne peut pas être
/// rattachée au colis transporté (et le client ne peut donc rien suivre). Le
/// service n'est démarré que lorsqu'un colis est réellement en cours de
/// transport, et arrêté dès la livraison ou l'annulation.
class LocationService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Timer? _locationTimer;
  bool _isUpdatingLocation = false;
  String? _activeParcelId;

  /// Colis actuellement suivi, ou `null` si le suivi est arrêté.
  String? get activeParcelId => _activeParcelId;

  bool get isTracking => _locationTimer != null;

  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Délègue à [resolveCurrentPosition] : service vérifié, permission demandée
  /// et délai maximum appliqué, pour ne pas laisser deux logiques de
  /// localisation divergentes dans l'app. Lève un [LocationFailure].
  Future<Position> getCurrentPosition() => resolveCurrentPosition();

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Publie une position pour un colis précis.
  ///
  /// Le backend (`POST /driver/location`) déduit `driverId` du jeton
  /// d'authentification et horodate la position côté serveur ; on lui fournit
  /// donc `parcelId`, `latitude`, `longitude` et, quand elle est connue, la
  /// précision. Aucune coordonnée n'est inventée : tout vient du GPS du
  /// téléphone.
  Future<void> updateLocationOnServer({
    required String parcelId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    try {
      final token = await _storage.read(key: 'token');
      final dio = Dio(BaseOptions(
        baseUrl: ApiService.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      // Le backend expose POST /driver/location (un PUT renvoie 404).
      await dio.post('/driver/location', data: {
        'parcelId': parcelId,
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
      });
    } catch (error, stackTrace) {
      developer.log(
        'Échec de la mise à jour de la position',
        name: 'LocationService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Démarre (ou redémarre) l'envoi périodique de la position pour [parcelId].
  ///
  /// Une première position est publiée immédiatement, puis toutes les
  /// [kLocationUploadInterval]. Relancer avec un autre colis remplace le suivi
  /// précédent : un chauffeur ne transporte qu'un colis à la fois.
  Future<void> startLocationTracking({required String parcelId}) async {
    if (_activeParcelId == parcelId && isTracking) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    stopLocationTracking();
    _activeParcelId = parcelId;

    Future<void> tick() async {
      if (_isUpdatingLocation) return;
      _isUpdatingLocation = true;
      try {
        final position = await resolveCurrentPosition(
          accuracy: LocationAccuracy.medium,
        );
        await updateLocationOnServer(
          parcelId: parcelId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );
      } catch (error, stackTrace) {
        developer.log(
          'Échec du suivi périodique',
          name: 'LocationService',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _isUpdatingLocation = false;
      }
    }

    // Première position sans attendre la première échéance du minuteur.
    unawaited(tick());
    _locationTimer = Timer.periodic(kLocationUploadInterval, (_) => tick());
  }

  /// Arrête l'envoi de positions et oublie le colis suivi.
  void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _activeParcelId = null;
  }

  Future<double> calculateDistance(
      double startLat, double startLng, double endLat, double endLng) async {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) /
        1000;
  }

  Future<String> getAddressFromLatLng(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final street = placemark.street ?? '';
        final locality = placemark.locality ?? '';
        final country = placemark.country ?? '';
        return '$street, $locality, $country';
      }
      return 'Adresse non trouvée';
    } catch (e) {
      return 'Erreur de géocodage: $e';
    }
  }
}
