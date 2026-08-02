import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/utils/parcel_offer_helpers.dart';

void main() {
  User buildUser({String? city, String? zoneName}) {
    return User(
      id: 'driver-1',
      email: 'driver@example.com',
      phone: '+221770000000',
      fullName: 'Chauffeur Test',
      role: UserRole.driver,
      city: city,
      zoneName: zoneName,
      createdAt: DateTime(2026),
    );
  }

  Parcel buildParcel({
    required String departure,
    List<Bid> bids = const [],
  }) {
    return Parcel(
      id: 'parcel-1',
      trackingNumber: 'PC-TEST',
      senderId: 'client-1',
      senderName: 'Client Test',
      senderPhone: '+221780000000',
      receiverName: 'Destinataire',
      receiverPhone: '+221760000000',
      description: 'Colis',
      weight: 2,
      type: ParcelType.package,
      status: ParcelStatus.free,
      departureZoneId: 'zone-1',
      departureZoneName: departure,
      bids: bids,
      createdAt: DateTime(2026),
    );
  }

  group('filtrage de la zone utilisateur', () {
    test('compare exactement la zone sans tenir compte de la casse', () {
      final user = buildUser(city: '  Dakar Plateau ');

      expect(
        parcelStartsInUserZone(
          buildParcel(departure: 'dAkAr   pLaTeAu'),
          user,
        ),
        isTrue,
      );
    });

    test('refuse une zone qui contient seulement le même nom', () {
      final user = buildUser(city: 'Dakar');

      expect(
        parcelStartsInUserZone(
          buildParcel(departure: 'Garage Dakar'),
          user,
        ),
        isFalse,
      );
    });

    test('utilise la zone de rattachement si la ville est absente', () {
      final user = buildUser(zoneName: 'Zone Nord');

      expect(
        parcelStartsInUserZone(
          buildParcel(departure: 'zone nord'),
          user,
        ),
        isTrue,
      );
    });
  });

  test('retrouve une offre déjà envoyée par le chauffeur', () {
    final bid = Bid(
      id: 'bid-1',
      parcelId: 'parcel-1',
      driverId: 'driver-1',
      driverName: 'Chauffeur Test',
      driverPhone: '+221770000000',
      price: 5000,
      createdAt: DateTime(2026),
    );
    final parcel = buildParcel(departure: 'Dakar', bids: [bid]);

    expect(findUserBid(parcel, 'driver-1')?.id, 'bid-1');
    expect(findUserBid(parcel, 'driver-2'), isNull);
  });

  test('retrouve une proposition client avec les variantes du contrat API', () {
    final offers = [
      {'id': 'offer-1', 'clientId': 'client-1'},
      {
        'id': 'offer-2',
        'client': {'id': 'client-2'},
      },
    ];

    expect(
      findUserAdvertisementOffer(offers, 'client-1')?['id'],
      'offer-1',
    );
    expect(
      findUserAdvertisementOffer(offers, 'client-2')?['id'],
      'offer-2',
    );
  });
}
