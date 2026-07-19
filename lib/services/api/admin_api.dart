import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/user.dart';
import 'client.dart';

class AdminApi {
  final ApiClient client;
  AdminApi(this.client);

  Future<List<Parcel>> getAllParcelsSuperAdmin() async {
    try {
      final res = await client.dio.get('/super-admin/parcels');
      final data = client.handle(res);
      final list = (data['parcels'] as List?) ?? [];
      return list.map((j) => Parcel.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<User>> getAllUsersSuperAdmin() async {
    try {
      final res = await client.dio.get('/super-admin/users');
      final data = client.handle(res);
      final list = (data['users'] as List?) ?? [];
      return list.map((j) => User.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Garage>> getAllGaragesSuperAdmin() async {
    try {
      final res = await client.dio.get('/super-admin/garages');
      final data = client.handle(res);
      final list = (data['garages'] as List?) ?? (data['data'] as List?) ?? [];
      return list.map((j) => Garage.fromJson(Map<String, dynamic>.from(j))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> updateUserStatus(String userId, String status) async {
    try {
      final res = await client.dio.patch('/super-admin/users/$userId/status',
          data: {'status': status});
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final res = await client.dio.get('/super-admin/stats');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAdminConfig() async {
    try {
      final res = await client.dio.get('/super-admin/config');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateAdminConfig(Map<String, dynamic> cfg) async {
    try {
      final res = await client.dio.put('/super-admin/config', data: cfg);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createUserSuperAdmin(Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/super-admin/users', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserSuperAdmin(String userId, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.put('/super-admin/users/$userId', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteUserSuperAdmin(String userId) async {
    try {
      final res = await client.dio.delete('/super-admin/users/$userId');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> resetUserPinAdmin(String userId) async {
    try {
      final res = await client.dio.post('/super-admin/users/$userId/reset-pin');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createGarage(Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/super-admin/garages', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateGarage(String id, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.put('/super-admin/garages/$id', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteGarage(String id) async {
    try {
      final res = await client.dio.delete('/super-admin/garages/$id');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- Zones ---

  Future<List<Map<String, dynamic>>> getAllZones() async {
    try {
      final res = await client.dio.get('/super-admin/zones');
      final data = client.handle(res);
      return (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPublicZones() async {
    try {
      final res = await client.dio.get('/public/zones');
      final data = client.handle(res);
      return (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createZone(Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/super-admin/zones', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateZone(String id, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.put('/super-admin/zones/$id', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteZone(String id) async {
    try {
      final res = await client.dio.delete('/super-admin/zones/$id');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getZone(String id) async {
    try {
      final res = await client.dio.get('/super-admin/zones/$id');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> assignDriverToZone(
      String zoneId, String driverId, {bool isPrimary = false}) async {
    try {
      final res = await client.dio.post(
        '/super-admin/zones/$zoneId/drivers',
        data: {'driverId': driverId, 'isPrimary': isPrimary},
      );
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeDriverFromZone(
      String zoneId, String driverId) async {
    try {
      final res = await client.dio.delete(
        '/super-admin/zones/$zoneId/drivers',
        data: {'driverId': driverId},
      );
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> migrateGaragesToZones() async {
    try {
      final res = await client.dio.post('/super-admin/zones/migrate');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteParcel(String id) async {
    try {
      final res = await client.dio.delete('/super-admin/parcels/$id');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> confirmCashPayment(String parcelId) async {
    try {
      final res = await client.dio.post('/super-admin/parcels/$parcelId/confirm-cash');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
