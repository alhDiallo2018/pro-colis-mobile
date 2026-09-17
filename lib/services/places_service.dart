import 'package:dio/dio.dart';

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

  /// Vrai quand une clé a bien été injectée au build. Sans elle, les appels
  /// Places / Geocoding renvoient `REQUEST_DENIED` et l'interface doit se
  /// replier sur la saisie manuelle ou sur « Position actuelle ».
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

    final response = await _dio.get('$_base/place/autocomplete/json',
        queryParameters: {
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
      final response = await _dio.get('$_base/place/details/json',
          queryParameters: {
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
  /// Renvoie `null` si aucun résultat ou en cas d'erreur : l'appelant affiche
  /// alors un repli explicite (« Position actuelle ») sans perdre les
  /// coordonnées.
  static Future<PlaceDetails?> reverseGeocode(
      double latitude, double longitude) async {
    if (!isConfigured) return null;

    try {
      final response = await _dio.get('$_base/geocode/json', queryParameters: {
        'latlng': '$latitude,$longitude',
        'language': 'fr',
        'key': googleApiKey,
      });

      final data = response.data;
      if (response.statusCode != 200 || data['status'] != 'OK') return null;

      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      return PlaceDetails.fromComponents(
        first['address_components'] as List?,
        placeId: first['place_id'] as String?,
        formattedAddress: first['formatted_address'] as String?,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      return null;
    }
  }
}
