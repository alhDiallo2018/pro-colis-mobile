import '../models/parcel.dart';
import '../models/user.dart';

class MockData {
  static const bool enabled = bool.fromEnvironment(
    'MOCK_API',
    defaultValue: false,
  );

  static const String pin = '123456';

  static final List<User> users = [
    User(
      id: 'mock-client-1',
      email: 'client@sendprocolis.test',
      phone: '+221771234567',
      fullName: 'Aminata Diop',
      role: UserRole.client,
      status: UserStatus.active,
      pin: pin,
      address: 'Sacré-Coeur 3',
      city: 'Dakar',
      region: 'Dakar',
      isEmailVerified: true,
      isPhoneVerified: true,
      isProfileComplete: true,
      createdAt: DateTime(2026, 1, 10),
      lastLogin: DateTime.now(),
    ),
    User(
      id: 'mock-driver-1',
      email: 'driver@sendprocolis.test',
      phone: '+221772345678',
      fullName: 'Moussa Ndiaye',
      role: UserRole.driver,
      status: UserStatus.active,
      pin: pin,
      city: 'Thiès',
      region: 'Thiès',
      zoneId: 'garage-dkr',
      zoneName: 'Zone Dakar Plateau',
      vehiclePlate: 'DK-4587-AA',
      vehicleModel: 'Mercedes Sprinter',
      vehicleType: 'van',
      vehicleCapacity: 1300,
      driverStatus: DriverStatus.available,
      rating: 4.8,
      totalDeliveries: 128,
      completedDeliveries: 121,
      cancelledDeliveries: 7,
      isEmailVerified: true,
      isPhoneVerified: true,
      isProfileComplete: true,
      createdAt: DateTime(2025, 11, 5),
      lastLogin: DateTime.now(),
    ),
    User(
      id: 'mock-admin-1',
      email: 'admin@sendprocolis.test',
      phone: '+221773456789',
      fullName: 'Fatou Sow',
      role: UserRole.admin,
      status: UserStatus.active,
      pin: pin,
      city: 'Dakar',
      region: 'Dakar',
      zoneId: 'garage-dkr',
      zoneName: 'Zone Dakar Plateau',
      isEmailVerified: true,
      isPhoneVerified: true,
      isProfileComplete: true,
      createdAt: DateTime(2025, 9, 20),
      lastLogin: DateTime.now(),
    ),
    User(
      id: 'mock-support-tech-1',
      email: 'support.tech@sendprocolis.test',
      phone: '+221775678901',
      fullName: 'Awa Ndoye',
      role: UserRole.supportTechnique,
      status: UserStatus.active,
      pin: pin,
      address: 'Point E',
      city: 'Dakar',
      region: 'Dakar',
      isEmailVerified: true,
      isPhoneVerified: true,
      isVerified: true,
      isProfileComplete: true,
      createdAt: DateTime(2025, 10, 14),
      lastLogin: DateTime.now(),
    ),
    User(
      id: 'mock-support-com-1',
      email: 'support.com@sendprocolis.test',
      phone: '+221776789012',
      fullName: 'Seydou Kane',
      role: UserRole.supportCommercial,
      status: UserStatus.active,
      pin: pin,
      address: 'Almadies',
      city: 'Dakar',
      region: 'Dakar',
      isEmailVerified: true,
      isPhoneVerified: true,
      isVerified: true,
      isProfileComplete: true,
      createdAt: DateTime(2025, 8, 3),
      lastLogin: DateTime.now(),
    ),
    User(
      id: 'mock-super-admin-1',
      email: 'super@sendprocolis.test',
      phone: '+221774567890',
      fullName: 'Ibrahima Ba',
      role: UserRole.superAdmin,
      status: UserStatus.active,
      pin: pin,
      city: 'Dakar',
      region: 'Dakar',
      isEmailVerified: true,
      isPhoneVerified: true,
      isProfileComplete: true,
      createdAt: DateTime(2025, 7, 1),
      lastLogin: DateTime.now(),
    ),
  ];

