import 'client.dart';

class CommissionApi {
  final ApiClient client;
  CommissionApi(this.client);

  Future<Map<String, dynamic>> estimate(double amount) async {
    try {
      final res = await client.dio
          .post('/commissions/estimate', data: {'amount': amount});
      final rd = client.handle(res);
      final result = rd['commission'] ?? rd;
      if (result is Map<String, dynamic> && result.containsKey('commission')) {
        return Map<String, dynamic>.from(result);
      }
      throw const FormatException('Réponse de commission invalide');
    } catch (_) {
      // Une estimation financière ne doit jamais être remplacée par un calcul
      // local silencieux. Le backend est l'unique autorité sur les barèmes.
      rethrow;
    }
  }

  Future<Map<String, dynamic>> estimateForParcel(String parcelId) async {
    try {
      final res = await client.dio.get('/driver/parcels/$parcelId/commission');
      final rd = client.handle(res);
      return Map<String, dynamic>.from(rd['commission'] ?? rd);
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> payCashCommission(String parcelId, String source,
      {double? amount}) async {
    try {
      final data = <String, dynamic>{
        'source': source,
        if (amount != null) 'amount': amount,
      };
      final res = await client.dio
          .post('/driver/parcels/$parcelId/pay-commission', data: data);
      final rd = client.handle(res);
      return Map<String, dynamic>.from(rd['result'] ?? rd);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
