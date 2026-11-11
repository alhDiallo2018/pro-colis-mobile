// Provider Riverpod de la preference "duree de session". Centralise la lecture
// (asynchrone, depuis SharedPreferences) et l'ecriture pour que le reglage soit
// partage entre la page Parametres et le verrou local (SessionLockNotifier).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/session_timeout_preference.dart';

final sessionTimeoutProvider =
    StateNotifierProvider<SessionTimeoutNotifier, SessionTimeoutOption>((ref) {
  return SessionTimeoutNotifier();
});

class SessionTimeoutNotifier extends StateNotifier<SessionTimeoutOption> {
  SessionTimeoutNotifier() : super(SessionTimeoutOption.defaultOption) {
    _load();
  }

  Future<void> _load() async {
    final value = await SessionTimeoutStore.read();
    if (mounted) state = value;
  }

  Future<void> setOption(SessionTimeoutOption option) async {
    if (option == state) return;
    state = option;
    await SessionTimeoutStore.write(option);
  }
}
