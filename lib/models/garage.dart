// mobile/lib/models/garage.dart


class Garage {
  final String id;
  final String name;
  final String city;
  final String region;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final int driversCount;
  final int parcelsCount;
  final double revenue;
  final DateTime createdAt;
  final DateTime updatedAt;

  Garage({
    required this.id,
    required this.name,
    required this.city,
    required this.region,
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.driversCount = 0,
    this.parcelsCount = 0,
    this.revenue = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Garage.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return null;
      }
    }

    return Garage(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      latitude: json['latitude'] != null ? (json['latitude'] is double ? json['latitude'] : double.tryParse(json['latitude'].toString())) : null,
      longitude: json['longitude'] != null ? (json['longitude'] is double ? json['longitude'] : double.tryParse(json['longitude'].toString())) : null,
      driversCount: json['driversCount'] ?? json['drivers_count'] ?? 0,
      parcelsCount: json['parcelsCount'] ?? json['parcels_count'] ?? 0,
      revenue: json['revenue'] != null ? (json['revenue'] is double ? json['revenue'] : double.tryParse(json['revenue'].toString()) ?? 0) : 0,
      createdAt: parseDateTime(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      updatedAt: parseDateTime(json['updatedAt'] ?? json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'city': city,
    'region': region,
    'address': address,
    'phone': phone,
    'latitude': latitude,
    'longitude': longitude,
    'drivers_count': driversCount,
    'parcels_count': parcelsCount,
    'revenue': revenue,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}