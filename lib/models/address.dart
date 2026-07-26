class Address {
  final String id;
  final String? userId;
  final String? label;
  final String address;
  final String? city;
  final String? region;
  final double? latitude;
  final double? longitude;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Address({
    required this.id,
    this.userId,
    this.label,
    required this.address,
    this.city,
    this.region,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    double? decimal(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    return Address(
      id: json['id']?.toString() ?? '',
      userId: (json['userId'] ?? json['user_id'])?.toString(),
      label: json['label']?.toString(),
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString(),
      region: json['region']?.toString(),
      latitude: decimal(json['latitude']),
      longitude: decimal(json['longitude']),
      isDefault: (json['isDefault'] ?? json['is_default']) == true,
      createdAt: DateTime.tryParse(
        (json['createdAt'] ?? json['created_at'])?.toString() ?? '',
      ),
      updatedAt: DateTime.tryParse(
        (json['updatedAt'] ?? json['updated_at'])?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toPayload() => {
        if (label?.trim().isNotEmpty == true) 'label': label!.trim(),
        'address': address.trim(),
        if (city?.trim().isNotEmpty == true) 'city': city!.trim(),
        if (region?.trim().isNotEmpty == true) 'region': region!.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'isDefault': isDefault,
      };
}
