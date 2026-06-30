// mobile/lib/models/user.dart
// ignore_for_file: unreachable_switch_default, unnecessary_null_comparison

import 'package:flutter/material.dart';

enum UserRole {
  client('client', 'Client', Icons.person, Colors.green),
  driver('driver', 'Chauffeur', Icons.delivery_dining, Colors.blue),
  admin('admin', 'Admin Garage', Icons.business, Colors.orange),
  superAdmin('super_admin', 'Super Admin', Icons.admin_panel_settings, Colors.red);

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  
  const UserRole(this.value, this.label, this.icon, this.color);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.client,
    );
  }
}

enum UserStatus {
  active('active', 'Actif', Colors.green),
  suspended('suspended', 'Suspendu', Colors.orange),
  deleted('deleted', 'Supprimé', Colors.red);

  final String value;
  final String label;
  final Color color;
  
  const UserStatus(this.value, this.label, this.color);
}

enum DriverStatus {
  available('available', 'Disponible', Colors.green),
  busy('busy', 'En livraison', Colors.red),
  offline('offline', 'Hors ligne', Colors.grey);

  final String value;
  final String label;
  final Color color;
  
  const DriverStatus(this.value, this.label, this.color);
  
  static DriverStatus fromString(String value) {
    return DriverStatus.values.firstWhere(
      (e) => e.value == value.toLowerCase(),
      orElse: () => DriverStatus.offline,
    );
  }
}

enum Gender {
  male('male', 'Homme', Icons.male),
  female('female', 'Femme', Icons.female),
  other('other', 'Autre', Icons.person);

  final String value;
  final String label;
  final IconData icon;
  
  const Gender(this.value, this.label, this.icon);
}

class User {
  // Informations de base
  final String id;
  final String email;
  final String phone;
  final String fullName;
  final UserRole role;
  final UserStatus status;
  final String? pin;
  
  // Profil
  final String? profilePhoto;
  final String? address;
  final String? city;
  final String? region;
  final Gender? gender;
  
  // Affiliation garage
  final String? garageId;
  final String? garageName;
  
  // Informations chauffeur
  final String? vehiclePlate;
  final String? vehicleModel;
  final String? vehicleColor;
  final int? vehicleYear;
  final DriverStatus? driverStatus;
  
  // Statistiques chauffeur
  final double? rating;
  final int? totalDeliveries;
  final int? completedDeliveries;
  final int? cancelledDeliveries;
  
  // Vérifications
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isProfileComplete;
  
  // Dates
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;
  final DateTime? lastActiveAt;

  // Constructeur principal
  const User({
    required this.id,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.role,
    this.status = UserStatus.active,
    this.pin,
    this.profilePhoto,
    this.address,
    this.city,
    this.region,
    this.garageId,
    this.garageName,
    this.vehiclePlate,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleYear,
    this.driverStatus,
    this.gender,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.isProfileComplete = false,
    this.rating,
    this.totalDeliveries,
    this.completedDeliveries,
    this.cancelledDeliveries,
    required this.createdAt,
    this.updatedAt,
    this.lastLogin,
    this.lastActiveAt,
  });

