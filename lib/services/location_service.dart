import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';
import 'location_fix.dart';

class LocationService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Timer? _locationTimer;
  bool _isUpdatingLocation = false;

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

  Future<void> updateLocationOnServer(
      double latitude, double longitude) async {
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
        'latitude': latitude,
        'longitude': longitude,
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

  Future<void> startLocationTracking() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    stopLocationTracking();

    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      // La géolocalisation et l'appel HTTP peuvent approcher l'intervalle de
      // polling : empêcher deux mises à jour concurrentes évite les doublons.
      if (_isUpdatingLocation) return;
      _isUpdatingLocation = true;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
        await updateLocationOnServer(
          position.latitude,
          position.longitude,
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
    });
  }

  void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
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
