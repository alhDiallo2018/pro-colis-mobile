// ignore_for_file: avoid_print

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';

class LocationService {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Timer? _locationTimer;

  Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<Position> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Permission de localisation refusée');
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

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

      await dio.put('/driver/location', data: {
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (e) {
      print('LocationService: échec mise à jour position — $e');
    }
  }

  Future<void> startLocationTracking() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    stopLocationTracking();

    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.balanced,
          ),
        );
        await updateLocationOnServer(
          position.latitude,
          position.longitude,
        );
      } catch (e) {
        print('LocationService: échec tracking — $e');
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