  // Factory depuis JSON
  factory User.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (e) {
        return null;
      }
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      try {
        return double.parse(value.toString());
      } catch (e) {
        return null;
      }
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      try {
        return int.parse(value.toString());
      } catch (e) {
        return null;
      }
    }

    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? '',
      role: json['role'] != null ? UserRole.fromString(json['role'].toString()) : UserRole.client,
      status: json['status'] != null 
          ? UserStatus.values.firstWhere(
              (e) => e.value == json['status'].toString(),
              orElse: () => UserStatus.active,
            )
          : UserStatus.active,
      pin: json['pin']?.toString(),
      profilePhoto: json['profilePhoto']?.toString() ?? json['profile_photo']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      region: json['region']?.toString(),
      garageId: json['garageId']?.toString() ?? json['garage_id']?.toString(),
      garageName: json['garageName']?.toString() ?? json['garage_name']?.toString(),
      vehiclePlate: json['vehiclePlate']?.toString() ?? json['vehicle_plate']?.toString(),
      vehicleModel: json['vehicleModel']?.toString() ?? json['vehicle_model']?.toString(),
      vehicleColor: json['vehicleColor']?.toString() ?? json['vehicle_color']?.toString(),
      vehicleYear: parseInt(json['vehicleYear']) ?? parseInt(json['vehicle_year']),
      driverStatus: json['driverStatus'] != null 
          ? DriverStatus.fromString(json['driverStatus'].toString())
          : json['driver_status'] != null
              ? DriverStatus.fromString(json['driver_status'].toString())
              : null,
      gender: json['gender'] != null
          ? Gender.values.firstWhere(
              (e) => e.value == json['gender'].toString(),
              orElse: () => Gender.other,
            )
          : null,
      isEmailVerified: json['isEmailVerified'] ?? json['is_email_verified'] ?? false,
      isPhoneVerified: json['isPhoneVerified'] ?? json['is_phone_verified'] ?? false,
      isProfileComplete: json['isProfileComplete'] ?? json['is_profile_complete'] ?? false,
      rating: parseDouble(json['rating']),
      totalDeliveries: parseInt(json['totalDeliveries']) ?? parseInt(json['total_deliveries']),
      completedDeliveries: parseInt(json['completedDeliveries']) ?? parseInt(json['completed_deliveries']),
      cancelledDeliveries: parseInt(json['cancelledDeliveries']) ?? parseInt(json['cancelled_deliveries']),
      createdAt: parseDateTime(json['createdAt']) ?? parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDateTime(json['updatedAt']) ?? parseDateTime(json['updated_at']),
      lastLogin: parseDateTime(json['lastLogin']) ?? parseDateTime(json['last_login']),
      lastActiveAt: parseDateTime(json['lastActiveAt']) ?? parseDateTime(json['last_active_at']),
    );
  }

  // Conversion en JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'fullName': fullName,
    'role': role.value,
    'status': status.value,
    'pin': pin,
    'profilePhoto': profilePhoto,
    'address': address,
    'city': city,
    'region': region,
    'garageId': garageId,
    'garageName': garageName,
    'vehiclePlate': vehiclePlate,
    'vehicleModel': vehicleModel,
    'vehicleColor': vehicleColor,
    'vehicleYear': vehicleYear,
    'driverStatus': driverStatus?.value,
    'gender': gender?.value,
    'isEmailVerified': isEmailVerified,
    'isPhoneVerified': isPhoneVerified,
    'isProfileComplete': isProfileComplete,
    'rating': rating,
    'totalDeliveries': totalDeliveries,
    'completedDeliveries': completedDeliveries,
    'cancelledDeliveries': cancelledDeliveries,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'lastLogin': lastLogin?.toIso8601String(),
    'lastActiveAt': lastActiveAt?.toIso8601String(),
  };

  // ==================== PROPRIÉTÉS CALCULÉES ====================
  
  // Statut général
  bool get isActive => status == UserStatus.active;
  bool get isSuspended => status == UserStatus.suspended;
  bool get isDeleted => status == UserStatus.deleted;
  
  // Rôles
  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isAdmin => role == UserRole.admin;
  bool get isDriver => role == UserRole.driver;
  bool get isClient => role == UserRole.client;
  bool get isGarageStaff => isAdmin || isSuperAdmin;
  
  // Permissions
  bool get canManageUsers => isSuperAdmin;
  bool get canManageGarages => isSuperAdmin;
  bool get canManageDrivers => isSuperAdmin || isAdmin;
  bool get canViewAllParcels => isSuperAdmin || isAdmin;
  bool get canDeliverParcels => isDriver;
  bool get canCreateParcels => isClient;
  bool get canAcceptBids => isDriver;
  bool get canMakeBids => isDriver;
  
  // Statut chauffeur
  bool get isDriverAvailable => isDriver && driverStatus == DriverStatus.available;
  bool get isDriverBusy => isDriver && driverStatus == DriverStatus.busy;
  bool get isDriverOffline => isDriver && driverStatus == DriverStatus.offline;
  
  // Statistiques
  double get successRate {
    if (totalDeliveries == null || totalDeliveries == 0) return 0.0;
    final completed = completedDeliveries ?? 0;
    return completed / totalDeliveries!;
  }
  
  String get formattedRating => rating?.toStringAsFixed(1) ?? 'N/A';
  String get formattedTotalDeliveries => totalDeliveries?.toString() ?? '0';
  String get formattedSuccessRate => '${(successRate * 100).toStringAsFixed(0)}%';
  
  // Affichage
  String get displayName => fullName;
  String get shortName {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0];
    return '${parts[0]} ${parts[parts.length - 1]}';
  }
  
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
  
  String get formattedPhone {
    String rawPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (rawPhone.startsWith('221') && rawPhone.length > 9) {
      return '+${rawPhone.substring(0, 3)} ${rawPhone.substring(3, 6)} ${rawPhone.substring(6, 8)} ${rawPhone.substring(8, 10)}';
    }
    if (rawPhone.startsWith('77') && rawPhone.length == 9) {
      return '+221 $rawPhone';
    }
    if (rawPhone.length == 9 && !rawPhone.startsWith('77')) {
      return '+221 $rawPhone';
    }
    return phone;
  }
  
  String get vehicleInfo {
    final parts = <String>[];
    if (vehiclePlate != null && vehiclePlate!.isNotEmpty) parts.add(vehiclePlate!);
    if (vehicleModel != null && vehicleModel!.isNotEmpty) parts.add(vehicleModel!);
    if (vehicleColor != null && vehicleColor!.isNotEmpty) parts.add(vehicleColor!);
    return parts.join(' - ');
  }
  
  bool get hasVehicleInfo => vehiclePlate != null || vehicleModel != null;
  bool get hasProfilePhoto => profilePhoto != null && profilePhoto!.isNotEmpty;
  bool get hasAddress => address != null && address!.isNotEmpty;
  bool get hasPin => pin != null && pin!.isNotEmpty;
  
  // Status text avec couleur
  Color get statusColor {
    if (isDriver) {
      switch (driverStatus) {
        case DriverStatus.available: return Colors.green;
        case DriverStatus.busy: return Colors.red;
        case DriverStatus.offline: return Colors.grey;
        default: return Colors.grey;
      }
    }
    return status.color;
  }
  
  String get statusText {
    if (isDriver && driverStatus != null) {
      return driverStatus!.label;
    }
    return status.label;
  }
  
  IconData get statusIcon {
    if (isDriver) {
      switch (driverStatus) {
        case DriverStatus.available: return Icons.check_circle;
        case DriverStatus.busy: return Icons.local_shipping;
        case DriverStatus.offline: return Icons.circle;
        default: return Icons.help_outline;
      }
    }
    switch (status) {
      case UserStatus.active: return Icons.check_circle;
      case UserStatus.suspended: return Icons.warning;
      case UserStatus.deleted: return Icons.delete;
      default: return Icons.help_outline;
    }
  }

  // ==================== MÉTHODES UTILITAIRES ====================
  
  User copyWith({
    String? id,
    String? email,
    String? phone,
    String? fullName,
    UserRole? role,
    UserStatus? status,
    String? pin,
    String? profilePhoto,
    String? address,
    String? city,
    String? region,
    String? garageId,
    String? garageName,
    String? vehiclePlate,
    String? vehicleModel,
    String? vehicleColor,
    int? vehicleYear,
    DriverStatus? driverStatus,
    Gender? gender,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    bool? isProfileComplete,
    double? rating,
    int? totalDeliveries,
    int? completedDeliveries,
    int? cancelledDeliveries,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
    DateTime? lastActiveAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      status: status ?? this.status,
      pin: pin ?? this.pin,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      address: address ?? this.address,
      city: city ?? this.city,
      region: region ?? this.region,
      garageId: garageId ?? this.garageId,
      garageName: garageName ?? this.garageName,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      driverStatus: driverStatus ?? this.driverStatus,
      gender: gender ?? this.gender,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      completedDeliveries: completedDeliveries ?? this.completedDeliveries,
      cancelledDeliveries: cancelledDeliveries ?? this.cancelledDeliveries,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
  
  // Map pour mise à jour partielle
  Map<String, dynamic> toUpdateMap() {
    final map = <String, dynamic>{};
    if (email != null) map['email'] = email;
    if (phone != null) map['phone'] = phone;
    if (fullName != null) map['fullName'] = fullName;
    if (pin != null) map['pin'] = pin;
    if (profilePhoto != null) map['profilePhoto'] = profilePhoto;
    if (address != null) map['address'] = address;
    if (city != null) map['city'] = city;
    if (region != null) map['region'] = region;
    if (garageId != null) map['garageId'] = garageId;
    if (vehiclePlate != null) map['vehiclePlate'] = vehiclePlate;
    if (vehicleModel != null) map['vehicleModel'] = vehicleModel;
    if (vehicleColor != null) map['vehicleColor'] = vehicleColor;
    if (vehicleYear != null) map['vehicleYear'] = vehicleYear;
    if (driverStatus != null) map['driverStatus'] = driverStatus!.value;
    if (gender != null) map['gender'] = gender!.value;
    return map;
  }
  
  @override
  String toString() {
    return 'User(id: $id, email: $email, fullName: $fullName, role: ${role.label})';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

// ==================== EXTENSIONS ====================

extension UserListExtension on List<User> {
  List<User> get drivers => where((u) => u.isDriver).toList();
  List<User> get clients => where((u) => u.isClient).toList();
  List<User> get admins => where((u) => u.isAdmin).toList();
  List<User> get active => where((u) => u.isActive).toList();
  List<User> get availableDrivers => where((u) => u.isDriverAvailable).toList();
  
  User? findById(String id) {
    try {
      return firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }
  
  Map<String, List<User>> groupByRole() {
    return {
      'clients': clients,
      'drivers': drivers,
      'admins': admins,
    };
  }
}