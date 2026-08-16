// mobile/lib/providers/message_provider.dart
//
// Conversations et fils de discussion : lecture, envoi, modification et
// suppression logique.
//
// Les règles d'édition vivent côté API (auteur seul, fenêtre de 15 minutes,
// propositions de prix figées). [canEditMessage] les reproduit ici uniquement
// pour décider d'afficher ou non l'action : c'est l'API qui tranche.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/notification_badge_service.dart';

/// Doit rester aligné sur `MESSAGE_EDIT_WINDOW_MS` de l'API.
const Duration kMessageEditWindow = Duration(minutes: 15);

/// Préfixe des propositions de prix échangées dans le fil. L'API refuse de les
/// modifier ou de les supprimer, elles engagent une négociation.
const String kPriceProposalPrefix = '__PRIX__';

bool isPriceProposal(Map<String, dynamic> message) =>
    (message['body']?.toString() ?? '').startsWith(kPriceProposalPrefix);

/// Vrai si l'utilisateur peut encore modifier ce message. Sert à masquer
/// l'action ; un refus tardif de l'API reste possible si l'horloge du téléphone
/// diverge, et son message est alors affiché tel quel.
bool canEditMessage(Map<String, dynamic> message, String? currentUserId) {
  if (currentUserId == null) return false;
  if (message['senderId']?.toString() != currentUserId) return false;
  if (isPriceProposal(message)) return false;

  // Un message sans texte est un média seul : rien à réécrire.
  if ((message['body']?.toString() ?? '').trim().isEmpty) return false;

  final createdAt = DateTime.tryParse(message['createdAt']?.toString() ?? '');
  if (createdAt == null) return false;
  return DateTime.now().difference(createdAt) <= kMessageEditWindow;
}

/// La suppression n'a pas de fenêtre de temps : l'auteur peut retirer son
/// message à tout moment, sauf s'il s'agit d'une proposition de prix.
bool canDeleteMessage(Map<String, dynamic> message, String? currentUserId) {
  if (currentUserId == null) return false;
  if (message['senderId']?.toString() != currentUserId) return false;
  return !isPriceProposal(message);
}

final messageProvider =
    StateNotifierProvider<MessageNotifier, MessageState>((ref) {
  return MessageNotifier();
});

class MessageNotifier extends StateNotifier<MessageState> {
  MessageNotifier() : super(MessageState.initial());

  final ApiService _apiService = ApiService();

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true);
    try {
      final conversations = await _apiService.getConversations();
      state = state.copyWith(
        conversations: conversations,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      debugPrint('❌ Chargement des conversations: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Charge un fil et mémorise l'interlocuteur courant : les mutations qui
  /// suivent peuvent ainsi le recharger sans que l'écran repasse les paramètres.
  Future<void> loadThread(String peerId, {String? parcelId}) async {
    // Construction explicite plutôt que `copyWith` : `parcelId` valant `null`
    // est une information — un fil général doit pouvoir remplacer un fil
    // rattaché à un colis, ce qu'un `??` dans `copyWith` empêcherait.
    state = MessageState(
      isLoading: state.isLoading,
      isLoadingThread: true,
      isMutating: state.isMutating,
      conversations: state.conversations,
      thread: state.thread,
      activePeerId: peerId,
      activeParcelId: parcelId,
    );
    try {
      final messages =
          await _apiService.getMessagesThread(peerId, parcelId: parcelId);
      state = state.copyWith(
        thread: messages,
        isLoadingThread: false,
        error: null,
      );
      // Ouvrir un fil marque ses messages comme lus côté serveur : le badge de
      // l'icône doit descendre tout de suite, sans attendre le prochain
      // démarrage de l'application.
      unawaited(NotificationBadgeService.refresh());
    } catch (e) {
      debugPrint('❌ Chargement du fil: $e');
      state = state.copyWith(error: e.toString(), isLoadingThread: false);
    }
  }

  Future<void> _reloadActiveThread() async {
    final peerId = state.activePeerId;
    if (peerId == null) return;
    await loadThread(peerId, parcelId: state.activeParcelId);
  }

  Future<Map<String, dynamic>> _mutate(
    Future<Map<String, dynamic>> Function() action, {
    required String fallbackError,
  }) async {
    state = state.copyWith(isMutating: true);
    try {
      final result = await action();
      if (result['success'] == true) {
        await _reloadActiveThread();
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

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    String? body,
    String? parcelId,
    String? audioUrl,
    String? photoUrl,
    String? videoUrl,
  }) =>
      _mutate(
        () => _apiService.sendMessage({
          'receiverId': receiverId,
          if (body != null && body.isNotEmpty) 'body': body,
          if (parcelId != null) 'parcelId': parcelId,
          if (audioUrl != null) 'audioUrl': audioUrl,
          if (photoUrl != null) 'photoUrl': photoUrl,
          if (videoUrl != null) 'videoUrl': videoUrl,
        }),
        fallbackError: 'Message non envoyé',
      );

  Future<Map<String, dynamic>> updateMessage(String messageId, String body) =>
      _mutate(
        () => _apiService.updateMessage(messageId, body),
        fallbackError: 'Message non modifié',
      );

  Future<Map<String, dynamic>> deleteMessage(String messageId) => _mutate(
        () => _apiService.deleteMessage(messageId),
        fallbackError: 'Message non supprimé',
      );

  /// Accusé de lecture unitaire. Ne recharge pas le fil : ouvrir la
  /// conversation marque déjà tous ses messages côté API.
  Future<void> markRead(String messageId) async {
    try {
      await _apiService.markMessageRead(messageId);
    } catch (e) {
      debugPrint('❌ Accusé de lecture: $e');
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }

  void reset() => state = MessageState.initial();
}

class MessageState {
  final bool isLoading;
  final bool isLoadingThread;
  final bool isMutating;

  /// Conversations agrégées par (interlocuteur, colis) — contrat renvoyé par
  /// l'API, partagé avec le web.
  final List<Map<String, dynamic>> conversations;
  final List<Map<String, dynamic>> thread;

  /// Interlocuteur et colis du fil affiché, retenus pour le rechargement après
  /// une mutation.
  final String? activePeerId;
  final String? activeParcelId;
  final String? error;

  const MessageState({
    required this.isLoading,
    this.isLoadingThread = false,
    this.isMutating = false,
    this.conversations = const [],
    this.thread = const [],
    this.activePeerId,
    this.activeParcelId,
    this.error,
  });

  factory MessageState.initial() => const MessageState(isLoading: false);

  /// `error` n'est pas conservée quand elle n'est pas passée : chaque tentative
  /// repart d'un état propre. Le fil actif l'est, en revanche — les mutations
  /// appellent `copyWith` sans le repréciser et doivent pouvoir le recharger.
  MessageState copyWith({
    bool? isLoading,
    bool? isLoadingThread,
    bool? isMutating,
    List<Map<String, dynamic>>? conversations,
    List<Map<String, dynamic>>? thread,
    String? activePeerId,
    String? activeParcelId,
    String? error,
  }) {
    return MessageState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingThread: isLoadingThread ?? this.isLoadingThread,
      isMutating: isMutating ?? this.isMutating,
      conversations: conversations ?? this.conversations,
      thread: thread ?? this.thread,
      activePeerId: activePeerId ?? this.activePeerId,
      activeParcelId: activeParcelId ?? this.activeParcelId,
      error: error,
    );
  }

  int get unreadCount => conversations.fold<int>(
        0,
        (total, conversation) =>
            total + ((conversation['unreadCount'] as num?)?.toInt() ?? 0),
      );
}
