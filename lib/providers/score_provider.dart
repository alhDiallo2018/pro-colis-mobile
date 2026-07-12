// lib/providers/score_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/score.dart';
import '../services/api_service.dart';

final scoreProvider = StateNotifierProvider<ScoreNotifier, ScoreState>((ref) {
  return ScoreNotifier();
});

class ScoreState {
  final bool isLoading;
  final double balance;
  final List<Map<String, dynamic>> history;
  final String? error;
  final Score? score;
  final bool hasAttemptedLoad;

  ScoreState({
    required this.isLoading,
    this.balance = 0,
    this.history = const [],
    this.error,
    this.score,
    this.hasAttemptedLoad = false,
  });

  factory ScoreState.initial() => ScoreState(isLoading: false);

  ScoreState copyWith({
    bool? isLoading,
    double? balance,
    List<Map<String, dynamic>>? history,
    String? error,
    Score? score,
    bool? hasAttemptedLoad,
  }) {
    return ScoreState(
      isLoading: isLoading ?? this.isLoading,
      balance: balance ?? this.balance,
      history: history ?? this.history,
      error: error ?? this.error,
      score: score ?? this.score,
      hasAttemptedLoad: hasAttemptedLoad ?? this.hasAttemptedLoad,
    );
  }
}

class ScoreNotifier extends StateNotifier<ScoreState> {
  ScoreNotifier() : super(ScoreState.initial());

  final ApiService _apiService = ApiService();

  Future<void> loadScore(String userId) async {
    state = state.copyWith(isLoading: true, hasAttemptedLoad: true);
    try {
      final balance = await _apiService.getScoreBalance();
      final history = await _apiService.getScoreHistory();
      final transactions = history
          .map((t) => ScoreTransaction(
                id: t['id']?.toString() ?? '',
                userId: userId,
                amount: int.tryParse(t['amount']?.toString() ?? '') ?? 0,
                type: t['type']?.toString() ?? '',
                parcelId: t['parcelId']?.toString(),
                timestamp: t['createdAt'] != null
                    ? DateTime.tryParse(t['createdAt'].toString()) ??
                        DateTime.now()
                    : DateTime.now(),
                description: t['description']?.toString() ?? '',
                status: t['status']?.toString() ?? 'completed',
              ))
          .toList();

      final score = Score(
        userId: userId,
        points: balance.toInt(),
        transactions: transactions,
      );

      state = state.copyWith(
        balance: balance,
        score: score,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadBalance() async {
    state = state.copyWith(isLoading: true, hasAttemptedLoad: true);
    try {
      final balance = await _apiService.getScoreBalance();
      state = state.copyWith(
        balance: balance,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true);
    try {
      final history = await _apiService.getScoreHistory();
      state = state.copyWith(history: history, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<bool> purchasePoints(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _apiService.purchasePoints(data);
      if (result['success'] == true || result['payment'] != null) {
        await loadBalance();
        state = state.copyWith(isLoading: false, error: null);
        return true;
      }
      state = state.copyWith(
        error: result['message'] ?? 'Erreur achat',
        isLoading: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }
}
