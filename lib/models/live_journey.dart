class LiveJourney {
  const LiveJourney(
      {required this.id,
      required this.vehicleReference,
      required this.driverName,
      required this.model,
      required this.lineNumber,
      required this.from,
      required this.to,
      required this.direction,
      required this.departureAt,
      required this.latitude,
      required this.longitude,
      required this.accuracy,
      required this.capturedAt,
      required this.expiresAt});
  final String id,
      vehicleReference,
      driverName,
      model,
      lineNumber,
      from,
      to,
      direction;
  final DateTime? departureAt;
  final double latitude, longitude, accuracy;
  final DateTime capturedAt, expiresAt;
  bool isFresh(DateTime now) =>
      now.isBefore(expiresAt) &&
      now.difference(capturedAt).inSeconds <= 60 &&
      capturedAt.difference(now).inSeconds <= 5;
  String get label => lineNumber.isEmpty ? model : 'Ligne $lineNumber';
  static LiveJourney? fromJson(Map<String, dynamic> json) {
    final p = json['position'];
    final from = json['departure'];
    final to = json['arrival'];
    if (p is! Map || from is! Map || to is! Map) return null;
    final lat = double.tryParse('${p['latitude']}'),
        lng = double.tryParse('${p['longitude']}'),
        accuracy = double.tryParse('${p['accuracyMeters']}');
    final captured = DateTime.tryParse('${p['capturedAt']}'),
        expires = DateTime.tryParse('${p['expiresAt']}');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        accuracy == null ||
        !accuracy.isFinite ||
        accuracy < 0 ||
        captured == null ||
        expires == null) return null;
    return LiveJourney(
        id: json['advertisementId'].toString(),
        vehicleReference: json['vehicleReference']?.toString() ?? '',
        driverName: json['driverName']?.toString() ?? 'Chauffeur',
        model: json['vehicleModel']?.toString() ?? 'Véhicule',
        lineNumber: json['lineNumber']?.toString() ?? '',
        from: from['name']?.toString() ?? 'Départ',
        to: to['name']?.toString() ?? 'Arrivée',
        direction: '${from['zoneId']}:${to['zoneId']}',
        departureAt: DateTime.tryParse('${json['departureAt']}'),
        latitude: lat,
        longitude: lng,
        accuracy: accuracy,
        capturedAt: captured,
        expiresAt: expires);
  }
}
