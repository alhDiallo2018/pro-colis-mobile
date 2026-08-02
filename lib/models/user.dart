// mobile/lib/models/user.dart
// ignore_for_file: unreachable_switch_default, unnecessary_null_comparison

import 'package:flutter/material.dart';

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

enum UserRole {
  client('client', 'Client', Icons.person, Colors.green),
  driver('driver', 'Chauffeur', Icons.delivery_dining, Colors.blue),
  admin('admin', 'Admin Zone', Icons.business, Colors.orange),
  supportTechnique('support_technique', 'Support technique',
      Icons.support_agent, Color(0xFF7C3AED)),
  supportCommercial('support_commercial', 'Support commercial', Icons.handshake,
      Color(0xFF0C6E7D)),
  support('support', 'Support', Icons.headset_mic, Color(0xFF475569)),
  superAdmin(
      'super_admin', 'Super Admin', Icons.admin_panel_settings, Colors.red);

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const UserRole(this.value, this.label, this.icon, this.color);

  static UserRole fromString(String value) {
    // L'API et les anciennes bases ont utilisé plusieurs séparateurs et
    // abréviations pour les rôles support. On compare une forme compacte afin
    // que `support_technique`, `support-technique` et `supportTechnique`
    // aboutissent tous au même dashboard.
    final compact =
        value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

    switch (compact) {
      case 'client':
        return UserRole.client;
      case 'driver':
      case 'chauffeur':
        return UserRole.driver;
      case 'admin':
      case 'adminzone':
      case 'garageadmin':
        return UserRole.admin;
      case 'supporttechnique':
      case 'supporttechnic':
      case 'supporttechnical':
      case 'supporttech':
      case 'techsupport':
      case 'technicalsupport':
        return UserRole.supportTechnique;
      case 'supportcommercial':
      case 'supportcomm':
      case 'commercialsupport':
      case 'supportsales':
      case 'salessupport':
        return UserRole.supportCommercial;
      case 'support':
        return UserRole.support;
      case 'superadmin':
        return UserRole.superAdmin;
      default:
        // Conserve la compatibilité historique, tout en rendant la valeur
        // fautive visible dans les journaux de développement.
        debugPrint(
          '[UserRole] Rôle API non reconnu "$value", repli vers client.',
        );
        return UserRole.client;
    }
  }

  /// Endpoint de mise à jour du profil propre au rôle. Centralisé ici pour que
  /// l'ajout d'un rôle ne laisse pas un `switch` obsolète derrière lui.
  String get profileEndpoint {
    switch (this) {
      case UserRole.client:
        return '/client/profile';
      case UserRole.driver:
        return '/driver/profile';
      case UserRole.admin:
        return '/garage-admin/profile';
      case UserRole.supportTechnique:
        return '/support-technique/profile';
      case UserRole.supportCommercial:
        return '/support-commercial/profile';
      // L'API autorise `super_admin` et `support` sur PUT /super-admin/profile.
      case UserRole.support:
      case UserRole.superAdmin:
        return '/super-admin/profile';
    }
  }

