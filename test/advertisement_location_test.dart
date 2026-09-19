import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/advertisement.dart';
import 'package:procolis/services/api_service.dart';

void main() {
  test('la résolution conserve la zone et non le garage miroir', () {
    final zone = ApiService.parseResolvedPlaceZone({
      'success': true,
      'data': {'id': 'zone-uuid', 'name': 'Ouakam', 'city': ''},
      'garage': {'id': 'garage-uuid', 'name': 'Garage miroir'},
      'garageId': 'garage-uuid',
    });
    expect(zone?.id, 'zone-uuid');
    expect(zone?.locationLabel, 'Ouakam');
    expect(
        ApiService.parseResolvedPlaceZone({
          'success': true,
          'garage': {'id': 'wrong-reference'},
        }),
        isNull);
  });

  test('les noms des zones restent visibles quand les villes sont vides', () {
    final ad = Advertisement.fromJson({
      'departureCity': ' ',
      'departureZoneName': 'Ouakam',
      'arrivalCity': '',
      'arrivalName': 'Thiès Nord',
    });
    expect(ad.departureCity, 'Ouakam');
    expect(ad.arrivalCity, 'Thiès Nord');
    expect(ad.route, 'Ouakam  →  Thiès Nord');
  });

  test('les anciennes annonces conservent leur ville', () {
    expect(Advertisement.fromJson({'departureCity': ' Dakar '}).departureCity,
        'Dakar');
    expect(
        Advertisement.fromJson({'departureCity': ' '}).departureCity, isNull);
  });
}
