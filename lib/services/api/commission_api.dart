import 'client.dart';

class CommissionApi {
  final ApiClient client;
  CommissionApi(this.client);

  Future<Map<String, dynamic>> estimate(double amount) async {
    try {
      final res = await client.dio.post('/commissions/estimate', data: {'amount': amount});
      final rd = client.handle(res);
      final result = rd['commission'] ?? rd;
      if (result is Map<String, dynamic> && result.containsKey('commission')) {
        return Map<String, dynamic>.from(result);
      }
      final c = _default(amount);
      return {
        'amount': amount,
        'commission': c['commission'],
        'netAmount': c['netAmount'],
        'percentage': c['percentage'],
        'minAmount': 100,
        'maxAmount': 500,
        'profile': 'local',
      };
    } catch (e) {
      final c = _default(amount);
      return {
        'amount': amount,
        'commission': c['commission'],
        'netAmount': c['netAmount'],
        'percentage': c['percentage'],
        'minAmount': 100,
        'maxAmount': 500,
        'profile': 'local',
      };
    }
  }

  Future<Map<String, dynamic>> estimateForParcel(String parcelId) async {
    try {
      final res = await client.dio.get('/driver/parcels/$parcelId/commission');
      final rd = client.handle(res);
      return Map<String, dynamic>.from(rd['commission'] ?? rd);
    } catch (e) {
      return {'commission': 0, 'netAmount': 0, 'percentage': 5};
    }
  }

  Future<Map<String, dynamic>> payCashCommission(String parcelId, String source, {double? amount}) async {
    try {
      final data = <String, dynamic>{
        'source': source,
        if (amount != null) 'amount': amount,
      };
      final res = await client.dio.post('/driver/parcels/$parcelId/pay-commission', data: data);
      final rd = client.handle(res);
      return Map<String, dynamic>.from(rd['result'] ?? rd);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Map<String, dynamic> _default(double amount) {
    final commission = (amount * 0.05).clamp(100.0, 500.0);
    return {
      'commission': commission,
      'netAmount': amount - commission,
      'percentage': 5,
    };
  }
}
