// Suivi GPS temps réel : le modèle DriverLocation doit tolérer les variantes
// du contrat API et ne jamais présenter une position absente comme réelle.

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/driver_location.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/services/location_service.dart';

void main() {
  test('LocationService conserve une instance de suivi applicative unique', () {
    expect(identical(LocationService(), LocationService()), isTrue);
  });

  group('DriverLocation.fromJson', () {
    test('parse les champs camelCase', () {
      final loc = DriverLocation.fromJson({
        'id': 'l-1',
        'driverId': 'd-1',
        'parcelId': 'p-1',
        'latitude': 14.6937,
        'longitude': -17.4441,
        'accuracy': 12.5,
        'createdAt': '2026-09-11T10:00:00.000Z',
      });

      expect(loc.latitude, closeTo(14.6937, 0.0001));
      expect(loc.longitude, closeTo(-17.4441, 0.0001));
      expect(loc.accuracy, closeTo(12.5, 0.001));
      expect(loc.driverId, 'd-1');
      expect(loc.parcelId, 'p-1');
      expect(loc.recordedAt, DateTime.parse('2026-09-11T10:00:00.000Z'));
    });

    test('accepte snake_case et timestamp comme horodatage', () {
      final loc = DriverLocation.fromJson({
        'driver_id': 'd-2',
        'parcel_id': 'p-2',
        'lat': '14.7',
        'lng': '-17.4',
        'timestamp': '2026-09-11T11:00:00.000Z',
      });

      expect(loc.latitude, closeTo(14.7, 0.001));
      expect(loc.longitude, closeTo(-17.4, 0.001));
      expect(loc.recordedAt, isNotNull);
    });

    test('des coordonnées toutes nulles ne sont pas exploitables', () {
      final loc = DriverLocation.fromJson({'latitude': 0, 'longitude': 0});
      expect(loc.hasCoordinates, isFalse);
    });

    test('une réponse partielle ou hors plage est refusée', () {
      expect(
        DriverLocation.fromJson({'longitude': -17.4}).hasCoordinates,
        isFalse,
      );
      expect(
        DriverLocation.fromJson({
          'latitude': 95,
          'longitude': -17.4,
        }).hasCoordinates,
        isFalse,
      );
    });

    test('une position réelle a des coordonnées exploitables', () {
      final loc =
          DriverLocation.fromJson({'latitude': 14.6937, 'longitude': -17.4441});
      expect(loc.hasCoordinates, isTrue);
    });
  });

  group('DriverLocation fraîcheur', () {
    test('isStale détecte une position trop ancienne', () {
      final now = DateTime.parse('2026-09-11T10:10:00.000Z');
      final old = DriverLocation.fromJson({
        'latitude': 14.0,
        'longitude': -17.0,
        'createdAt': '2026-09-11T10:00:00.000Z',
      });
      expect(old.isStale(now), isTrue);

      final fresh = DriverLocation.fromJson({
        'latitude': 14.0,
        'longitude': -17.0,
        'createdAt': '2026-09-11T10:09:00.000Z',
      });
      expect(fresh.isStale(now), isFalse);
    });

    test('sans horodatage, la position est considérée comme obsolète', () {
      final loc =
          DriverLocation.fromJson({'latitude': 14.0, 'longitude': -17.0});
      expect(loc.isStale(DateTime.now()), isTrue);
    });
  });

  group('Parcel.isBeingTransported', () {
    Parcel parcelWith(ParcelStatus status) => Parcel(
          id: 'p-1',
          trackingNumber: 'PC-TEST',
          senderName: 'A',
          senderPhone: '0',
          receiverName: 'B',
          receiverPhone: '0',
          description: '',
          weight: 1,
          type: ParcelType.package,
          status: status,
          departureZoneId: 'z',
          departureZoneName: 'Z',
          createdAt: DateTime.now(),
        );

    test('vrai uniquement quand le colis est entre les mains du chauffeur', () {
      expect(parcelWith(ParcelStatus.pending).isBeingTransported, isFalse);
      expect(parcelWith(ParcelStatus.confirmed).isBeingTransported, isFalse);
      expect(parcelWith(ParcelStatus.pickedUp).isBeingTransported, isTrue);
      expect(parcelWith(ParcelStatus.inTransit).isBeingTransported, isTrue);
      expect(parcelWith(ParcelStatus.arrived).isBeingTransported, isTrue);
      expect(
          parcelWith(ParcelStatus.outForDelivery).isBeingTransported, isTrue);
      expect(parcelWith(ParcelStatus.delivered).isBeingTransported, isFalse);
      expect(parcelWith(ParcelStatus.cancelled).isBeingTransported, isFalse);
    });
  });

  group('Parcel.driverLocation', () {
    Map<String, dynamic> parcelJson(dynamic driverLocation) => {
          'id': 'p-location',
          'trackingNumber': 'PC-LOCATION',
          'senderName': 'A',
          'senderPhone': '0',
          'receiverName': 'B',
          'receiverPhone': '0',
          'description': '',
          'weight': 1,
          'type': 'package',
          'status': 'in_transit',
          'departureZoneId': 'z',
          'departureZoneName': 'Zone',
          'createdAt': '2026-09-11T10:00:00.000Z',
          'driverLocation': driverLocation,
        };

    test('available=false reste une position absente', () {
      final parcel = Parcel.fromJson(parcelJson({'available': false}));
      expect(parcel.driverLocation, isNull);
    });

    test('une position disponible est conservée avec son horodatage', () {
      final parcel = Parcel.fromJson(parcelJson({
        'available': true,
        'latitude': 14.6937,
        'longitude': -17.4441,
        'updatedAt': '2026-09-11T10:01:00.000Z',
      }));
      expect(parcel.driverLocation, isNotNull);
      expect(parcel.driverLocation!.latitude, closeTo(14.6937, 0.0001));
      expect(
        parcel.driverLocation!.recordedAt,
        DateTime.parse('2026-09-11T10:01:00.000Z'),
      );
    });

    test('conserve les informations publiques réelles du chauffeur', () {
      final parcel = Parcel.fromJson({
        ...parcelJson({'available': false}),
        'driver': {
          'id': 'driver-1',
          'name': 'Awa Ndiaye',
          'rating': '4.7',
          'isVerified': true,
          'vehicleType': 'Fourgonnette',
        },
      });

      expect(parcel.driverRating, 4.7);
      expect(parcel.driverVerified, isTrue);
      expect(parcel.driverVehicleType, 'Fourgonnette');
    });
  });
}
