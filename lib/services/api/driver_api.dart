import '../../models/parcel.dart';
import '../../models/user.dart';
import 'client.dart';

class DriverApi {
  final ApiClient client;
  DriverApi(this.client);

  Future<List<Parcel>> getDriverParcels() async {
    try {
      final res = await client.dio.get('/driver/parcels');
      final data = client.handle(res);
      final list = (data['parcels'] as List?) ?? [];
      return list.map((j) => Parcel.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDriverBidsSent() async {
    try {
      final res = await client.dio.get('/driver/bids/sent');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['bids'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> advanceParcel(String parcelId, String step,
      {String? location, String? otp}) async {
    try {
      final body = <String, dynamic>{};
      if (location != null) body['location'] = location;
      if (otp != null) body['otp'] = otp;
      final res = await client.dio.put(
        '/driver/parcels/$parcelId/$step',
        data: body.isEmpty ? null : body,
      );
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> driverDeliver(String parcelId, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.put('/driver/parcels/$parcelId/deliver', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<User>> getGarageColleagues(String garageId) async {
    try {
      final res = await client.dio.get('/public/drivers/garage/$garageId');
      final data = client.handle(res);
      final list = (data['drivers'] as List?) ?? [];
      return list.map((j) => User.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> updateDriverStatus(String status) async {
    try {
      final res = await client.dio.put('/driver/profile', data: {'driverStatus': status});
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
