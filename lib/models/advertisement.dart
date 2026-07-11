// lib/models/advertisement.dart
//
// Annonce de trajet publiée par un chauffeur (ressource /advertisements de
// l'API, distincte des colis). Parcourue par les clients dans le libre service.

class Advertisement {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverPhone;
  final String? driverProfilePhoto;
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureAt;
  final num? availableWeight;
  final num? proposedPrice;
  final String? description;
  final String? audioUrl;
  final String status;
  final int offersCount;
  final DateTime? createdAt;

  const Advertisement({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.driverPhone,
    this.driverProfilePhoto,
    this.departureCity,
    this.arrivalCity,
    this.departureAt,
    this.availableWeight,
    this.proposedPrice,
    this.description,
    this.audioUrl,
    this.status = 'open',
    this.offersCount = 0,
    this.createdAt,
  });

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    final driver = json['driver'] as Map<String, dynamic>?;

    String? asString(dynamic v) => v?.toString();
    DateTime? asDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    num? asNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v;
      return num.tryParse(v.toString());
    }

    final offers = json['offers'];

    return Advertisement(
      id: asString(json['id']) ?? '',
      driverId: asString(json['driverId']) ?? asString(driver?['id']) ?? '',
      driverName: asString(json['driverName']) ??
          asString(driver?['fullName']) ??
          'Chauffeur',
      driverPhone: asString(json['driverPhone']) ?? asString(driver?['phone']),
      driverProfilePhoto: asString(json['driverProfilePhoto']) ?? asString(driver?['profilePhoto']),
      departureCity: asString(json['departureCity']),
      arrivalCity: asString(json['arrivalCity']),
      departureAt: asDate(json['departureAt']),
      availableWeight: asNum(json['availableWeight']),
      proposedPrice: asNum(json['proposedPrice']),
      description: asString(json['description']),
      audioUrl: asString(json['audioUrl']),
      status: asString(json['status']) ?? 'open',
      offersCount: offers is List ? offers.length : 0,
      createdAt: asDate(json['createdAt']),
    );
  }

  String get route =>
      '${departureCity ?? '—'}  →  ${arrivalCity ?? '—'}';

  String get formattedWeight =>
      availableWeight != null ? '${availableWeight!.round()} kg' : '—';

  String get formattedPrice =>
      proposedPrice != null ? '${proposedPrice!.round()} FCFA' : 'À négocier';
}
