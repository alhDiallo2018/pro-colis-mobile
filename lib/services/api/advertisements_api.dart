import 'client.dart';

class AdvertisementsApi {
  final ApiClient client;
  AdvertisementsApi(this.client);

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    try {
      final res = await client.dio.post('/advertisements', data: data);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getAdvertisements({Map<String, dynamic>? params}) async {
    try {
      final res = await client.dio.get('/advertisements', queryParameters: params);
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['advertisements'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getDetail(String adId) async {
    final res = await client.dio.get('/advertisements/$adId');
    final data = client.handle(res);
    return data['advertisement'] ?? data;
  }

  Future<List<Map<String, dynamic>>> getMyAdvertisements() async {
    try {
      final res = await client.dio.get('/advertisements/my');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['advertisements'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> close(String adId) async {
    try {
      final res = await client.dio.post('/advertisements/$adId/close');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createOffer(String adId, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/advertisements/$adId/offers', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> acceptOffer(String adId, String offerId) async {
    try {
      final res = await client.dio.post('/advertisements/$adId/offers/$offerId/accept');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> rejectOffer(String adId, String offerId) async {
    try {
      final res = await client.dio.post('/advertisements/$adId/offers/$offerId/reject');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> negotiateOffer(String adId, String offerId, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/advertisements/$adId/offers/$offerId/negotiate', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
