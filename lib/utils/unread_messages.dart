/// Nombre réel de messages non lus dans une conversation renvoyée par l'API.
///
/// Les versions récentes exposent `unreadCount`. Le repli historique ne vaut
/// qu'un message au maximum et sert uniquement avec une ancienne API.
int unreadMessagesInConversation(
  Map<String, dynamic> conversation, {
  String? currentUserId,
}) {
  final raw = conversation['unreadCount'] ?? conversation['unread'];
  final count = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  if (count != null) return count < 0 ? 0 : count;

  final receiver = conversation['receiver'];
  final receiverId = receiver is Map
      ? receiver['id']?.toString()
      : conversation['receiverId']?.toString();
  return currentUserId != null &&
          receiverId == currentUserId &&
          conversation['isRead'] != true
      ? 1
      : 0;
}

int totalUnreadMessages(
  Iterable<Map<String, dynamic>> conversations, {
  String? currentUserId,
}) =>
    conversations.fold(
      0,
      (total, conversation) =>
          total +
          unreadMessagesInConversation(
            conversation,
            currentUserId: currentUserId,
          ),
    );
