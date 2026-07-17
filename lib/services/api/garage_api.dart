import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/user.dart';
import 'client.dart';

class GarageApi {
  final ApiClient client;
  GarageApi(this.client);

  Future<List<Parcel>> getGarageParcels({String? status}) async {
    try {
      final res = await client.dio.get('/garage-admin/parcels');
      final data = client.handle(res);
      final list = (data['parcels'] as List?) ?? [];
      return list.map((j) => Parcel.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<User>> getGarageDrivers() async {
    try {
      final res = await client.dio.get('/garage-admin/drivers');
      final data = client.handle(res);
      final list = (data['drivers'] as List?) ?? [];
      return list.map((j) => User.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> assignDriverToParcel(String parcelId, String driverId) async {
    try {
      final res = await client.dio.put('/garage-admin/parcels/$parcelId/assign-driver',
          data: {'driverId': driverId});
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteParcelAdmin(String parcelId) async {
    try {
      final res = await client.dio.delete('/garage-admin/parcels/$parcelId');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
