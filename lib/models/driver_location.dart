// lib/models/driver_location.dart
//
// Position GPS réelle d'un chauffeur pendant le transport d'un colis.
//
// Le backend est la source de vérité : ces coordonnées sont celles que le
// chauffeur transmet via `POST /driver/location` et que l'API renvoie ensuite
// au client dans le suivi du colis. Aucune coordonnée n'est inventée côté
// mobile — si le backend ne fournit pas de position, `DriverLocation` reste
// absent (null) et l'interface affiche l'indisponibilité.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

DateTime? _parseDateTime(dynamic v) =>
    v != null ? DateTime.tryParse(v.toString()) : null;

class DriverLocation {
  final String? id;
  final String? driverId;
  final String? parcelId;
  final double latitude;
  final double longitude;
  final double? accuracy;

  /// Horodatage de la position. Le backend stocke `createdAt` ; on accepte
  /// aussi `timestamp` / `updatedAt` par tolérance de contrat.
  final DateTime? recordedAt;

  const DriverLocation({
    this.id,
    this.driverId,
    this.parcelId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.recordedAt,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    final recordedAt = _parseDateTime(
            json['createdAt'] ?? json['timestamp'] ?? json['updatedAt']) ??
        _parseDateTime(json['recorded_at'] ?? json['created_at']);

    return DriverLocation(
      id: json['id']?.toString(),
      driverId: json['driverId']?.toString() ?? json['driver_id']?.toString(),
      parcelId: json['parcelId']?.toString() ?? json['parcel_id']?.toString(),
      latitude: _toDouble(json['latitude'] ?? json['lat']),
      longitude: _toDouble(json['longitude'] ?? json['lng']),
      accuracy: json['accuracy'] != null
          ? _toDouble(json['accuracy'])
          : null,
      recordedAt: recordedAt,
    );
  }

  /// La position est exploitable dès que latitude et longitude sont des
  /// coordonnées plausibles (non nulles toutes les deux).
  bool get hasCoordinates =>
      latitude != 0 || longitude != 0;

  /// Ancienneté de la position, ou `null` si aucun horodatage n'est fourni.
  Duration? age(DateTime now) {
    final at = recordedAt;
    if (at == null) return null;
    return now.difference(at);
  }

  /// Une position trop ancienne ne doit plus être présentée comme « temps
  /// réel ». Le seuil par défaut est de 5 minutes.
  bool isStale(DateTime now, {Duration threshold = const Duration(minutes: 5)}) {
    final a = age(now);
    if (a == null) return true;
    return a > threshold;
  }
}
