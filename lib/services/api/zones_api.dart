import '../../models/zone.dart';
import 'client.dart';

class ZonesApi {
  final ApiClient client;
  ZonesApi(this.client);

  /// Détecte les zones couvrant une position GPS.
  /// Aligné sur la webapp : GET /zones/detect?latitude=..&longitude=..
  Future<List<Zone>> detectZones(double latitude, double longitude) async {
    try {
      final res = await client.dio.get('/zones/detect', queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
      });
      final data = client.handle(res);
      final list = (data['data'] as List?) ?? (data['zones'] as List?) ?? [];
      return list
          .map((z) => Zone.fromJson(Map<String, dynamic>.from(z)))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
