import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/config/app_config.dart';
import 'package:procolis/providers/session_lock_provider.dart';

void main() {
  group('SessionLockNotifier', () {
    test('bloque un démarrage à froid quand la biométrie est activée',
        () async {
      final notifier = SessionLockNotifier(
        isBiometricEnabled: () async => true,
      );
      addTearDown(notifier.dispose);

      expect(notifier.state, SessionLockStatus.checking);

      await notifier.initializeOnLaunch();

      expect(notifier.state, SessionLockStatus.locked);
    });

    test('ouvre directement si la biométrie est désactivée', () async {
      final notifier = SessionLockNotifier(
        isBiometricEnabled: () async => false,
      );
      addTearDown(notifier.dispose);

      await notifier.initializeOnLaunch();

      expect(notifier.state, SessionLockStatus.unlocked);
    });

    test('garde le repli serveur si le stockage sécurisé échoue', () async {
      final notifier = SessionLockNotifier(
        isBiometricEnabled: () async =>
            throw StateError('Keystore indisponible'),
      );
      addTearDown(notifier.dispose);

      await notifier.initializeOnLaunch();

      expect(notifier.state, SessionLockStatus.unlocked);
    });

    test('verrouille après une absence supérieure au délai', () async {
      var now = DateTime(2026, 9, 18, 12);
      var biometricEnabled = false;
      final notifier = SessionLockNotifier(
        isBiometricEnabled: () async => biometricEnabled,
        now: () => now,
      );
      addTearDown(notifier.dispose);

      await notifier.initializeOnLaunch();
      biometricEnabled = true;
      notifier.markBackgrounded();
      now = now.add(AppConfig.sessionIdleTimeout + const Duration(seconds: 1));

      await notifier.evaluateOnResume();

      expect(notifier.state, SessionLockStatus.locked);

      notifier.unlock();
      expect(notifier.state, SessionLockStatus.unlocked);
    });

    test('ne verrouille pas après une absence courte', () async {
      var now = DateTime(2026, 9, 18, 12);
      final notifier = SessionLockNotifier(
        isBiometricEnabled: () async => true,
        now: () => now,
      );
      addTearDown(notifier.dispose);

      await notifier.initializeOnLaunch();
      notifier.unlock();
      notifier.markBackgrounded();
      now = now.add(AppConfig.sessionIdleTimeout - const Duration(seconds: 1));

      await notifier.evaluateOnResume();

      expect(notifier.state, SessionLockStatus.unlocked);
    });
  });
}
