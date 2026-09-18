import 'dart:developer' as developer;

import 'package:dio/dio.dart';
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
/// La clé est injectée **une seule fois** via `--dart-define=GOOGLE_MAPS_API_KEY`
/// et lue ici. Aucun écran ne doit la récupérer ailleurs ni la hardcoder.
class PlacesService {
  PlacesService._();

  static const String googleApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Vrai quand une clé a bien été injectée au build. Sans elle, la recherche
  /// Places n'est pas disponible et le géocodage inverse utilise le service
  /// natif du téléphone comme solution de repli.
  static bool get isConfigured => googleApiKey.trim().isNotEmpty;

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static const String _base = 'https://maps.googleapis.com/maps/api';

  /// Autocomplétion Places : renvoie au plus 6 prédictions pour [query].
  ///
  /// Lève un [PlacesApiException] quand l'API répond avec un statut d'erreur
  /// (clé refusée, quota, ...), pour que l'appelant puisse prévenir
  /// l'utilisateur une fois. Renvoie une liste vide si la requête est trop
  /// courte ou si la clé n'est pas configurée.
  static Future<List<PlaceResult>> autocomplete(String query) async {
    final input = query.trim();
    if (input.length < 2 || !isConfigured) return const [];

    final response =
        await _dio.get('$_base/place/autocomplete/json', queryParameters: {
      'input': input,
      'language': 'fr',
      'key': googleApiKey,
    });

    final data = response.data;
    if (response.statusCode == 200 && data['status'] == 'OK') {
      return (data['predictions'] as List)
          .map((p) => PlaceResult.fromJson(p as Map<String, dynamic>))
          .take(6)
          .toList();
    }
    if (data['status'] == 'ZERO_RESULTS') return const [];
    throw PlacesApiException(data['status']?.toString() ?? 'UNKNOWN');
  }

  /// Détails + coordonnées d'un lieu à partir de son `placeId`.
  ///
  /// Renvoie `null` si le lieu est introuvable ou en cas d'erreur : l'appelant
  /// conserve alors les informations déjà saisies (texte, coordonnées).
  static Future<PlaceDetails?> placeDetails(String placeId) async {
    if (placeId.trim().isEmpty || !isConfigured) return null;

    try {
      final response =
          await _dio.get('$_base/place/details/json', queryParameters: {
        'place_id': placeId,
        'fields': 'name,geometry,address_components,formatted_address',
        'language': 'fr',
        'key': googleApiKey,
      });

      final data = response.data;
      if (response.statusCode != 200 || data['status'] != 'OK') return null;

      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) return null;

      final location = result['geometry']?['location'];
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();

      return PlaceDetails.fromComponents(
        result['address_components'] as List?,
        placeId: placeId,
        name: result['name'] as String?,
        formattedAddress: result['formatted_address'] as String?,
        latitude: lat,
        longitude: lng,
      );
    } catch (_) {
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
    if (isConfigured) {
      try {
        final response =
            await _dio.get('$_base/geocode/json', queryParameters: {
          'latlng': '$latitude,$longitude',
          'language': 'fr',
          'key': googleApiKey,
        });

        final data = response.data;
        if (response.statusCode == 200 && data['status'] == 'OK') {
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final first = results.first as Map<String, dynamic>;
            final place = PlaceDetails.fromComponents(
              first['address_components'] as List?,
              placeId: first['place_id'] as String?,
              formattedAddress: first['formatted_address'] as String?,
              latitude: latitude,
              longitude: longitude,
            );
            if (place.hasGeographicLabel) return place;
          }
        }
      } catch (error, stackTrace) {
        developer.log(
          'Le géocodage Google a échoué, utilisation du repli natif',
          name: 'PlacesService',
          error: error,
          stackTrace: stackTrace,
        );
      }
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
      return place.hasGeographicLabel ? place : null;
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
