import 'dart:developer' as developer;

import 'api/client.dart';
import 'package:geocoding/geocoding.dart';

import '../models/place.dart';

/// Erreur renvoyée quand Google répond avec un statut autre que `OK` ou
/// `ZERO_RESULTS` (clé invalide, quota dépassé, billing non activé, ...).
class PlacesApiException implements Exception {
  const PlacesApiException(this.status);

  final String status;

  /// Vrai quand le problème vient de la clé / du projet Google Cloud.
  bool get isConfigError =>
      status == 'REQUEST_DENIED' || status == 'INVALID_REQUEST';

  @override
  String toString() => 'PlacesApiException($status)';
}

/// Accès centralisé aux APIs HTTP Google Maps utilisées par l'application :
/// autocomplétion Places, détails d'un lieu et géocodage inverse.
///
/// Les appels passent par notre API : la clé serveur ne dépend plus d'un
/// --dart-define oublié et les restrictions navigateur ne bloquent pas Places.
class PlacesService {
  PlacesService._();
  static final ApiClient _client = ApiClient();

  static Future<dynamic> _get(String path, Map<String, dynamic> params) async {
    final response =
        await _client.dio.get('/public/places/$path', queryParameters: params);
    final data = _client.handle(response);
    if (data['success'] != true) {
      throw PlacesApiException(data['error']?['code']?.toString() ?? 'UNKNOWN');
    }
    return data['data'];
  }

  /// Autocomplétion mondiale Places pour [query].
  ///
  /// Lève un [PlacesApiException] quand l'API répond avec un statut d'erreur
  /// (clé refusée, quota, ...), pour que l'appelant puisse prévenir
  /// l'utilisateur une fois. Renvoie une liste vide si la requête est trop
  /// courte. La configuration de la clé est gérée par le serveur.
  static Future<List<PlaceResult>> autocomplete(String query,
      {String? sessionToken}) async {
    final input = query.trim();
    if (input.length < 2) return const [];
    final data = await _get('autocomplete', {
      'input': input,
      if (sessionToken != null) 'sessionToken': sessionToken
    });
    return (data as List)
        .map((p) => PlaceResult.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  /// Normalise le même contrat pour une suggestion et un point cartographique.
  static PlaceDetails _parse(Map<String, dynamic> result) {
    final location = result['geometry']?['location'];
    return PlaceDetails.fromComponents(result['address_components'] as List?,
        placeId: result['place_id'] as String?,
        name: result['name'] as String?,
        formattedAddress: result['formatted_address'] as String?,
        latitude: (location?['lat'] as num?)?.toDouble(),
        longitude: (location?['lng'] as num?)?.toDouble());
  }

  static Future<PlaceDetails?> placeDetails(String placeId,
      {String? sessionToken}) async {
    if (placeId.trim().isEmpty) return null;
    try {
      final data = await _get('details', {
        'placeId': placeId,
        if (sessionToken != null) 'sessionToken': sessionToken
      });
      return data is Map ? _parse(Map<String, dynamic>.from(data)) : null;
    } catch (error, stackTrace) {
      developer.log('Détails du lieu indisponibles',
          name: 'PlacesService',
          error: error is PlacesApiException ? error : error.runtimeType,
          stackTrace: stackTrace);
      return null;
    }
  }

  /// Géocodage inverse d'un point GPS, pour afficher un libellé lisible au
  /// lieu des seules coordonnées.
  ///
  /// Google est prioritaire, puis le géocodeur natif du téléphone prend le
  /// relais. `null` signifie qu'aucun nom géographique fiable n'a été trouvé :
  /// l'interface ne doit jamais remplacer ce nom par de simples coordonnées.
  static Future<PlaceDetails?> reverseGeocode(
      double latitude, double longitude) async {
    try {
      final data =
          await _get('reverse', {'latitude': latitude, 'longitude': longitude});
      if (data is Map) {
        final place = _parse(Map<String, dynamic>.from(data));
        if (place.hasGeographicLabel) return place.copyWith(exactPoint: true);
      }
    } catch (error, stackTrace) {
      developer.log('Géocodage indisponible, utilisation du repli natif',
          name: 'PlacesService',
          error: error.runtimeType,
          stackTrace: stackTrace);
    }

    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final placemark = placemarks.first;
      final addressParts = <String?>[
        placemark.street,
        placemark.subLocality,
        placemark.locality,
        placemark.administrativeArea,
        placemark.country,
      ];
      // Plusieurs niveaux administratifs portent parfois la même valeur. On
      // les déduplique pour produire une adresse naturelle et stable.
      final seen = <String>{};
      final address = addressParts
          .map((part) => part?.trim())
          .whereType<String>()
          .where((part) => part.isNotEmpty && seen.add(part.toLowerCase()))
          .join(', ');

      final place = PlaceDetails(
        formattedAddress: address.isEmpty ? null : address,
        district: placemark.subLocality,
        city: (placemark.locality?.trim().isNotEmpty ?? false)
            ? placemark.locality
            : placemark.subAdministrativeArea,
        region: placemark.administrativeArea,
        country: placemark.country,
        latitude: latitude,
        longitude: longitude,
      );
      return place.hasGeographicLabel ? place.copyWith(exactPoint: true) : null;
    } catch (error, stackTrace) {
      developer.log(
        'Aucun géocodeur n’a pu résoudre la localité',
        name: 'PlacesService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
