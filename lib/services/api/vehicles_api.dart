import 'client.dart';

class VehiclesApi {
  final ApiClient client;
  VehiclesApi(this.client);

  Future<Map<String, dynamic>?> getVehicle() async {
    try {
      final res = await client.dio.get('/driver/vehicle');
      final data = client.handle(res);
      return data['vehicle'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> upsertVehicle(Map<String, dynamic> d) async {
    try {
      final res = await client.dio.put('/driver/vehicle', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
