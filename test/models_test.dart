import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/garage.dart';
import 'package:procolis/models/payment.dart';
import 'package:procolis/models/score.dart';

void main() {
  group('User Model', () {
    test('parses user from JSON correctly', () {
      final json = {
        'id': 'user-001',
        'email': 'test@procolis.test',
        'phone': '+221771234567',
        'fullName': 'John Doe',
        'role': 'client',
        'status': 'active',
        'pin': '123456',
        'city': 'Dakar',
        'region': 'Dakar',
        'address': '123 Rue Principale',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'lastLogin': '2026-06-01T00:00:00.000Z',
      };

      final user = User.fromJson(json);

      expect(user.id, 'user-001');
      expect(user.email, 'test@procolis.test');
      expect(user.phone, '+221771234567');
      expect(user.fullName, 'John Doe');
      expect(user.role, UserRole.client);
      expect(user.status, UserStatus.active);
      expect(user.city, 'Dakar');
      expect(user.region, 'Dakar');
      expect(user.address, '123 Rue Principale');
    });

    test('correctly identifies role getters', () {
      final client = User(id: '1', role: UserRole.client);
      final driver = User(id: '2', role: UserRole.driver);
      final admin = User(id: '3', role: UserRole.admin);
      final superAdmin = User(id: '4', role: UserRole.superAdmin);

      expect(client.isClient, true);
      expect(client.isDriver, false);
      expect(driver.isClient, false);
      expect(driver.isDriver, true);
      expect(admin.isAdmin, true);
      expect(superAdmin.isSuperAdmin, true);
    });

    test('detects driver availability correctly', () {
      final available = User(
        id: '1',
        role: UserRole.driver,
        driverStatus: DriverStatus.available,
      );
      final offline = User(
        id: '2',
        role: UserRole.driver,
        driverStatus: DriverStatus.offline,
      );
      final busy = User(
        id: '3',
        role: UserRole.driver,
        driverStatus: DriverStatus.busy,
      );
      final nonDriver = User(id: '4', role: UserRole.client);

      expect(available.isDriverAvailable, true);
      expect(available.isDriverBusy, false);
      expect(offline.isDriverAvailable, false);
      expect(offline.isDriverOffline, true);
      expect(busy.isDriverBusy, true);
      expect(nonDriver.isDriverAvailable, false);
      expect(nonDriver.isDriver, false);
    });

    test('serializes to JSON correctly', () {
      final user = User(
        id: 'user-001',
        email: 'test@test.com',
        phone: '+221771234567',
        fullName: 'John Doe',
        role: UserRole.client,
        status: UserStatus.active,
        city: 'Dakar',
        region: 'Dakar',
      );

      final json = user.toJson();

      expect(json['id'], 'user-001');
      expect(json['email'], 'test@test.com');
      expect(json['role'], 'client');
      expect(json['status'], 'active');
    });
  });

  group('Parcel Model', () {
    test('parses parcel from JSON correctly', () {
      final json = {
        'id': 'parcel-001',
        'trackingNumber': 'PC-2026-001',
        'senderId': 'user-001',
        'senderName': 'John Doe',
        'senderPhone': '+221771234567',
        'receiverName': 'Jane Smith',
        'receiverPhone': '+221789876543',
        'receiverAddress': '456 Rue Secondaire',
        'description': 'Documents importants',
        'weight': 2.5,
        'type': 'document',
        'status': 'pending',
        'departureGarageId': 'garage-dkr',
        'departureGarageName': 'Garage Dakar',
        'arrivalGarageId': 'garage-ths',
        'arrivalGarageName': 'Garage Thies',
        'price': 3000,
        'totalAmount': 3500,
        'createdAt': '2026-01-01T00:00:00.000Z',
      };

      final parcel = Parcel.fromJson(json);

      expect(parcel.id, 'parcel-001');
      expect(parcel.trackingNumber, 'PC-2026-001');
      expect(parcel.senderName, 'John Doe');
      expect(parcel.receiverName, 'Jane Smith');
      expect(parcel.weight, 2.5);
      expect(parcel.type, ParcelType.document);
      expect(parcel.status, ParcelStatus.pending);
      expect(parcel.price, 3000);
      expect(parcel.totalAmount, 3500);
    });

    test('correctly identifies parcel status states', () {
      final pending = Parcel(id: '1', status: ParcelStatus.pending, createdAt: DateTime.now());
      final delivered = Parcel(id: '2', status: ParcelStatus.delivered, createdAt: DateTime.now());
      final cancelled = Parcel(id: '3', status: ParcelStatus.cancelled, createdAt: DateTime.now());
      final inTransit = Parcel(id: '4', status: ParcelStatus.inTransit, createdAt: DateTime.now());

      expect(pending.status, ParcelStatus.pending);
      expect(delivered.isFinished, true);
      expect(cancelled.isFinished, true);
      expect(inTransit.status, ParcelStatus.inTransit);
    });

    test('parses bids from JSON', () {
      final json = {
        'id': 'parcel-001',
        'trackingNumber': 'PC-001',
        'bids': [
          {
            'id': 'bid-001',
            'parcelId': 'parcel-001',
            'driverId': 'driver-001',
            'driverName': 'Moussa Ndiaye',
            'driverPhone': '+221772345678',
            'price': 5000,
            'message': 'Disponible ce soir',
            'createdAt': '2026-01-01T12:00:00.000Z',
          }
        ],
        'createdAt': '2026-01-01T00:00:00.000Z',
      };

      final parcel = Parcel.fromJson(json);

      expect(parcel.bids, isNotNull);
      expect(parcel.bids!.length, 1);
      expect(parcel.bids![0].driverName, 'Moussa Ndiaye');
      expect(parcel.bids![0].price, 5000);
    });

    test('copyWith preserves fields', () {
      final original = Parcel(
        id: 'parcel-001',
        trackingNumber: 'PC-001',
        senderName: 'John',
        status: ParcelStatus.pending,
        weight: 2.5,
        price: 3000,
        createdAt: DateTime(2026),
      );

      final modified = original.copyWith(
        status: ParcelStatus.delivered,
        driverName: 'Driver X',
      );

      expect(modified.id, original.id);
      expect(modified.trackingNumber, original.trackingNumber);
      expect(modified.senderName, original.senderName);
      expect(modified.weight, original.weight);
      expect(modified.status, ParcelStatus.delivered);
      expect(modified.driverName, 'Driver X');
      expect(original.status, ParcelStatus.pending);
      expect(original.driverName, isNull);
    });
  });

  group('Garage Model', () {
    test('parses garage from JSON', () {
      final json = {
        'id': 'garage-001',
        'name': 'Garage Dakar Plateau',
        'city': 'Dakar',
        'region': 'Dakar',
        'address': 'Plateau, Rue 10',
        'phone': '+221338888888',
        'latitude': 14.6937,
        'longitude': -17.4441,
        'driversCount': 15,
        'parcelsCount': 250,
        'revenue': 5000000,
      };

      final garage = Garage.fromJson(json);

      expect(garage.id, 'garage-001');
      expect(garage.name, 'Garage Dakar Plateau');
      expect(garage.city, 'Dakar');
      expect(garage.driversCount, 15);
      expect(garage.parcelsCount, 250);
      expect(garage.revenue, 5000000);
    });
  });

  group('Payment Model', () {
    test('parses payment from JSON', () {
      final json = {
        'id': 'pay-001',
        'userId': 'user-001',
        'parcelId': 'parcel-001',
        'amount': 5000.0,
        'currency': 'XOF',
        'method': 'wave',
        'status': 'completed',
        'transactionId': 'txn-12345',
        'createdAt': '2026-01-01T00:00:00.000Z',
      };

      final payment = Payment.fromJson(json);

      expect(payment.id, 'pay-001');
      expect(payment.amount, 5000.0);
      expect(payment.method, PaymentMethod.wave);
      expect(payment.status, PaymentStatus.completed);
    });
  });

  group('Score Model', () {
    test('parses score from JSON', () {
      final json = {
        'userId': 'user-001',
        'points': 150,
        'transactions': [
          {
            'id': 'txn-001',
            'amount': 100,
            'type': 'credit',
            'description': 'Recharge de points',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'status': 'completed',
          }
        ],
      };

      final score = Score.fromJson(json);

      expect(score.points, 150);
      expect(score.transactions.length, 1);
      expect(score.transactions[0].amount, 100);
      expect(score.transactions[0].type, 'credit');
    });
  });

  group('UserRole enum', () {
    test('fromString parses correctly', () {
      expect(UserRole.fromString('client'), UserRole.client);
      expect(UserRole.fromString('driver'), UserRole.driver);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('super_admin'), UserRole.superAdmin);
      expect(UserRole.fromString('unknown'), UserRole.client);
    });

    test('each role has correct value and label', () {
      expect(UserRole.client.value, 'client');
      expect(UserRole.client.label, 'Client');
      expect(UserRole.driver.value, 'driver');
      expect(UserRole.driver.label, 'Chauffeur');
      expect(UserRole.admin.value, 'admin');
      expect(UserRole.admin.label, 'Admin Garage');
      expect(UserRole.superAdmin.value, 'super_admin');
      expect(UserRole.superAdmin.label, 'Super Admin');
    });
  });

  group('DriverStatus enum', () {
    test('fromString parses correctly', () {
      expect(DriverStatus.fromString('available'), DriverStatus.available);
      expect(DriverStatus.fromString('busy'), DriverStatus.busy);
      expect(DriverStatus.fromString('offline'), DriverStatus.offline);
      expect(DriverStatus.fromString('unknown'), DriverStatus.offline);
    });
  });
}
