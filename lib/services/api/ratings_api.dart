import 'client.dart';

class RatingsApi {
  final ApiClient client;
  RatingsApi(this.client);

  Future<Map<String, dynamic>> rateDriver({
    required String driverId,
    required int rating,
    String? parcelId,
    String? comment,
  }) async {
    try {
      final res = await client.dio.post('/ratings', data: {
        'driverId': driverId,
        'rating': rating,
        if (parcelId != null) 'parcelId': parcelId,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getDriverRatings(String driverId) async {
    try {
      final res = await client.dio.get('/ratings/driver/$driverId');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['ratings'] ?? []);
    } catch (e) {
      return [];
    }
  }
}
