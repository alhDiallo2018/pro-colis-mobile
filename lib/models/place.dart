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
    this.district,
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

  /// Quartier, arrondissement ou sous-localité. Ce niveau est souvent plus
  /// utile que la ville pour nommer une zone pointée précisément sur la carte.
  final String? district;
  final String? city;
  final String? region;
  final String? country;

  final double? latitude;
  final double? longitude;

  /// Vrai quand les coordonnées sont exploitables.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Nom court à employer pour une zone. Les faux libellés techniques et les
  /// chaînes composées uniquement de coordonnées sont volontairement ignorés.
  String? get zoneName {
    for (final candidate in [name, district, city, region, country]) {
      final clean = _humanLabel(candidate);
      if (clean != null) return clean;
    }

    final address = _clean(formattedAddress);
    if (address == null || _isCoordinateOnly(address)) return null;
    final firstAddressPart = address.split(',').first;
    return _humanLabel(firstAddressPart);
  }

  /// Une sélection cartographique n'est exploitable par l'utilisateur que si
  /// elle contient un vrai nom géographique en plus de ses coordonnées.
  bool get hasGeographicLabel => zoneName != null;

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
    String? district,
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
      district: district ?? this.district,
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

  static String? _humanLabel(String? value) {
    final clean = _clean(value);
    if (clean == null) return null;

    final normalized = clean.toLowerCase();
    const genericLabels = {
      'ma position',
      'position actuelle',
      'current location',
    };
    if (genericLabels.contains(normalized)) return null;

    // Google ou certains géocodeurs natifs peuvent placer "lat, lng" dans le
    // champ `name`. Ce texte est une donnée technique, pas une localité.
    return _isCoordinateOnly(clean) ? null : clean;
  }

  static bool _isCoordinateOnly(String value) {
    final coordinateOnly = RegExp(
      r'^[-+]?\d{1,3}(?:[.,]\d+)?\s*[,;]\s*[-+]?\d{1,3}(?:[.,]\d+)?$',
    );
    return coordinateOnly.hasMatch(value);
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
      district: _pick(list, [
        'neighborhood',
        'sublocality_level_1',
        'sublocality',
        'administrative_area_level_3',
      ]),
      city: _pick(
          list, ['locality', 'postal_town', 'administrative_area_level_2']),
      region: _pick(list, ['administrative_area_level_1']),
      country: _pick(list, ['country']),
      latitude: latitude,
      longitude: longitude,
    );
  }
}
