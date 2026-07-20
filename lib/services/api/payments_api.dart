import 'client.dart';

class PaymentsApi {
  final ApiClient client;
  PaymentsApi(this.client);

  /// Historique des paiements de l'utilisateur courant.
  /// Aligné sur la webapp : GET /payments/history → { payments } ou { data }.
  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final res = await client.dio.get('/payments/history');
      final data = client.handle(res);
      final list = (data['payments'] as List?) ?? (data['data'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
