// mobile/lib/providers/advertisement_provider.dart
//
// CRUD des annonces de trajet du chauffeur, offres reçues comprises.
//
// Les écrans appelaient ApiService directement et réimplémentaient chacun leur
// rechargement après mutation. Centraliser ici évite qu'une action oublie de
// rafraîchir la liste, et donne un seul endroit où lire le message de refus
// renvoyé par l'API (annonce déjà engagée, offre déjà acceptée...).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

final advertisementProvider =
    StateNotifierProvider<AdvertisementNotifier, AdvertisementState>((ref) {
  return AdvertisementNotifier();
});

class AdvertisementNotifier extends StateNotifier<AdvertisementState> {
  AdvertisementNotifier() : super(AdvertisementState.initial());

  final ApiService _apiService = ApiService();

  /// Chargement en cours, partagé par tous les appelants simultanés. Sans lui,
  /// l'ouverture de l'écran pendant qu'une mutation recharge déjà la liste
  /// lançait deux requêtes concurrentes dont la plus lente écrasait le résultat
  /// de l'autre.
  Future<void>? _inFlightLoad;

  Future<void> loadMyAdvertisements() {
    return _inFlightLoad ??=
        _loadMyAdvertisements().whenComplete(() => _inFlightLoad = null);
  }

  Future<void> _loadMyAdvertisements() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Le délai maximal double celui de Dio : si la requête n'est jamais
      // envoyée (jeton illisible, adaptateur bloqué), le spinner doit quand
      // même rendre la main plutôt que tourner indéfiniment.
      final ads = await _apiService
          .getMyAdvertisements()
          .timeout(const Duration(seconds: 45));
      state = state.copyWith(myAds: ads, isLoading: false, error: null);
    } on TimeoutException {
      debugPrint('❌ Chargement des annonces : délai dépassé');
      state = state.copyWith(
        error: 'Le chargement de vos voyages a expiré. Réessayez.',
        isLoading: false,
      );
    } catch (e) {
      debugPrint('❌ Chargement des annonces: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Exécute une mutation puis recharge la liste si elle a réussi. L'API répond
  /// `{success, message}` même sur un refus métier (4xx) : le message est
  /// remonté tel quel à l'écran plutôt que traduit ici.
  Future<Map<String, dynamic>> _mutate(
    Future<Map<String, dynamic>> Function() action, {
    required String fallbackError,
  }) async {
    state = state.copyWith(isMutating: true);
    try {
      final result = await action();
      final succeeded = result['success'] == true;
      if (succeeded) {
        await loadMyAdvertisements();
        state = state.copyWith(isMutating: false, error: null);
        return result;
      }
      final message = result['message']?.toString() ?? fallbackError;
      state = state.copyWith(isMutating: false, error: message);
      return {...result, 'success': false, 'message': message};
    } catch (e) {
      state = state.copyWith(isMutating: false, error: e.toString());
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> createAdvertisement(
    Map<String, dynamic> data,
  ) =>
      _mutate(
        () => _apiService.createAdvertisement(data),
        fallbackError: 'Impossible de publier l\'annonce',
      );

  Future<Map<String, dynamic>> updateAdvertisement(
    String advertisementId,
    Map<String, dynamic> data,
  ) =>
      _mutate(
        () => _apiService.updateAdvertisement(advertisementId, data),
        fallbackError: 'Impossible de modifier l\'annonce',
      );

  /// Suppression définitive. L'API la refuse dès qu'une offre a été acceptée :
  /// dans ce cas c'est [closeAdvertisement] qu'il faut utiliser.
  Future<Map<String, dynamic>> deleteAdvertisement(String advertisementId) =>
      _mutate(
        () => _apiService.deleteAdvertisement(advertisementId),
        fallbackError: 'Impossible de supprimer l\'annonce',
      );

  Future<Map<String, dynamic>> closeAdvertisement(
    String advertisementId, {
    String? reason,
  }) =>
      _mutate(
        () => _apiService.closeAdvertisement(advertisementId, reason: reason),
        fallbackError: 'Impossible de fermer l\'annonce',
      );

  Future<Map<String, dynamic>> acceptOffer(
    String advertisementId,
    String offerId,
  ) =>
      _mutate(
        () => _apiService.acceptAdvertisementOffer(advertisementId, offerId),
        fallbackError: 'Impossible d\'accepter cette offre',
      );

  Future<Map<String, dynamic>> rejectOffer(
    String advertisementId,
    String offerId,
  ) =>
      _mutate(
        () => _apiService.rejectAdvertisementOffer(advertisementId, offerId),
        fallbackError: 'Impossible de refuser cette offre',
      );

  Future<Map<String, dynamic>> negotiateOffer(
    String advertisementId,
    String offerId,
    Map<String, dynamic> data,
  ) =>
      _mutate(
        () => _apiService.negotiateAdvertisementOffer(
          advertisementId,
          offerId,
          data,
        ),
        fallbackError: 'Impossible d\'envoyer la contre-proposition',
      );

  /// Offres d'une annonce précise. La liste `myAds` les porte déjà en nested,
  /// cette lecture sert aux écrans qui n'affichent qu'une annonce.
  Future<List<Map<String, dynamic>>> loadOffers(String advertisementId) async {
    try {
      return await _apiService.getAdvertisementOffers(advertisementId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }

  void reset() => state = AdvertisementState.initial();
}

class AdvertisementState {
  final bool isLoading;

  /// Annonces brutes telles que renvoyées par l'API : les écrans exploitent les
  /// offres imbriquées et les identifiants de zone, que le modèle
  /// [Advertisement] ne porte pas.
  final List<Map<String, dynamic>> myAds;

  /// Vrai pendant une création / modification / suppression, pour désactiver les
  /// boutons sans masquer la liste déjà affichée.
  final bool isMutating;
  final String? error;

  const AdvertisementState({
    required this.isLoading,
    this.myAds = const [],
    this.isMutating = false,
    this.error,
  });

  factory AdvertisementState.initial() =>
      const AdvertisementState(isLoading: false);

  /// Contrairement à `ParcelState`, `error` n'est pas conservée quand elle n'est
  /// pas passée : chaque nouvelle tentative repart d'un état propre. C'est
  /// volontaire — un `error ?? this.error` rend l'erreur impossible à effacer
  /// autrement qu'en la remplaçant.
  AdvertisementState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? myAds,
    bool? isMutating,
    String? error,
  }) {
    return AdvertisementState(
      isLoading: isLoading ?? this.isLoading,
      myAds: myAds ?? this.myAds,
      isMutating: isMutating ?? this.isMutating,
      error: error,
    );
  }

  bool get hasAds => myAds.isNotEmpty;

  List<Map<String, dynamic>> get openAds =>
      myAds.where((ad) => ad['status'] == 'open').toList();

  List<Map<String, dynamic>> get closedAds =>
      myAds.where((ad) => ad['status'] != 'open').toList();
}
