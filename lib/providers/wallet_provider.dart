import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wallet.dart';
import '../services/api_service.dart';

class WalletState {
  final bool isLoading;
  final String? error;
  final Wallet? wallet;

  /// Solde en FCFA. `null` signifie « inconnu » (non chargé ou erreur) : il ne
  /// doit jamais être interprété comme un solde nul.
  final double? balance;
  final List<WalletTransaction> transactions;

  const WalletState({
    this.isLoading = false,
    this.error,
    this.wallet,
    this.balance,
    this.transactions = const [],
  });

  WalletState copyWith({
    bool? isLoading,
    String? error,
    Wallet? wallet,
    double? balance,
    List<WalletTransaction>? transactions,
    bool clearError = false,
  }) {
    return WalletState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error,
      wallet: wallet ?? this.wallet,
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
    );
  }

  bool get hasBalance => (balance ?? 0) > 0;
}

final walletProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(const WalletState());

  final ApiService _apiService = ApiService();

  Future<void> loadWallet(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
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
        error: e is ApiException ? e.message : 'Impossible de récupérer votre solde.',
      );
    }
  }

  Future<void> loadBalance(String userId) async {
    try {
      final balance = await _apiService.getWalletBalance(userId);
      state = state.copyWith(balance: balance, error: null);
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'Impossible de récupérer votre solde.',
      );
    }
  }
}
