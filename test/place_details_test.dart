// Tests du modèle des lieux Google (PlaceResult / PlaceDetails) : on verrouille
// que la sélection d'un lieu ne perd ni le nom, ni l'adresse, ni les
// coordonnées, ni le placeId, et que le libellé affiché respecte la priorité
// attendue (adresse complète → quartier + ville → ville + pays).

import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/place.dart';

void main() {
  group('PlaceResult', () {
    test('parse la prédiction et son structured_formatting', () {
      final result = PlaceResult.fromJson({
        'description': 'Grand Dakar, Dakar, Sénégal',
        'place_id': 'ChIJp1',
        'structured_formatting': {
          'main_text': 'Grand Dakar',
          'secondary_text': 'Dakar, Sénégal',
        },
      });

      expect(result.placeId, 'ChIJp1');
      expect(result.mainText, 'Grand Dakar');
      expect(result.secondaryText, 'Dakar, Sénégal');
      expect(result.description, 'Grand Dakar, Dakar, Sénégal');
    });

    test('tolère l’absence de structured_formatting', () {
      final result =
          PlaceResult.fromJson({'description': 'Dakar', 'place_id': 'p'});
      expect(result.mainText, '');
      expect(result.secondaryText, '');
    });
  });

  group('PlaceDetails', () {
    test('conserve l’objet complet (placeId, nom, adresse, coordonnées)', () {
      const place = PlaceDetails(
        placeId: 'ChIJp1',
        name: 'Grand Dakar',
        formattedAddress: 'Grand Dakar, Dakar, Sénégal',
        city: 'Dakar',
        country: 'Sénégal',
        latitude: 14.7645,
        longitude: -17.4444,
      );

      expect(place.placeId, 'ChIJp1');
      expect(place.name, 'Grand Dakar');
      expect(place.formattedAddress, 'Grand Dakar, Dakar, Sénégal');
      expect(place.latitude, 14.7645);
      expect(place.longitude, -17.4444);
      expect(place.hasCoordinates, isTrue);
    });

    test('hasCoordinates est faux sans coordonnées', () {
      const place = PlaceDetails(name: 'Dakar');
      expect(place.hasCoordinates, isFalse);
    });

    test('label privilégie l’adresse complète', () {
      const place = PlaceDetails(
        name: 'Grand Dakar',
        formattedAddress: 'Grand Dakar, Dakar, Sénégal',
        city: 'Dakar',
        country: 'Sénégal',
      );
      expect(place.label, 'Grand Dakar, Dakar, Sénégal');
    });

    test('label retombe sur nom + ville, puis sur le nom', () {
      const withCity = PlaceDetails(name: 'Grand Yoff', city: 'Dakar');
      expect(withCity.label, 'Grand Yoff, Dakar');

      const nameOnly = PlaceDetails(name: 'Parcelles Assainies');
      expect(nameOnly.label, 'Parcelles Assainies');
    });

    test('label retombe au minimum sur ville + pays', () {
      const place = PlaceDetails(city: 'Thiès', country: 'Sénégal');
      expect(place.label, 'Thiès, Sénégal');
    });

    test('label est null quand rien n’est disponible', () {
      const place = PlaceDetails(latitude: 14.0, longitude: -17.0);
      expect(place.label, isNull);
    });

    test('fromComponents extrait ville / région / pays', () {
      final place = PlaceDetails.fromComponents(
        [
          {
            'types': ['country'],
            'long_name': 'Sénégal'
          },
          {
            'types': ['administrative_area_level_1'],
            'long_name': 'Dakar'
          },
          {
            'types': ['locality'],
            'long_name': 'Dakar'
          },
        ],
        placeId: 'ChIJ',
        name: 'Grand Dakar',
        formattedAddress: 'Grand Dakar, Dakar, Sénégal',
        latitude: 14.7645,
        longitude: -17.4444,
      );

      expect(place.city, 'Dakar');
      expect(place.region, 'Dakar');
      expect(place.country, 'Sénégal');
      expect(place.name, 'Grand Dakar');
      expect(place.latitude, 14.7645);
      expect(place.longitude, -17.4444);
    });

    test('fromComponents extrait le quartier avant la ville pour une zone', () {
      final place = PlaceDetails.fromComponents(
        [
          {
            'types': ['country'],
            'long_name': 'Sénégal'
          },
          {
            'types': ['locality'],
            'long_name': 'Dakar'
          },
          {
            'types': ['sublocality_level_1'],
            'long_name': 'Ouakam'
          },
        ],
        formattedAddress: 'Ouakam, Dakar, Sénégal',
        latitude: 14.72,
        longitude: -17.49,
      );

      expect(place.district, 'Ouakam');
      expect(place.zoneName, 'Ouakam');
      expect(place.hasGeographicLabel, isTrue);
    });

    test('refuse les faux noms de position et les coordonnées seules', () {
      const currentPosition = PlaceDetails(
        name: 'Ma position',
        latitude: 14.72,
        longitude: -17.49,
      );
      const coordinates = PlaceDetails(
        formattedAddress: '14.72000, -17.49000',
        latitude: 14.72,
        longitude: -17.49,
      );

      expect(currentPosition.zoneName, isNull);
      expect(currentPosition.hasGeographicLabel, isFalse);
      expect(coordinates.zoneName, isNull);
      expect(coordinates.hasGeographicLabel, isFalse);
    });

    test('copyWith remplace uniquement les champs fournis', () {
      const place = PlaceDetails(
        placeId: 'ChIJ',
        name: 'Grand Dakar',
        city: 'Dakar',
        latitude: 1,
        longitude: 2,
      );
      final renamed = place.copyWith(name: 'Grand Dakar (quartier)');
      expect(renamed.name, 'Grand Dakar (quartier)');
      expect(renamed.placeId, 'ChIJ');
      expect(renamed.city, 'Dakar');
      expect(renamed.latitude, 1);
    });
  });
}
