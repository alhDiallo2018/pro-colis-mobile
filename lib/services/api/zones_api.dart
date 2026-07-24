import '../../models/zone.dart';
import '../../models/garage.dart';
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

  /// Résout un lieu Google Places en zone (la crée en "pending" si nécessaire).
  /// POST /zones/resolve — renvoie la zone résolue/créée (ou null en cas d'échec).
  Future<Zone?> resolveZone({
    String? placeId,
    required String name,
    String? displayName,
    required double latitude,
    required double longitude,
    String? country,
    String? region,
    String? city,
  }) async {
    try {
      final res = await client.dio.post('/zones/resolve', data: {
        if (placeId != null) 'placeId': placeId,
        'name': name,
        if (displayName != null) 'displayName': displayName,
        'latitude': latitude,
        'longitude': longitude,
        if (country != null) 'country': country,
        if (region != null) 'region': region,
        if (city != null) 'city': city,
      });
      final data = client.handle(res);
      final z = data['data'];
      return z is Map ? Zone.fromJson(Map<String, dynamic>.from(z)) : null;
    } catch (e) {
      return null;
    }
  }

  /// Idem resolveZone mais renvoie un Garage (type attendu par le RoutePicker),
  /// pour injecter directement la zone résolue dans la liste sélectionnable.
  Future<Garage?> resolvePlaceAsGarage({
    String? placeId,
    required String name,
    required double latitude,
    required double longitude,
    String? country,
    String? region,
    String? city,
  }) async {
    try {
      final res = await client.dio.post('/zones/resolve', data: {
        if (placeId != null) 'placeId': placeId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        if (country != null) 'country': country,
        if (region != null) 'region': region,
        if (city != null) 'city': city,
      });
      final data = client.handle(res);
      final z = data['data'];
      return z is Map ? Garage.fromJson(Map<String, dynamic>.from(z)) : null;
    } catch (e) {
      return null;
    }
  }
}
