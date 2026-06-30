// ignore_for_file: avoid_print

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  
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

  Future<void> updateLocationOnServer(double latitude, double longitude, String parcelId) async {
    print('📍 Position mise à jour: $latitude, $longitude pour le colis $parcelId');
  }

  Future<double> calculateDistance(double startLat, double startLng, double endLat, double endLng) async {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
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