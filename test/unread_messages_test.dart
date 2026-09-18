import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/utils/unread_messages.dart';

void main() {
  group('totalUnreadMessages', () {
    test('additionne tous les messages, pas seulement les conversations', () {
      final total = totalUnreadMessages([
        {'unreadCount': 3},
        {'unreadCount': 2},
        {'unreadCount': 0},
      ]);

      expect(total, 5);
    });

    test('tolère un compteur sérialisé en chaîne', () {
      expect(unreadMessagesInConversation({'unreadCount': '4'}), 4);
    });

    test('garde le repli compatible avec une ancienne API', () {
      expect(
        unreadMessagesInConversation(
          {
            'receiver': {'id': 'me'},
            'isRead': false,
          },
          currentUserId: 'me',
        ),
        1,
      );
    });
  });
}