  static final List<Parcel> parcels = [
    Parcel(
      id: 'parcel-001',
      trackingNumber: 'PC-2026-001',
      senderId: 'mock-client-1',
      senderName: 'Aminata Diop',
      senderPhone: '+221771234567',
      senderEmail: 'client@sendprocolis.test',
      receiverName: 'Cheikh Fall',
      receiverPhone: '+221781112233',
      receiverAddress: 'Quartier Escale, Saint-Louis',
      description: 'Documents administratifs',
      weight: 0.4,
      type: ParcelType.document,
      status: ParcelStatus.pending,
      departureZoneId: 'garage-dkr',
      departureZoneName: 'Zone Dakar Plateau',
      arrivalZoneId: 'garage-stl',
      arrivalZoneName: 'Zone Saint-Louis',
      price: 2500,
      totalAmount: 2500,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      estimatedDeliveryDate: DateTime.now().add(const Duration(days: 1)),
    ),
    Parcel(
      id: 'parcel-002',
      trackingNumber: 'PC-2026-002',
      senderId: 'mock-client-1',
      senderName: 'Aminata Diop',
      senderPhone: '+221771234567',
      senderEmail: 'client@sendprocolis.test',
      receiverName: 'Mariama Camara',
      receiverPhone: '+221786667788',
      receiverAddress: 'Grand Standing, Thiès',
      description: 'Petit carton fragile',
      weight: 3.2,
      type: ParcelType.fragile,
      status: ParcelStatus.inTransit,
      departureZoneId: 'garage-dkr',
      departureZoneName: 'Zone Dakar Plateau',
      arrivalZoneId: 'garage-ths',
      arrivalZoneName: 'Zone Thiès',
      driverId: 'mock-driver-1',
      driverName: 'Moussa Ndiaye',
      driverPhone: '+221772345678',
      price: 5000,
      totalAmount: 5000,
      isInsured: true,
      insuranceAmount: 25000,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      estimatedDeliveryDate: DateTime.now().add(const Duration(hours: 8)),
    ),
    Parcel(
      id: 'parcel-003',
      trackingNumber: 'PC-2026-003',
      senderId: 'mock-client-1',
      senderName: 'Aminata Diop',
      senderPhone: '+221771234567',
      senderEmail: 'client@sendprocolis.test',
      receiverName: 'Oumar Diallo',
      receiverPhone: '+221775554433',
      receiverAddress: 'Bambey centre',
      description: 'Sac de vêtements',
      weight: 7.5,
      type: ParcelType.package,
      status: ParcelStatus.free,
      departureZoneId: 'garage-dkr',
      departureZoneName: 'Zone Dakar Plateau',
      arrivalZoneId: 'garage-bby',
      arrivalZoneName: 'Zone Bambey',
      proposedPrice: 7000,
      isFreeForBidding: true,
      bids: [
        Bid(
          id: 'bid-001',
          parcelId: 'parcel-003',
          driverId: 'mock-driver-1',
          driverName: 'Moussa Ndiaye',
          driverPhone: '+221772345678',
          price: 8500,
          message: 'Disponible ce soir, livraison rapide.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      estimatedDeliveryDate: DateTime.now().add(const Duration(days: 2)),
    ),
    Parcel(
      id: 'parcel-004',
      trackingNumber: 'PC-2026-004',
      senderId: 'mock-client-1',
      senderName: 'Aminata Diop',
      senderPhone: '+221771234567',
      senderEmail: 'client@sendprocolis.test',
      receiverName: 'Ndeye Sarr',
      receiverPhone: '+221789998877',
      receiverAddress: 'Keur Massar',
      description: 'Téléphone emballé',
      weight: 0.8,
      type: ParcelType.valuable,
      status: ParcelStatus.delivered,
      departureZoneId: 'garage-ths',
      departureZoneName: 'Zone Thiès',
      arrivalZoneId: 'garage-dkr',
      arrivalZoneName: 'Zone Dakar Plateau',
      driverId: 'mock-driver-1',
      driverName: 'Moussa Ndiaye',
      driverPhone: '+221772345678',
      price: 6500,
      totalAmount: 6500,
      deliveryDate: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];

  static User? findUserByIdentifier(String identifier) {
    final normalized = identifier.trim().toLowerCase().replaceAll(' ', '');
    for (final user in users) {
      if (user.email.toLowerCase() == normalized ||
          user.phone.replaceAll(' ', '') == normalized) {
        return user;
      }
    }
    return null;
  }

  static User userById(String id) {
    return users.firstWhere(
      (user) => user.id == id,
      orElse: () => users.first,
    );
  }

  static List<User> get drivers =>
      users.where((user) => user.role == UserRole.driver).toList();

  static List<Parcel> parcelsForUser(User user) {
    switch (user.role) {
      case UserRole.driver:
        return parcels
            .where((parcel) =>
                parcel.driverId == user.id ||
                parcel.status == ParcelStatus.free ||
                parcel.isFreeForBidding)
            .toList();
      case UserRole.admin:
        return parcels
            .where((parcel) =>
                parcel.departureZoneId == user.zoneId ||
                parcel.arrivalZoneId == user.zoneId)
            .toList();
      // Le support consulte tous les colis pour instruire tickets et
      // réclamations ; la restriction est côté écriture, pas côté lecture.
      case UserRole.supportTechnique:
      case UserRole.supportCommercial:
      case UserRole.support:
      case UserRole.superAdmin:
        return parcels;
      case UserRole.client:
        return parcels.where((parcel) => parcel.senderId == user.id).toList();
    }
  }

  static List<Parcel> freeParcels() {
    return parcels
        .where((parcel) => parcel.status == ParcelStatus.free || parcel.isFreeForBidding)
        .toList();
  }

  static Map<String, dynamic> loginPayload(User user) {
    return {
      'success': true,
      'accessToken': 'mock-token-${user.id}',
      'user': user.toJson(),
    };
  }

  /// Encaissements espèces déclarés par les chauffeurs et en attente de
  /// réconciliation, pour la file de validation admin.
  static List<Map<String, dynamic>> cashDeclarations() {
    final now = DateTime.now();
    return [
      {
        'id': 'mock-cash-1',
        'userId': 'mock-driver-1',
        'userName': 'Moussa Ndiaye',
        'parcelId': parcels.isNotEmpty ? parcels.first.id : 'mock-parcel-1',
        'trackingNumber':
            parcels.isNotEmpty ? parcels.first.trackingNumber : 'PC-0001',
        'amount': 12500,
        'currency': 'XOF',
        'method': 'cash',
        'channel': 'cash',
        'status': 'processing',
        'cashCollectionPoint': 'receiver_delivery',
        'declaredBy': 'mock-driver-1',
        'declaredByName': 'Moussa Ndiaye',
        'declaredAt':
            now.subtract(const Duration(hours: 3)).toIso8601String(),
        'declarationNote': 'Remis par le destinataire au garage de Thiès.',
        'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
      },
      {
        'id': 'mock-cash-2',
        'userId': 'mock-driver-1',
        'userName': 'Moussa Ndiaye',
        'parcelId': parcels.length > 1 ? parcels[1].id : 'mock-parcel-2',
        'trackingNumber':
            parcels.length > 1 ? parcels[1].trackingNumber : 'PC-0002',
        'amount': 8000,
        'currency': 'XOF',
        'method': 'cash',
        'channel': 'cash',
        'status': 'processing',
        'cashCollectionPoint': 'sender_pickup',
        'declaredBy': 'mock-driver-1',
        'declaredByName': 'Moussa Ndiaye',
        'declaredAt':
            now.subtract(const Duration(days: 1)).toIso8601String(),
        'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
      },
    ];
  }
}
