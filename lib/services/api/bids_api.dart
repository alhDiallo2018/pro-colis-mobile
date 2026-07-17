import 'client.dart';

class BidsApi {
  final ApiClient client;
  BidsApi(this.client);

  Future<Map<String, dynamic>> createBid(Map<String, dynamic> data) async {
    try {
      final res = await client.dio.post('/driver/bids', data: data);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getClientReceivedBids() async {
    try {
      final res = await client.dio.get('/client/bids/received');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['bids'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getParcelBids(String parcelId) async {
    try {
      final res = await client.dio.get('/public/parcels/$parcelId/bids');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['bids'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> acceptBid(String parcelId, String bidId) async {
    try {
      final res = await client.dio.post('/client/parcels/$parcelId/bids/$bidId/accept');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> rejectBid(String parcelId, String bidId, {String? responseMessage}) async {
    try {
      final res = await client.dio.post('/client/parcels/$parcelId/bids/$bidId/reject',
          data: responseMessage != null ? {'responseMessage': responseMessage} : null);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> negotiateBid(String bidId, Map<String, dynamic> data) async {
    try {
      final res = await client.dio.post('/client/bids/$bidId/negotiate', data: data);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
