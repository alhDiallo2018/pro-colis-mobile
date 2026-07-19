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
        balance: client.toDouble(walletData['balance'] ?? walletData['availableBalance']),
        totalDeposited: client.toDouble(walletData['totalDeposited']),
        totalConsumed: client.toDouble(walletData['totalSpent'] ?? walletData['totalCommissionsPaid']),
        totalRefunded: client.toDouble(walletData['totalRefunded'] ?? 0),
        pendingBalance: client.toDouble(walletData['pendingBalance']),
        totalWithdrawn: client.toDouble(walletData['totalWithdrawn']),
        totalCommissionsPaid: client.toDouble(walletData['totalCommissionsPaid']),
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
      final method = d['method']?.toString() ?? 'paydunya';
      if (method == 'paydunya') {
        final res = await client.dio.post('/payments/paydunya/create', data: {
          'type': 'wallet',
          'amount': d['amount'],
          if (d['phone'] != null) 'phone': d['phone'],
        });
        return client.handle(res);
      }
      final res = await client.dio.post('/driver/wallet/recharge', data: {
        'amount': d['amount'],
        'method': method,
        if (d['phone'] != null) 'phone': d['phone'],
      });
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> withdrawWallet(Map<String, dynamic> data) async {
    try {
      final res = await client.dio.post('/driver/wallet/withdraw', data: {
        ...data,
        'idempotencyKey': '${data['amount']}_${DateTime.now().millisecondsSinceEpoch}',
      });
      return client.handle(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getMyWithdrawals() async {
    try {
      final res = await client.dio.get('/driver/wallet/withdrawals');
      final data = client.handle(res);
      final list = (data['withdrawals'] as List?) ?? [];
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> cancelWithdrawal(String id) async {
    try {
      final res = await client.dio.delete('/driver/wallet/withdrawals/$id');
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
