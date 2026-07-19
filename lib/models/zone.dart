class Zone {
  final String id;
  final String name;
  final String? displayName;
  final String? placeId;
  final String? country;
  final String? city;
  final double latitude;
  final double longitude;
  final int radius;
  final List<List<double>>? boundary;
  final String type;
  final bool isActive;
  final String? parentId;
  final Map<String, dynamic>? metadata;
  final int driversCount;
  final int parcelsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Zone({
    required this.id,
    required this.name,
    this.displayName,
    this.placeId,
    this.country,
    this.city,
    required this.latitude,
    required this.longitude,
    this.radius = 5000,
    this.boundary,
    this.type = 'CIRCLE',
    this.isActive = true,
    this.parentId,
    this.metadata,
    this.driversCount = 0,
    this.parcelsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    double parseDouble(dynamic v) {
      if (v == null) return 0;
      if (v is double) return v;
      return double.tryParse(v.toString()) ?? 0;
    }

    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    List<List<double>>? parseBoundary(dynamic b) {
      if (b == null) return null;
      if (b is List) {
        return b.map<List<double>>((pt) {
          if (pt is List) {
            return pt.map<double>((c) => parseDouble(c)).toList();
          }
          return <double>[0, 0];
        }).toList();
      }
      return null;
    }

    return Zone(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['display_name']?.toString(),
      placeId: json['placeId']?.toString() ?? json['place_id']?.toString(),
      country: json['country']?.toString(),
      city: json['city']?.toString(),
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      radius: parseInt(json['radius']) ?? 5000,
      boundary: parseBoundary(json['boundary']),
      type: json['type']?.toString() ?? 'CIRCLE',
      isActive: (json['isActive'] ?? json['is_active'] ?? true) != false,
      parentId: json['parentId']?.toString() ?? json['parent_id']?.toString(),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : null,
      driversCount: json['_count'] != null
          ? parseInt(json['_count']['driverZones'] ?? json['_count']['driver_zones'])
          : parseInt(json['driversCount'] ?? json['drivers_count'] ?? 0),
      parcelsCount: json['_count'] != null
          ? parseInt(json['_count']['parcels'])
          : parseInt(json['parcelsCount'] ?? json['parcels_count'] ?? 0),
      createdAt: parseDateTime(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      updatedAt: parseDateTime(json['updatedAt'] ?? json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'display_name': displayName,
    'place_id': placeId,
    'country': country,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'boundary': boundary,
    'type': type,
    'is_active': isActive,
    'parent_id': parentId,
    'metadata': metadata,
  };
}
