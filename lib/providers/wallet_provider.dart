import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet.dart';
import '../services/api_service.dart';

class WalletState {
  final bool isLoading;
  final String? error;
  final Wallet? wallet;
  final double balance; // Solde en FCFA
  final List<WalletTransaction> transactions;

  const WalletState({
    this.isLoading = false,
    this.error,
    this.wallet,
    this.balance = 0,
    this.transactions = const [],
  });

  WalletState copyWith({
    bool? isLoading,
    String? error,
    Wallet? wallet,
    double? balance,
    List<WalletTransaction>? transactions,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      wallet: wallet ?? this.wallet,
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
    );
  }

  bool get hasBalance => balance > 0;
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState());

  final ApiService _apiService = ApiService();

  Future<void> loadWallet(String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      final wallet = await _apiService.getWallet(userId);
      state = state.copyWith(
        wallet: wallet,
        balance: wallet.balance,
        transactions: wallet.transactions,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadBalance(String userId) async {
    try {
      final balance = await _apiService.getWalletBalance(userId);
      state = state.copyWith(balance: balance, error: null);
    } catch (e) {
      // Erreur silencieuse pour les refresh
    }
  }

  Future<bool> deposit(String userId, Map<String, dynamic> data) async {
    try {
      final result = await _apiService.depositWallet(userId, data);
      if (result['success'] == true) {
        await loadBalance(userId);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> acceptDelivery({
    required String driverId,
    required String parcelId,
    required double deliveryAmount,
  }) async {
    try {
      final result = await _apiService.consumeDeliveryCommission(
        driverId: driverId,
        parcelId: parcelId,
        deliveryAmount: deliveryAmount,
      );
      if (result['success'] == true) {
        state = state.copyWith(
          balance: double.tryParse(result['newBalance']?.toString() ?? '') ?? state.balance,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
