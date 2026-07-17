import 'client.dart';

class PaydunyaApi {
  final ApiClient client;
  PaydunyaApi(this.client);

  Future<Map<String, dynamic>> createPayment(String type,
      {String? parcelId, int? points, double? amount}) async {
    try {
      final data = <String, dynamic>{'type': type};
      if (parcelId != null) data['parcelId'] = parcelId;
      if (points != null) data['points'] = points;
      if (amount != null) data['amount'] = amount;
      final res = await client.dio.post('/payments/paydunya/create', data: data);
      final rd = client.handle(res);
      return rd['data'] ?? rd;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> confirmPayment(String token) async {
    try {
      final res = await client.dio.get('/payments/paydunya/confirm/$token');
      final rd = client.handle(res);
      return rd['data'] ?? rd;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
