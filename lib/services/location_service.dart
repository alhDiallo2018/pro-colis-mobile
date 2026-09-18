import 'dart:async';
import 'dart:developer' as developer;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
  LocationService._internal();

  /// Instance applicative unique : le suivi ne doit pas être détruit lorsque
  /// l'utilisateur ferme simplement la fiche d'un colis.
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  final ApiService _api = ApiService();

  Timer? _locationTimer;
  int? _updatingGeneration;
  String? _activeParcelId;
  int _trackingGeneration = 0;

  /// Colis actuellement suivi, ou `null` si le suivi est arrêté.
  String? get activeParcelId => _activeParcelId;

  bool get isTracking => _locationTimer != null;

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
      // Réutilise le client API authentifié : même jeton, même refresh de
      // session et même politique d'erreurs que les autres appels métier.
      await _api.updateDriverLocation(
        parcelId: parcelId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Échec de la mise à jour de la position',
        name: 'LocationService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Démarre (ou redémarre) l'envoi périodique de la position pour [parcelId].
  ///
  /// Une première position est publiée immédiatement, puis toutes les
  /// [kLocationUploadInterval]. Relancer avec un autre colis remplace le suivi
  /// précédent : un chauffeur ne transporte qu'un colis à la fois.
  Future<void> startLocationTracking({required String parcelId}) async {
    if (_activeParcelId == parcelId &&
        (isTracking || _updatingGeneration == _trackingGeneration)) {
      return;
    }

    stopLocationTracking();
    _activeParcelId = parcelId;
    final generation = _trackingGeneration;

    Future<void> tick({bool propagateError = false}) async {
      if (_updatingGeneration == generation ||
          generation != _trackingGeneration ||
          _activeParcelId != parcelId) {
        return;
      }
      _updatingGeneration = generation;
      try {
        final position = await resolveCurrentPosition(
          accuracy: LocationAccuracy.medium,
        );
        // Le suivi peut avoir été coupé pendant l'acquisition GPS. Dans ce
        // cas, ne jamais publier une position devenue orpheline.
        if (generation != _trackingGeneration || _activeParcelId != parcelId) {
          return;
        }
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
        if (propagateError) rethrow;
      } finally {
        if (_updatingGeneration == generation) {
          _updatingGeneration = null;
        }
      }
    }

    // La première acquisition est attendue : si le GPS ou l'autorisation est
    // indisponible, l'appelant reçoit l'erreur et aucun faux suivi actif ne
    // reste affiché en mémoire.
    try {
      await tick(propagateError: true);
    } catch (error, stackTrace) {
      stopLocationTracking();
      developer.log(
        'Impossible de démarrer le suivi GPS',
        name: 'LocationService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
    _locationTimer = Timer.periodic(kLocationUploadInterval, (_) => tick());
  }

  /// Arrête l'envoi de positions et oublie le colis suivi.
  void stopLocationTracking() {
    _trackingGeneration++;
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
    } catch (error, stackTrace) {
      developer.log(
        'Géocodage inverse impossible',
        name: 'LocationService',
        error: error,
        stackTrace: stackTrace,
      );
      return 'Adresse indisponible pour le moment';
    }
  }
}