  /// Préfixe de ressource utilisé par les endpoints scopés au rôle
  /// (`/{scope}/parcels/:id`, `/{scope}/stats`…).
  String get apiScope {
    switch (this) {
      case UserRole.client:
        return 'client';
      case UserRole.driver:
        return 'driver';
      case UserRole.admin:
        return 'garage-admin';
      case UserRole.supportTechnique:
        return 'support-technique';
      case UserRole.supportCommercial:
        return 'support-commercial';
      // `support` consomme les mêmes ressources que le super admin.
      case UserRole.support:
      case UserRole.superAdmin:
        return 'super-admin';
    }
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
  final String? zoneId;
  final String? zoneName;

  // Informations chauffeur
  final String? vehiclePlate;
  final String? vehicleModel;
  // `type` et `capacity` sont les colonnes réelles de la table `vehicles`.
  // Couleur et année n'existent nulle part côté serveur : les exposer
  // garantissait des champs vides à l'écran.
  final String? vehicleType;
  final int? vehicleCapacity;
  final DriverStatus? driverStatus;

  // Statistiques chauffeur
  final double? rating;
  final int? totalDeliveries;
  final int? completedDeliveries;
  final int? cancelledDeliveries;

  // Wallet / Commission
  final double walletBalance;
  final double totalCommissionPaid;

  // Vérifications
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final bool isVerified;
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
    this.zoneId,
    this.zoneName,
    this.vehiclePlate,
    this.vehicleModel,
    this.vehicleType,
    this.vehicleCapacity,
    this.driverStatus,
    this.gender,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.isVerified = false,
    this.isProfileComplete = false,
    this.rating,
    this.totalDeliveries,
    this.completedDeliveries,
    this.cancelledDeliveries,
    this.walletBalance = 0,
    this.totalCommissionPaid = 0,
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

    // Certains endpoints renvoient le rôle directement, d'autres sous la
    // forme d'un objet (`{name: ...}`) ou avec une clé legacy `userRole`.
    // Extraire la valeur ici garantit que toutes les restaurations de session
    // utilisent le même aiguillage vers les dashboards.
    final rawRole = json['role'] ?? json['userRole'] ?? json['user_role'];
    final roleValue = rawRole is Map
        ? rawRole['value'] ?? rawRole['name'] ?? rawRole['role']
        : rawRole;

    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      fullName:
          json['fullName']?.toString() ?? json['full_name']?.toString() ?? '',
      role: roleValue != null
          ? UserRole.fromString(roleValue.toString())
          : UserRole.client,
      status: json['status'] != null
          ? UserStatus.values.firstWhere(
              (e) => e.value == json['status'].toString(),
              orElse: () => UserStatus.active,
            )
          : UserStatus.active,
      pin: json['pin']?.toString(),
      profilePhoto:
          json['profilePhoto']?.toString() ?? json['profile_photo']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      region: json['region']?.toString(),
      zoneId: json['zoneId']?.toString() ?? json['zone_id']?.toString(),
      zoneName:
          json['zoneName']?.toString() ?? json['zone_name']?.toString(),
      vehiclePlate:
          json['vehiclePlate']?.toString() ?? json['vehicle_plate']?.toString(),
      vehicleModel:
          json['vehicleModel']?.toString() ?? json['vehicle_model']?.toString(),
      vehicleType:
          json['vehicleType']?.toString() ?? json['vehicle_type']?.toString(),
      vehicleCapacity: parseInt(json['vehicleCapacity']) ??
          parseInt(json['vehicle_capacity']),
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
      isEmailVerified:
          json['isEmailVerified'] ?? json['is_email_verified'] ?? false,
      isPhoneVerified:
          json['isPhoneVerified'] ?? json['is_phone_verified'] ?? false,
      isVerified: json['isVerified'] ?? json['is_verified'] ?? false,
      isProfileComplete:
          json['isProfileComplete'] ?? json['is_profile_complete'] ?? false,
      rating: parseDouble(json['rating']),
      totalDeliveries: parseInt(json['totalDeliveries']) ??
          parseInt(json['total_deliveries']),
      completedDeliveries: parseInt(json['completedDeliveries']) ??
          parseInt(json['completed_deliveries']),
      cancelledDeliveries: parseInt(json['cancelledDeliveries']) ??
          parseInt(json['cancelled_deliveries']),
      walletBalance: _toDouble(json['walletBalance']),
      totalCommissionPaid: _toDouble(json['totalCommissionPaid']),
      createdAt: parseDateTime(json['createdAt']) ??
          parseDateTime(json['created_at']) ??
          DateTime.now(),
      updatedAt:
          parseDateTime(json['updatedAt']) ?? parseDateTime(json['updated_at']),
      lastLogin:
          parseDateTime(json['lastLogin']) ?? parseDateTime(json['last_login']),
      lastActiveAt: parseDateTime(json['lastActiveAt']) ??
          parseDateTime(json['last_active_at']),
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
        'zoneId': zoneId,
        'zoneName': zoneName,
        'vehiclePlate': vehiclePlate,
        'vehicleModel': vehicleModel,
        'vehicleType': vehicleType,
        'vehicleCapacity': vehicleCapacity,
        'driverStatus': driverStatus?.value,
        'gender': gender?.value,
        'isVerified': isVerified,
        'isEmailVerified': isEmailVerified,
        'isPhoneVerified': isPhoneVerified,
        'isProfileComplete': isProfileComplete,
        'rating': rating,
        'totalDeliveries': totalDeliveries,
        'completedDeliveries': completedDeliveries,
        'cancelledDeliveries': cancelledDeliveries,
        'walletBalance': walletBalance,
        'totalCommissionPaid': totalCommissionPaid,
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
  bool get isSupportTechnique => role == UserRole.supportTechnique;
  bool get isSupportCommercial => role == UserRole.supportCommercial;

  /// Compte support partagé historique. L'API l'autorise sur toutes les routes
  /// `/super-admin/*` au même titre que le super admin, mais le web le cantonne
  /// à l'espace support : on reproduit ce cantonnement.
  bool get isSupportShared => role == UserRole.support;

  /// Les trois rôles support, équivalent de `SUPPORT_ROLES` côté web
  /// (`ProColis-Web/src/lib/api/types.ts`).
  bool get isSupport =>
      isSupportShared || isSupportTechnique || isSupportCommercial;
  bool get isGarageStaff => isAdmin || isSuperAdmin;

  /// Personnel de la plateforme (par opposition aux clients et chauffeurs).
  bool get isStaff => isAdmin || isSupport || isSuperAdmin;

  // Permissions
  bool get canManageUsers => isSuperAdmin;
  bool get canManageGarages => isSuperAdmin;
  bool get canManageDrivers => isSuperAdmin || isAdmin;

  /// Le support consulte les colis pour traiter tickets et réclamations, mais
  /// n'assigne ni ne modifie : la lecture est volontairement séparée de
  /// [canManageParcels].
  bool get canViewAllParcels => isSuperAdmin || isAdmin || isSupport;
  bool get canManageParcels => isSuperAdmin || isAdmin;
  bool get canDeliverParcels => isDriver;
  bool get canCreateParcels => isClient;
  bool get canAcceptBids => isDriver;
  bool get canMakeBids => isDriver;

  /// Traitement des tickets de support : réservé au support technique et au
  /// super admin (le commercial suit des prospects, pas des incidents).
  bool get canHandleSupportTickets => isSupportTechnique || isSuperAdmin;

  /// Suivi commercial (prospects, partenariats, zones à signer).
  bool get canManageCommercial => isSupportCommercial || isSuperAdmin;

  // Statut chauffeur
  bool get isDriverAvailable =>
      isDriver && driverStatus == DriverStatus.available;
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
  String get formattedSuccessRate =>
      '${(successRate * 100).toStringAsFixed(0)}%';

  // Wallet
  bool get hasEnoughCredit => walletBalance > 0;
  bool get canReceiveDelivery => walletBalance >= 100; // Commission minimum

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
    if (vehiclePlate != null && vehiclePlate!.isNotEmpty)
      parts.add(vehiclePlate!);
    if (vehicleModel != null && vehicleModel!.isNotEmpty)
      parts.add(vehicleModel!);
    if (vehicleType != null && vehicleType!.isNotEmpty) parts.add(vehicleType!);
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
        case DriverStatus.available:
          return Colors.green;
        case DriverStatus.busy:
          return Colors.red;
        case DriverStatus.offline:
          return Colors.grey;
        default:
          return Colors.grey;
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
        case DriverStatus.available:
          return Icons.check_circle;
        case DriverStatus.busy:
          return Icons.local_shipping;
        case DriverStatus.offline:
          return Icons.circle;
        default:
          return Icons.help_outline;
      }
    }
    switch (status) {
      case UserStatus.active:
        return Icons.check_circle;
      case UserStatus.suspended:
        return Icons.warning;
      case UserStatus.deleted:
        return Icons.delete;
      default:
        return Icons.help_outline;
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
    String? zoneId,
    String? zoneName,
    String? vehiclePlate,
    String? vehicleModel,
    String? vehicleType,
    int? vehicleCapacity,
    DriverStatus? driverStatus,
    Gender? gender,
    bool? isEmailVerified,
    bool? isVerified,
    bool? isPhoneVerified,
    bool? isProfileComplete,
    double? rating,
    int? totalDeliveries,
    int? completedDeliveries,
    int? cancelledDeliveries,
    double? walletBalance,
    double? totalCommissionPaid,
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
      zoneId: zoneId ?? this.zoneId,
      zoneName: zoneName ?? this.zoneName,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleCapacity: vehicleCapacity ?? this.vehicleCapacity,
      driverStatus: driverStatus ?? this.driverStatus,
      gender: gender ?? this.gender,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isVerified: isVerified ?? this.isVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      completedDeliveries: completedDeliveries ?? this.completedDeliveries,
      cancelledDeliveries: cancelledDeliveries ?? this.cancelledDeliveries,
      walletBalance: walletBalance ?? this.walletBalance,
      totalCommissionPaid: totalCommissionPaid ?? this.totalCommissionPaid,
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
    if (zoneId != null) map['zoneId'] = zoneId;
    if (vehiclePlate != null) map['vehiclePlate'] = vehiclePlate;
    if (vehicleModel != null) map['vehicleModel'] = vehicleModel;
    if (vehicleType != null) map['vehicleType'] = vehicleType;
    if (vehicleCapacity != null) map['vehicleCapacity'] = vehicleCapacity;
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
  List<User> get supportAgents => where((u) => u.isSupport).toList();
  List<User> get supportTechniqueAgents =>
      where((u) => u.isSupportTechnique).toList();
  List<User> get supportCommercialAgents =>
      where((u) => u.isSupportCommercial).toList();
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
      'supportTechnique': supportTechniqueAgents,
      'supportCommercial': supportCommercialAgents,
    };
  }
}
