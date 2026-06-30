// lib/providers/score_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/score.dart';
import '../services/api_service.dart';

// Provider pour accéder au service API
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});

// Provider pour accéder au score
final scoreProvider = StateNotifierProvider<ScoreNotifier, ScoreState>((ref) {
  return ScoreNotifier(ref);
});

class ScoreState {
  final Score? score;
  final bool isLoading;
  final String? error;
  final bool hasAttemptedLoad;

  const ScoreState({
    this.score,
    this.isLoading = false,
    this.error,
    this.hasAttemptedLoad = false,
  });

  ScoreState copyWith({
    Score? score,
    bool? isLoading,
    String? error,
    bool? hasAttemptedLoad,
    bool clearError = false,
  }) {
    return ScoreState(
      score: score ?? this.score,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasAttemptedLoad: hasAttemptedLoad ?? this.hasAttemptedLoad,
    );
  }
}

class ScoreNotifier extends StateNotifier<ScoreState> {
  final Ref _ref;

  ScoreNotifier(this._ref) : super(const ScoreState());

  /// Récupérer le score de l'utilisateur depuis le backend
  Future<void> loadScore(String userId) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      hasAttemptedLoad: true,
      clearError: true,
    );
    try {
      final apiService = _ref.read(apiServiceProvider);
      
      // Appel API pour récupérer le score
      final response = await apiService.getUserScore();
      
      print('📊 Response loadScore: $response');
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        
        if (data == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'Données du score non trouvées',
          );
          return;
        }

        // ✅ Récupérer le score
        final scoreData = data['score'] as Map<String, dynamic>?;
        
        if (scoreData == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'Score non trouvé',
          );
          return;
        }

        // ✅ Récupérer les transactions depuis data['transactions'] (extérieur)
        final transactionsData = data['transactions'] as List? ?? [];
        
        // ✅ Ajouter les transactions au scoreData
        scoreData['transactions'] = transactionsData;

        print('📊 scoreData avec transactions: ${scoreData['transactions']}');
        
        final score = Score.fromJson(scoreData);
        state = state.copyWith(score: score, isLoading: false, clearError: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response['message'] ?? 'Erreur lors du chargement du score',
        );
      }
    } catch (e) {
      print('❌ Erreur loadScore: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Débiter des points (client crée un colis ou chauffeur livre)
  Future<bool> debitPoints(
    String userId,
    int amount,
    String parcelId,
    String description,
  ) async {
    try {
      final currentScore = state.score;
      if (currentScore == null || currentScore.points < amount) {
        state = state.copyWith(
          error: 'Points insuffisants. Veuillez acheter des points.',
        );
        return false;
      }

      final apiService = _ref.read(apiServiceProvider);
      
      // Appel API pour débiter les points
      final response = await apiService.debitPoints(
        userId: userId,
        amount: amount,
        type: 'parcel_creation',
        parcelId: parcelId,
        description: description,
      );

      if (response['success'] == true) {
        // Mettre à jour le score localement
        final transaction = ScoreTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: userId,
          amount: -amount,
          type: 'parcel_creation',
          parcelId: parcelId,
          description: description,
        );

        final updatedScore = currentScore.copyWith(
          points: response['newBalance'] ?? (currentScore.points - amount),
          transactions: [...currentScore.transactions, transaction],
          lastUpdated: DateTime.now(),
        );

        state = state.copyWith(score: updatedScore);
        return true;
      } else {
        state = state.copyWith(
          error: response['message'] ?? 'Erreur lors du débit des points',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Créditer des points (achat)
  Future<bool> creditPoints(
    String userId,
    int amount,
    String description,
  ) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      
      // Appel API pour créditer les points
      final response = await apiService.creditPoints(
        userId: userId,
        amount: amount,
        type: 'purchase',
        description: description,
      );

      if (response['success'] == true) {
        final currentScore = state.score ?? Score(userId: userId);
        
        final transaction = ScoreTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: userId,
          amount: amount,
          type: 'purchase',
          description: description,
        );

        final updatedScore = currentScore.copyWith(
          points: response['newBalance'] ?? (currentScore.points + amount),
          transactions: [...currentScore.transactions, transaction],
          lastUpdated: DateTime.now(),
        );

        state = state.copyWith(score: updatedScore);
        return true;
      } else {
        state = state.copyWith(
          error: response['message'] ?? 'Erreur lors du crédit des points',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Vérifier si l'utilisateur a assez de points
  bool hasEnoughPoints(int requiredPoints) {
    final score = state.score;
    if (score == null) return false;
    return score.points >= requiredPoints;
  }

  /// Obtenir le solde actuel
  int get currentPoints => state.score?.points ?? 0;

  /// Recharger le score depuis le backend
  Future<void> refreshScore() async {
    final userId = state.score?.userId;
    if (userId != null) {
      await loadScore(userId);
    }
  }
}
