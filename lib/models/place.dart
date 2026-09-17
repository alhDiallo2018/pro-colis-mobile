/// Modèles des lieux Google (Places / Geocoding).
///
/// Deux niveaux :
///  - [PlaceResult] : une prédiction d'autocomplétion (résultat de recherche) ;
///  - [PlaceDetails] : le lieu résolu complet (nom, adresse, coordonnées),
///    produit par la sélection d'une prédiction ou par un géocodage inverse.
///
/// [PlaceDetails] est l'objet **unique** qui transite entre le champ de
/// recherche et l'écran qui l'utilise : on ne perd plus ni le nom, ni
/// l'adresse, ni les coordonnées, ni le `placeId`.

/// Prédiction renvoyée par l'autocomplétion Google Places.
///
/// `mainText` est le nom du lieu (`Grand Dakar`), `secondaryText` le complément
/// (`Dakar, Sénégal`). `description` est la concaténation lisible des deux.
class PlaceResult {
  const PlaceResult({
    required this.description,
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  final String description;
  final String placeId;
  final String mainText;
  final String secondaryText;

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>?;
    return PlaceResult(
      description: json['description'] as String? ?? '',
      placeId: json['place_id'] as String? ?? '',
      mainText: structured?['main_text'] as String? ?? '',
      secondaryText: structured?['secondary_text'] as String? ?? '',
    );
  }
}

/// Lieu Google résolu, avec toutes les informations utiles à l'affichage et à
/// la géolocalisation.
class PlaceDetails {
  const PlaceDetails({
    this.placeId,
    this.name,
    this.formattedAddress,
    this.city,
    this.region,
    this.country,
    this.latitude,
    this.longitude,
  });

  /// Identifiant stable du lieu chez Google, quand il existe.
  final String? placeId;

  /// Nom réel du lieu sélectionné (`Grand Dakar`, `Gare routière`, ...).
  final String? name;

  /// Adresse complète et compréhensible (`Grand Dakar, Dakar, Sénégal`).
  final String? formattedAddress;

  final String? city;
  final String? region;
  final String? country;

  final double? latitude;
  final double? longitude;

  /// Vrai quand les coordonnées sont exploitables.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Libellé humain lisible, par ordre de priorité :
  ///  1. adresse complète si disponible ;
  ///  2. nom/quartier + ville ;
  ///  3. au minimum ville + pays.
  ///
  /// `null` uniquement quand aucun libellé ne peut être produit.
  String? get label {
    final address = _clean(formattedAddress);
    if (address != null) return address;

    final nameClean = _clean(name);
    final cityClean = _clean(city);
    if (nameClean != null && cityClean != null) return '$nameClean, $cityClean';
    if (nameClean != null) return nameClean;

    final cityCountry =
        [_clean(city), _clean(country)].whereType<String>().join(', ');
    if (cityCountry.isNotEmpty) return cityCountry;
    return null;
  }

  PlaceDetails copyWith({
    String? placeId,
    String? name,
    String? formattedAddress,
    String? city,
    String? region,
    String? country,
    double? latitude,
    double? longitude,
  }) {
    return PlaceDetails(
      placeId: placeId ?? this.placeId,
      name: name ?? this.name,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      city: city ?? this.city,
      region: region ?? this.region,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Les types sont classés du plus précis au plus large : on garde le premier
  /// qui matche pour éviter qu'un département n'écrase une ville.
  static String? _pick(List components, List<String> types) {
    for (final type in types) {
      for (final c in components) {
        final ts = (c['types'] as List?)?.cast<String>() ?? const [];
        if (ts.contains(type)) return c['long_name'] as String?;
      }
    }
    return null;
  }

  /// Construit le lieu à partir des `address_components` renvoyées par Google.
  factory PlaceDetails.fromComponents(
    List? components, {
    String? placeId,
    String? name,
    String? formattedAddress,
    double? latitude,
    double? longitude,
  }) {
    final list = components ?? const [];
    return PlaceDetails(
      placeId: placeId,
      name: name,
      formattedAddress: formattedAddress,
      city: _pick(
          list, ['locality', 'postal_town', 'administrative_area_level_2']),
      region: _pick(list, ['administrative_area_level_1']),
      country: _pick(list, ['country']),
      latitude: latitude,
      longitude: longitude,
    );
  }
}
