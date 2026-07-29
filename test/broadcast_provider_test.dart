import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/models/broadcast.dart';
import 'package:procolis/providers/broadcast_provider.dart';

void main() {
  Broadcast broadcast({
    String id = 'broadcast-1',
    bool active = true,
    List<String> roles = const ['client'],
    DateTime? startsAt,
    DateTime? endsAt,
  }) {
    final now = DateTime.now();
    return Broadcast(
      id: id,
      title: 'Information',
      message: 'Message important',
      targetRoles: roles,
      active: active,
      startsAt: startsAt ?? now.subtract(const Duration(minutes: 5)),
      endsAt: endsAt ?? now.add(const Duration(days: 1)),
      createdAt: now,
    );
  }

  group('filterActiveBroadcasts', () {
    test('affiche un message actif ciblant le rôle courant', () {
      final visible = filterActiveBroadcasts(
        [broadcast()],
        const {},
        'client',
      );

      expect(visible.map((item) => item.id), ['broadcast-1']);
    });

    test('masque seulement pendant une mise en veille encore active', () {
      final item = broadcast();

      final snoozed = filterActiveBroadcasts(
        [item],
        {'broadcast-1': DateTime.now().add(const Duration(hours: 2))},
        'client',
      );
      final expired = filterActiveBroadcasts(
        [item],
        {'broadcast-1': DateTime.now().subtract(const Duration(seconds: 1))},
        'client',
      );

      expect(snoozed, isEmpty);
      expect(expired.map((entry) => entry.id), ['broadcast-1']);
    });

    test('respecte le rôle, l’activation et la période administrateur', () {
      final now = DateTime.now();
      final all = [
        broadcast(id: 'wrong-role', roles: const ['driver']),
        broadcast(id: 'inactive', active: false),
        broadcast(
          id: 'future',
          startsAt: now.add(const Duration(hours: 1)),
        ),
        broadcast(
          id: 'finished',
          endsAt: now.subtract(const Duration(hours: 1)),
        ),
      ];

      expect(filterActiveBroadcasts(all, const {}, 'client'), isEmpty);
    });
  });
}
