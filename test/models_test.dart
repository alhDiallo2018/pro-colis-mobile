import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/models/address.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/garage.dart';
import 'package:procolis/models/payment.dart';
import 'package:procolis/models/notification.dart';
import 'package:procolis/models/score.dart';
import 'package:procolis/models/stats.dart';
import 'package:procolis/models/wallet.dart';
import 'package:procolis/models/zone.dart';

void main() {
  group('User Model', () {
    User buildUser({
      required String id,
      required UserRole role,
      DriverStatus? driverStatus,
      String email = 'test@test.com',
      String phone = '+221770000000',
      String fullName = 'Utilisateur Test',
      String? city,
      String? region,
    }) {
      return User(
        id: id,
        email: email,
        phone: phone,
        fullName: fullName,
        role: role,
        status: UserStatus.active,
        driverStatus: driverStatus,
        city: city,
        region: region,
        createdAt: DateTime(2026),
      );
    }

    test('parses user from JSON correctly', () {
      final json = {
        'id': 'user-001',
        'email': 'test@sendprocolis.test',
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
      expect(user.email, 'test@sendprocolis.test');
      expect(user.phone, '+221771234567');
      expect(user.fullName, 'John Doe');
      expect(user.role, UserRole.client);
      expect(user.status, UserStatus.active);
      expect(user.city, 'Dakar');
      expect(user.region, 'Dakar');
      expect(user.address, '123 Rue Principale');
    });

    test('correctly identifies role getters', () {
      final client = buildUser(id: '1', role: UserRole.client);
      final driver = buildUser(id: '2', role: UserRole.driver);
      final admin = buildUser(id: '3', role: UserRole.admin);
      final superAdmin = buildUser(id: '4', role: UserRole.superAdmin);

      expect(client.isClient, true);
      expect(client.isDriver, false);
      expect(driver.isClient, false);
      expect(driver.isDriver, true);
      expect(admin.isAdmin, true);
      expect(superAdmin.isSuperAdmin, true);
    });

    test('detects driver availability correctly', () {
      final available = buildUser(
        id: '1',
        role: UserRole.driver,
        driverStatus: DriverStatus.available,
      );
      final offline = buildUser(
        id: '2',
        role: UserRole.driver,
        driverStatus: DriverStatus.offline,
      );
      final busy = buildUser(
        id: '3',
        role: UserRole.driver,
        driverStatus: DriverStatus.busy,
      );
      final nonDriver = buildUser(id: '4', role: UserRole.client);

      expect(available.isDriverAvailable, true);
      expect(available.isDriverBusy, false);
      expect(offline.isDriverAvailable, false);
      expect(offline.isDriverOffline, true);
      expect(busy.isDriverBusy, true);
      expect(nonDriver.isDriverAvailable, false);
      expect(nonDriver.isDriver, false);
    });

    test('serializes to JSON correctly', () {
      final user = buildUser(
        id: 'user-001',
        email: 'test@test.com',
        phone: '+221771234567',
        fullName: 'John Doe',
        role: UserRole.client,
        city: 'Dakar',
        region: 'Dakar',
      );

      final json = user.toJson();

      expect(json['id'], 'user-001');
      expect(json['email'], 'test@test.com');
      expect(json['role'], 'client');
      expect(json['status'], 'active');
    });

    test('preserves the shared support role through a JSON round-trip', () {
      final user = User.fromJson({
        'id': 'support-001',
        'role': 'support',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(user.role, UserRole.support);
      expect(user.isSupportShared, true);
      expect(user.isSupport, true);
      expect(user.isSuperAdmin, false);
      expect(user.toJson()['role'], 'support');
    });
  });

  group('Parcel Model', () {
    // Centralise les champs métier obligatoires afin que chaque test reste
    // focalisé sur la propriété qu'il vérifie.
    Parcel buildParcel({
      required String id,
      ParcelStatus status = ParcelStatus.pending,
      double? price,
      double? negotiatedPrice,
      String? selectedBidId,
      List<Bid> bids = const [],
      String? paymentStatus,
      String trackingNumber = 'PC-TEST',
      String senderName = 'Expéditeur',
      double weight = 1,
    }) {
      return Parcel(
        id: id,
        trackingNumber: trackingNumber,
        senderName: senderName,
        senderPhone: '+221770000001',
        receiverName: 'Destinataire',
        receiverPhone: '+221770000002',
        description: 'Colis de test',
        weight: weight,
        type: ParcelType.package,
        status: status,
        departureZoneId: 'garage-001',
        departureZoneName: 'Garage Dakar',
        price: price,
        negotiatedPrice: negotiatedPrice,
        selectedBidId: selectedBidId,
        bids: bids,
        paymentStatus: paymentStatus,
        createdAt: DateTime(2026),
      );
    }

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
        'departureZoneId': 'garage-dkr',
        'departureZoneName': 'Garage Dakar',
        'arrivalZoneId': 'garage-ths',
        'arrivalZoneName': 'Garage Thies',
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
      final pending = buildParcel(id: '1');
      final delivered = buildParcel(id: '2', status: ParcelStatus.delivered);
      final cancelled = buildParcel(id: '3', status: ParcelStatus.cancelled);
      final inTransit = buildParcel(id: '4', status: ParcelStatus.inTransit);

      expect(pending.status, ParcelStatus.pending);
      expect(delivered.isFinished, true);
      expect(cancelled.isFinished, true);
      expect(inTransit.status, ParcelStatus.inTransit);
    });

    test('agreedPrice keeps the negotiated amount over the base price', () {
      final parcel = buildParcel(
        id: 'parcel-001',
        status: ParcelStatus.confirmed,
        price: 5000,
        negotiatedPrice: 4500,
      );

      expect(parcel.agreedPrice, 4500);
      expect(parcel.payableAmount, 4500);
      expect(parcel.canBePaid, true);
    });

    test('agreedPrice falls back to the accepted bid then to the base price',
        () {
      final withAcceptedBid = buildParcel(
        id: 'parcel-002',
        status: ParcelStatus.confirmed,
        price: 5000,
        selectedBidId: 'bid-1',
        bids: [
          Bid(
            id: 'bid-1',
            parcelId: 'parcel-002',
            driverId: 'driver-1',
            driverName: 'Moussa',
            driverPhone: '+221770000000',
            price: 4200,
            status: BidStatus.accepted,
            createdAt: DateTime(2026),
          ),
        ],
      );
      final withoutNegotiation = buildParcel(
        id: 'parcel-003',
        status: ParcelStatus.confirmed,
        price: 5000,
      );

      expect(withAcceptedBid.agreedPrice, 4200);
      expect(withoutNegotiation.agreedPrice, 5000);
    });

    test('a cancelled or already paid parcel cannot be paid', () {
      final cancelled = buildParcel(
        id: 'parcel-004',
        status: ParcelStatus.cancelled,
        price: 5000,
        negotiatedPrice: 4500,
      );
      final paid = buildParcel(
        id: 'parcel-005',
        status: ParcelStatus.inTransit,
        price: 5000,
        paymentStatus: 'completed',
      );
      final withoutPrice = buildParcel(
        id: 'parcel-006',
      );

      expect(cancelled.canBePaid, false);
      expect(paid.canBePaid, false);
      expect(withoutPrice.canBePaid, false);
      expect(withoutPrice.payableAmount, 0);
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
      expect(parcel.bids.length, 1);
      expect(parcel.bids[0].driverName, 'Moussa Ndiaye');
      expect(parcel.bids[0].price, 5000);
    });

    test('copyWith preserves fields', () {
      final original = buildParcel(
        id: 'parcel-001',
        trackingNumber: 'PC-001',
        senderName: 'John',
        weight: 2.5,
        price: 3000,
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

    test('serializes bids with the camelCase API contract', () {
      final bid = Bid(
        id: 'bid-001',
        parcelId: 'parcel-001',
        driverId: 'driver-001',
        driverName: 'Moussa',
        driverPhone: '+221770000000',
        price: 4500,
        createdAt: DateTime.utc(2026),
      );

      final json = bid.toJson();

      expect(json['parcelId'], 'parcel-001');
      expect(json['driverId'], 'driver-001');
      expect(json['createdAt'], '2026-01-01T00:00:00.000Z');
      expect(json.containsKey('parcel_id'), false);
      expect(Bid.fromJson(json).driverId, 'driver-001');
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

    test('serializes counters and dates in camelCase', () {
      final garage = Garage.fromJson({
        'id': 'garage-001',
        'name': 'Garage Dakar',
        'city': 'Dakar',
        'region': 'Dakar',
        'drivers_count': 3,
        'parcels_count': 8,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-02T00:00:00.000Z',
      });

      final json = garage.toJson();

      expect(json['driversCount'], 3);
      expect(json['parcelsCount'], 8);
      expect(json['isActive'], true);
      expect(json.containsKey('drivers_count'), false);
      expect(Garage.fromJson(json).parcelsCount, 8);
    });
  });

  group('WS1 transport contract', () {
    test('normalizes every wallet transaction type to Prisma lowercase', () {
      const values = [
        'deposit',
        'commission',
        'bonus',
        'adjustment',
        'refund',
        'correction',
        'penalty',
        'withdrawal',
      ];

      for (final value in values) {
        final transaction = WalletTransaction.fromJson({
          'id': 'transaction-$value',
          'userId': 'driver-001',
          'walletId': 'wallet-001',
          'amount': 1000,
          'type': value.toUpperCase(),
          'description': value,
          'createdAt': '2026-01-01T00:00:00.000Z',
        });

        expect(transaction.type.value, value);
        expect(transaction.toJson()['type'], value);
      }
    });

    test('reads zone radius as decimal kilometres and writes radiusKm', () {
      final zone = Zone.fromJson({
        'id': 'zone-001',
        'name': 'Dakar',
        'latitude': 14.7167,
        'longitude': -17.4677,
        'radius': 12.5,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(zone.radiusKm, 12.5);
      expect(zone.toJson()['radiusKm'], 12.5);
      expect(zone.toJson().containsKey('radius'), false);
    });

    test('recognizes every notification type emitted by the API', () {
      const emittedTypes = [
        'bid_created',
        'bid_accepted',
        'ad_offer',
        'ad_offer_accepted',
        'ad_offer_rejected',
        'parcel_delivered',
        'driver_assigned',
        'delivery_completed',
        'delivery_paid',
        'payment_confirmed',
        'payment_cash',
        'message',
        'support_reply',
        'pin_reset',
        'deposit',
        'commission',
        'commission_paid',
        'commission_deduction',
        'commitment_fee',
        'commitment_refund',
        'purchase',
        'refund',
        'score_credited',
        'wallet_recharged',
        'wallet_debited',
        'withdrawal',
        'withdrawal_requested',
        'withdrawal_completed',
        'withdrawal_failed',
        'withdrawal_cancelled',
        'admin_credit',
        'admin_debit',
        'admin_driver_credited',
        'admin_payment_confirmed',
      ];

      for (final value in emittedTypes) {
        final type = NotificationType.fromString(value);
        expect(type, isNot(NotificationType.info), reason: value);
        expect(type.value, value);
      }
    });

    test('round-trips notifications using camelCase keys', () {
      final notification = Notification.fromJson({
        'id': 'notification-001',
        'user_id': 'user-001',
        'parcel_id': 'parcel-001',
        'type': 'payment_confirmed',
        'title': 'Paiement',
        'body': 'Paiement reçu',
        'is_read': true,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      final json = notification.toJson();

      expect(notification.type, NotificationType.paymentConfirmed);
      expect(json['userId'], 'user-001');
      expect(json['parcelId'], 'parcel-001');
      expect(json['isRead'], true);
      expect(json.containsKey('user_id'), false);
      expect(
          Notification.fromJson(json).type, NotificationType.paymentConfirmed);
    });
  });

  group('WS3 profile data', () {
    test('parses decimal address coordinates and writes camelCase payload', () {
      final address = Address.fromJson({
        'id': 'address-001',
        'user_id': 'user-001',
        'label': 'Bureau',
        'address': 'Plateau, Dakar',
        'city': 'Dakar',
        'latitude': '14.6700000',
        'longitude': '-17.4300000',
        'is_default': true,
      });

      expect(address.latitude, 14.67);
      expect(address.longitude, -17.43);
      expect(address.isDefault, true);
      expect(address.toPayload()['isDefault'], true);
      expect(address.toPayload().containsKey('is_default'), false);
    });

    test('normalizes role statistics returned as strings or numbers', () {
      final userStats = UserStats.fromJson({
        'totalParcels': '12',
        'activeParcels': 3,
        'deliveredParcels': 8.0,
        'pendingBids': 2,
        'unreadNotifications': 4,
        'scoreBalance': '150',
      });
      final zoneStats = ZoneStats.fromJson({
        'totalParcels': 20,
        'activeParcels': '5',
        'deliveredToday': 2,
        'activeDrivers': 7,
        'revenue': '125000.50',
        'parcelsByStatus': {'pending': '3', 'delivered': 17},
      });

      expect(userStats.totalParcels, 12);
      expect(userStats.scoreBalance, 150);
      expect(zoneStats.revenue, 125000.5);
      expect(zoneStats.parcelsByStatus['pending'], 3);
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

    test('derives the channel from the method when absent', () {
      Payment build(String method) => Payment.fromJson({
            'id': 'pay-channel',
            'userId': 'user-001',
            'amount': 1000,
            'method': method,
            'status': 'pending',
            'createdAt': '2026-01-01T00:00:00.000Z',
          });

      expect(build('wave').channel, PaymentChannel.platform);
      expect(build('card').channel, PaymentChannel.platform);
      expect(build('cash').channel, PaymentChannel.cash);
      expect(build('wave').isCash, false);
      expect(build('cash').isCash, true);
    });

    test('a declared cash collection awaits admin validation', () {
      final declared = Payment.fromJson({
        'id': 'pay-cash',
        'userId': 'driver-001',
        'parcelId': 'parcel-001',
        'amount': 12500,
        'method': 'cash',
        'status': 'processing',
        'cashCollectionPoint': 'receiver_delivery',
        'declaredAt': '2026-01-02T10:00:00.000Z',
        'createdAt': '2026-01-02T10:00:00.000Z',
      });

      expect(declared.isCashDeclared, true);
      expect(declared.awaitsCashValidation, true);
      expect(
          declared.cashCollectionPoint, CashCollectionPoint.receiverDelivery);
      // Le libellé « en cours » n'a pas de sens pour des espèces déjà reçues.
      expect(declared.statusLabel, 'Encaissement déclaré');

      final validated = declared.copyWith(
        status: PaymentStatus.completed,
        validatedAt: DateTime(2026, 1, 3),
      );
      expect(validated.awaitsCashValidation, false);
      expect(validated.statusLabel, 'Encaissement validé');
    });

    test('reads the declaration fields nested in metadata', () {
      final payment = Payment.fromJson({
        'id': 'pay-meta',
        'userId': 'driver-001',
        'amount': 8000,
        'method': 'cash',
        'status': 'processing',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'metadata': {
          'cashCollectionPoint': 'sender_pickup',
          'declaredByName': 'Moussa Ndiaye',
          'declarationNote': 'Remis au garage.',
        },
      });

      expect(payment.cashCollectionPoint, CashCollectionPoint.senderPickup);
      expect(payment.declaredByName, 'Moussa Ndiaye');
      expect(payment.declarationNote, 'Remis au garage.');
    });

    test('accepts a Prisma Decimal amount serialized as a string', () {
      final payment = Payment.fromJson({
        'id': 'pay-decimal',
        'userId': 'driver-001',
        'amount': '12500.50',
        'method': 'cash',
        'status': 'processing',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(payment.amount, 12500.50);
    });

    test('parses the accepted channels list, ignoring unknown values', () {
      expect(
        PaymentChannel.listFrom(['cash', 'platform']),
        [PaymentChannel.cash, PaymentChannel.platform],
      );
      // Une méthode connue vaut son canal ; le reste est ignoré.
      expect(PaymentChannel.listFrom(['wave']), [PaymentChannel.platform]);
      expect(PaymentChannel.listFrom(['bitcoin']), isEmpty);
      expect(PaymentChannel.listFrom(null), isEmpty);
      // Dédoublonnage : deux méthodes plateforme ne font qu'un canal.
      expect(
        PaymentChannel.listFrom(['wave', 'card', 'cash']),
        [PaymentChannel.cash, PaymentChannel.platform],
      );
    });
  });

  group('Parcel — canal de paiement', () {
    Parcel parcel({
      ParcelStatus status = ParcelStatus.delivered,
      String? paymentChannel,
      String? cashCollectionPoint,
      String? paymentStatus,
      DateTime? pickupDate,
      double price = 10000,
    }) {
      return Parcel.fromJson({
        'id': 'parcel-pay',
        'trackingNumber': 'PC-PAY',
        'status': status.value,
        'price': price,
        'paymentChannel': paymentChannel,
        'cashCollectionPoint': cashCollectionPoint,
        'paymentStatus': paymentStatus,
        'pickupDate': pickupDate?.toIso8601String(),
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
    }

    test('falls back to cash when no channel is set', () {
      final legacy = parcel();
      expect(legacy.resolvedPaymentChannel, PaymentChannel.cash);
      expect(legacy.isCashPayment, true);
      // Un colis en espèces ne doit jamais proposer le paiement en ligne.
      expect(legacy.canBePaidOnline, false);
    });

    test('a platform parcel can be paid online, never in cash', () {
      final online = parcel(paymentChannel: 'platform');
      expect(online.isPlatformPayment, true);
      expect(online.canBePaidOnline, true);
      expect(online.needsCashDeclaration, false);
    });

    test('the driver must declare once the collection milestone is passed', () {
      // Le destinataire paie : la déclaration n'est due qu'après la livraison.
      final beforeDelivery = parcel(
        status: ParcelStatus.inTransit,
        paymentChannel: 'cash',
        cashCollectionPoint: 'receiver_delivery',
      );
      expect(beforeDelivery.needsCashDeclaration, false);

      final afterDelivery = parcel(
        status: ParcelStatus.delivered,
        paymentChannel: 'cash',
        cashCollectionPoint: 'receiver_delivery',
      );
      expect(afterDelivery.needsCashDeclaration, true);

      // L'expéditeur paie : la déclaration est due dès le ramassage.
      final afterPickup = parcel(
        status: ParcelStatus.pickedUp,
        paymentChannel: 'cash',
        cashCollectionPoint: 'sender_pickup',
      );
      expect(afterPickup.needsCashDeclaration, true);

      final beforePickup = parcel(
        status: ParcelStatus.confirmed,
        paymentChannel: 'cash',
        cashCollectionPoint: 'sender_pickup',
      );
      expect(beforePickup.needsCashDeclaration, false);
    });

    test('no declaration due once declared, paid or cancelled', () {
      final declared = parcel(
        paymentChannel: 'cash',
        cashCollectionPoint: 'receiver_delivery',
        paymentStatus: 'processing',
      );
      expect(declared.isCashDeclared, true);
      expect(declared.needsCashDeclaration, false);

      final paid = parcel(
        paymentChannel: 'cash',
        cashCollectionPoint: 'receiver_delivery',
        paymentStatus: 'completed',
      );
      expect(paid.needsCashDeclaration, false);

      final cancelled = parcel(
        status: ParcelStatus.cancelled,
        paymentChannel: 'cash',
        cashCollectionPoint: 'receiver_delivery',
      );
      expect(cancelled.needsCashDeclaration, false);

      final free = parcel(
        paymentChannel: 'cash',
        cashCollectionPoint: 'receiver_delivery',
        price: 0,
      );
      expect(free.needsCashDeclaration, false);
    });

    test('parses the channels accepted by the driver', () {
      final withChannels = Parcel.fromJson({
        'id': 'parcel-acc',
        'trackingNumber': 'PC-ACC',
        'status': 'free',
        'acceptedPaymentChannels': ['cash'],
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(withChannels.acceptedPaymentChannels, [PaymentChannel.cash]);
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
      expect(
        UserRole.fromString('support_technique'),
        UserRole.supportTechnique,
      );
      expect(
        UserRole.fromString('support-tech'),
        UserRole.supportTechnique,
      );
      expect(
        UserRole.fromString('support technic'),
        UserRole.supportTechnique,
      );
      expect(
        UserRole.fromString('support_commercial'),
        UserRole.supportCommercial,
      );
      expect(
        UserRole.fromString('supportComm'),
        UserRole.supportCommercial,
      );
      expect(UserRole.fromString('support'), UserRole.support);
      expect(UserRole.fromString('super_admin'), UserRole.superAdmin);
      expect(UserRole.fromString('unknown'), UserRole.client);
    });

    test('parses support roles returned as nested API objects', () {
      final technique = User.fromJson({
        'id': 'support-tech-1',
        'role': {'name': 'support_tech'},
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      final commercial = User.fromJson({
        'id': 'support-com-1',
        'userRole': {'value': 'support_commercial'},
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(technique.role, UserRole.supportTechnique);
      expect(commercial.role, UserRole.supportCommercial);
    });

    test('each role has correct value and label', () {
      expect(UserRole.client.value, 'client');
      expect(UserRole.client.label, 'Client');
      expect(UserRole.driver.value, 'driver');
      expect(UserRole.driver.label, 'Chauffeur');
      expect(UserRole.admin.value, 'admin');
      expect(UserRole.admin.label, 'Admin Zone');
      expect(UserRole.support.value, 'support');
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
