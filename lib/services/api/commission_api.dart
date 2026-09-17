import 'client.dart';
import '../commission_service.dart';

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
      return _fallback(amount);
    } catch (e) {
      return _fallback(amount);
    }
  }

  Future<Map<String, dynamic>> estimateForParcel(String parcelId) async {
    try {
      final res = await client.dio.get('/driver/parcels/$parcelId/commission');
      final rd = client.handle(res);
      return Map<String, dynamic>.from(rd['commission'] ?? rd);
    } catch (e) {
      return {'commission': 0, 'netAmount': 0, 'percentage': 0};
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

  /// Repli cohérent avec la configuration chargée (`CommissionService`). La
  /// commission n'est jamais recalculée avec un pourcentage codé en dur : si
  /// l'API n'a pas répondu, on repart de la dernière configuration connue.
  Map<String, dynamic> _fallback(double amount) {
    final commission = CommissionService.calculate(amount);
    return {
      'amount': amount,
      'commission': commission,
      'netAmount': amount - commission,
      'percentage': CommissionService.percentage,
      'minAmount': CommissionService.minimum,
      'maxAmount': CommissionService.maximum,
      'profile': 'local',
    };
  }
}
