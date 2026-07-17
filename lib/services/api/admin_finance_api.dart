import 'client.dart';

class AdminFinanceApi {
  final ApiClient client;
  AdminFinanceApi(this.client);

  Future<Map<String, dynamic>> dashboard() async {
    try {
      final res = await client.dio.get('/super-admin/finance/dashboard');
      final data = client.handle(res);
      return data['dashboard'] ?? data['data'] ?? data;
    } catch (e) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> wallets({Map<String, dynamic>? params}) async {
    try {
      final res = await client.dio.get('/super-admin/wallets', queryParameters: params);
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['wallets'] ?? data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> walletDetail(String userId) async {
    try {
      final res = await client.dio.get('/super-admin/wallets/$userId');
      final data = client.handle(res);
      return data['wallet'] ?? data['data'] ?? data;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> walletTransactions(String userId,
      {Map<String, dynamic>? params}) async {
    try {
      final res = await client.dio.get('/super-admin/wallets/$userId/transactions',
          queryParameters: params);
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['transactions'] ?? data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> rechargeWallet(String userId, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/super-admin/wallets/$userId/recharge', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> debitWallet(String userId, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/super-admin/wallets/$userId/debit', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> commissionConfig() async {
    try {
      final res = await client.dio.get('/super-admin/commissions/config');
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['configs'] ?? data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> updateCommissionConfig(Map<String, dynamic> d) async {
    try {
      final res = await client.dio.put('/super-admin/commissions/config', data: d);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> payments({Map<String, dynamic>? params}) async {
    try {
      final res = await client.dio.get('/super-admin/payments', queryParameters: params);
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['payments'] ?? data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getPayment(String paymentId) async {
    try {
      final res = await client.dio.get('/super-admin/payments/$paymentId');
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> simulateCommission(double amount) async {
    try {
      final res = await client.dio.get('/super-admin/commissions/simulate',
          queryParameters: {'amount': amount});
      final data = client.handle(res);
      return List<Map<String, dynamic>>.from(data['simulation'] ?? data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }
}
