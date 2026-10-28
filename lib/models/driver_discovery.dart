import 'garage.dart';
import 'user.dart';

class DriverDiscoveryQuery {
  const DriverDiscoveryQuery(
      {required this.latitude,
      required this.longitude,
      this.radiusKm = 10,
      this.vehicleType,
      this.minCapacity,
      this.verifiedOnly = false});
  final double latitude, longitude, radiusKm;
  final String? vehicleType;
  final double? minCapacity;
  final bool verifiedOnly;
  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
        if (vehicleType != null) 'vehicleType': vehicleType,
        if (minCapacity != null) 'minCapacity': minCapacity,
        if (verifiedOnly) 'verifiedOnly': true,
        'limit': 100,
      };
}

class NearbyDriver {
  const NearbyDriver(
      {required this.user,
      required this.latitude,
      required this.longitude,
      required this.updatedAt,
      this.accuracyMeters = 150});
  final User user;
  final double latitude, longitude, accuracyMeters;
  final DateTime updatedAt;
  bool isFresh(DateTime now) =>
      now.difference(updatedAt) >= Duration.zero &&
      now.difference(updatedAt) <= const Duration(minutes: 10);

  static NearbyDriver? fromJson(Map<String, dynamic> json) {
    final point = json['mapPosition'];
    if (point is! Map) return null;
    final lat = double.tryParse('${point['latitude']}');
    final lng = double.tryParse('${point['longitude']}');
    final date = DateTime.tryParse('${json['locationUpdatedAt']}');
    if (lat == null ||
        lng == null ||
        date == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) return null;
    return NearbyDriver(
        user: User.fromJson(json),
        latitude: lat,
        longitude: lng,
        updatedAt: date,
        accuracyMeters: double.tryParse('${point['accuracyMeters']}') ?? 150);
  }
}

class DriverMapResult {
  const DriverMapResult(
      {this.drivers = const [], this.counts = const {}, this.total = 0});
  final List<NearbyDriver> drivers;
  final Map<String, int> counts;
  final int total;
  factory DriverMapResult.fromJson(Map<String, dynamic> body) =>
      DriverMapResult(
        drivers: (body['drivers'] as List? ?? [])
            .whereType<Map>()
            .map((item) =>
                NearbyDriver.fromJson(Map<String, dynamic>.from(item)))
            .whereType<NearbyDriver>()
            .toList(),
        counts: {
          for (final item
              in (body['categories'] as List? ?? []).whereType<Map>())
            '${item['value']}': int.tryParse('${item['availableCount']}') ?? 0
        },
        total: int.tryParse('${body['search']?['total']}') ?? 0,
      );
}

/// Un seul objet évite de conserver un chauffeur issu d'un ancien trajet.
class DeliveryDiscoverySelection {
  const DeliveryDiscoverySelection(
      {this.pickup,
      this.destination,
      this.driver,
      this.vehicleType,
      this.weight,
      this.openForOffers = false});
  final Garage? pickup, destination;
  final User? driver;
  final String? vehicleType;
  final double? weight;
  final bool openForOffers;
}
