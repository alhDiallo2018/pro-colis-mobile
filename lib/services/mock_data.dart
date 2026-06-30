import '../models/parcel.dart';
import '../models/user.dart';

class MockData {
  static const bool enabled = bool.fromEnvironment(
    'MOCK_API',
    defaultValue: true,
  );

  static const String pin = '123456';

  static final List<User> users = [
    User(
      id: 'mock-client-1',
      email: 'client@procolis.test',
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
      email: 'driver@procolis.test',
      phone: '+221772345678',
      fullName: 'Moussa Ndiaye',
      role: UserRole.driver,
      status: UserStatus.active,
      pin: pin,
      city: 'Thiès',
      region: 'Thiès',
      garageId: 'garage-dkr',
      garageName: 'Garage Dakar Plateau',
      vehiclePlate: 'DK-4587-AA',
      vehicleModel: 'Mercedes Sprinter',
      vehicleColor: 'Blanc',
      vehicleYear: 2022,
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
      email: 'admin@procolis.test',
      phone: '+221773456789',
      fullName: 'Fatou Sow',
      role: UserRole.admin,
      status: UserStatus.active,
      pin: pin,
      city: 'Dakar',
      region: 'Dakar',
      garageId: 'garage-dkr',
      garageName: 'Garage Dakar Plateau',
      isEmailVerified: true,
      isPhoneVerified: true,
      isProfileComplete: true,
      createdAt: DateTime(2025, 9, 20),
      lastLogin: DateTime.now(),
    ),
    User(
      id: 'mock-super-admin-1',
      email: 'super@procolis.test',
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
      senderEmail: 'client@procolis.test',
      receiverName: 'Cheikh Fall',
      receiverPhone: '+221781112233',
      receiverAddress: 'Quartier Escale, Saint-Louis',
      description: 'Documents administratifs',
      weight: 0.4,
      type: ParcelType.document,
      status: ParcelStatus.pending,
      departureGarageId: 'garage-dkr',
      departureGarageName: 'Garage Dakar Plateau',
      arrivalGarageId: 'garage-stl',
      arrivalGarageName: 'Garage Saint-Louis',
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
      senderEmail: 'client@procolis.test',
      receiverName: 'Mariama Camara',
      receiverPhone: '+221786667788',
      receiverAddress: 'Grand Standing, Thiès',
      description: 'Petit carton fragile',
      weight: 3.2,
      type: ParcelType.fragile,
      status: ParcelStatus.inTransit,
      departureGarageId: 'garage-dkr',
      departureGarageName: 'Garage Dakar Plateau',
      arrivalGarageId: 'garage-ths',
      arrivalGarageName: 'Garage Thiès',
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
      senderEmail: 'client@procolis.test',
      receiverName: 'Oumar Diallo',
      receiverPhone: '+221775554433',
      receiverAddress: 'Bambey centre',
      description: 'Sac de vêtements',
      weight: 7.5,
      type: ParcelType.package,
      status: ParcelStatus.free,
      departureGarageId: 'garage-dkr',
      departureGarageName: 'Garage Dakar Plateau',
      arrivalGarageId: 'garage-bby',
      arrivalGarageName: 'Garage Bambey',
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
      senderEmail: 'client@procolis.test',
      receiverName: 'Ndeye Sarr',
      receiverPhone: '+221789998877',
      receiverAddress: 'Keur Massar',
      description: 'Téléphone emballé',
      weight: 0.8,
      type: ParcelType.valuable,
      status: ParcelStatus.delivered,
      departureGarageId: 'garage-ths',
      departureGarageName: 'Garage Thiès',
      arrivalGarageId: 'garage-dkr',
      arrivalGarageName: 'Garage Dakar Plateau',
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
                parcel.departureGarageId == user.garageId ||
                parcel.arrivalGarageId == user.garageId)
            .toList();
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
}
