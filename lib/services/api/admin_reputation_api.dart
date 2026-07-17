import 'client.dart';

class AdminReputationApi {
  final ApiClient client;
  AdminReputationApi(this.client);

  Future<Map<String, dynamic>> dashboard() async {
    try {
      final res = await client.dio.get('/super-admin/reputation/dashboard');
      return client.handle(res);
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> scores({Map<String, dynamic>? params}) async {
    try {
      final res = await client.dio.get('/super-admin/scores', queryParameters: params);
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['scores'] ?? data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> scoreDetail(String userId) async {
    try {
      final res = await client.dio.get('/super-admin/scores/$userId');
      final data = client.handle(res);
      return data['score'] ?? data['data'] ?? data;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> scoreHistory(String userId,
      {Map<String, dynamic>? params}) async {
    try {
      final res = await client.dio.get('/super-admin/scores/$userId/history',
          queryParameters: params);
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['transactions'] ?? data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> addPoints(String userId, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/super-admin/scores/$userId/add', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removePoints(String userId, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/super-admin/scores/$userId/remove', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> ranking() async {
    try {
      final res = await client.dio.get('/super-admin/scores/ranking');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['rankings'] ?? data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> driverDetail(String userId) async {
    try {
      final res = await client.dio.get('/super-admin/drivers/$userId');
      final data = client.handle(res);
      return data['driver'] ?? data['data'] ?? data;
    } catch (e) {
      return null;
    }
  }
}
