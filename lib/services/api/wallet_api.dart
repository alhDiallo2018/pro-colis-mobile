import '../../models/wallet.dart';
import 'client.dart';

class WalletApi {
  final ApiClient client;
  WalletApi(this.client);

  Future<Wallet> getWallet(String userId) async {
    try {
      final res = await client.dio.get('/driver/wallet');
      final data = client.handle(res);
      final walletData = (data['wallet'] as Map<String, dynamic>?) ?? data;
      final txList = data['transactions'] as List?;
      final transactions = txList
          ?.map((t) => WalletTransaction.fromJson(Map<String, dynamic>.from(t)))
          .toList() ?? [];
      return Wallet(
        id: walletData['id']?.toString() ?? 'wallet-$userId',
        userId: walletData['userId']?.toString() ?? userId,
        balance: client.toDouble(walletData['balance']),
        totalDeposited: client.toDouble(walletData['totalDeposited']),
        totalConsumed: client.toDouble(walletData['totalSpent']),
        isActive: walletData['status'] == 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        transactions: transactions,
      );
    } catch (e) {
      return Wallet(id: 'wallet-$userId', userId: userId, balance: 0, createdAt: DateTime.now(), updatedAt: DateTime.now());
    }
  }

  Future<double> getWalletBalance(String userId) async {
    final wallet = await getWallet(userId);
    return wallet.balance;
  }

  Future<Map<String, dynamic>> depositWallet(String userId, Map<String, dynamic> d) async {
    try {
      final res = await client.dio.post('/score/purchase', data: {
        'points': d['amount'],
        'method': d['method'] ?? 'cash',
        if (d['phone'] != null) 'phoneNumber': d['phone'],
      });
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> withdrawWallet(Map<String, dynamic> data) async {
    try {
      final res = await client.dio.post('/driver/wallet/withdraw', data: data);
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> consumeCommission({
    required String parcelId,
    required double deliveryAmount,
  }) async {
    try {
      final res = await client.dio.post('/driver/wallet/consume', data: {
        'parcelId': parcelId,
        'deliveryAmount': deliveryAmount,
      });
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
