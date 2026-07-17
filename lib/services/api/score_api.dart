import 'client.dart';

class ScoreApi {
  final ApiClient client;
  ScoreApi(this.client);

  Future<double> getBalance() async {
    try {
      final res = await client.dio.get('/score/balance');
      final data = client.handle(res);
      return client.toDouble(data['balance']);
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final res = await client.dio.get('/score/history');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['transactions'] ?? data['history'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> purchasePoints(Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/score/purchase', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> purchaseWithWallet(int points) async {
    try {
      final res = await client.dio.post('/score/purchase/wallet', data: {'points': points});
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
