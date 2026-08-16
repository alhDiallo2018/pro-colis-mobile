// mobile/lib/providers/session_lock_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/biometric_service.dart';

final sessionLockProvider =
    StateNotifierProvider<SessionLockNotifier, bool>((ref) {
  return SessionLockNotifier();
});

/// Verrouillage de l'écran après une mise en arrière-plan prolongée.
///
/// L'API ferme la session au-delà de `SESSION_IDLE_TIMEOUT`. Sans ce verrou,
/// l'utilisateur retrouverait ses écrans habituels dont chaque requête
/// répondrait 401, puis serait renvoyé à la connexion complète. Le verrou lui
/// offre le chemin court : une empreinte au lieu du PIN.
///
/// Il ne s'active que si le déverrouillage biométrique est configuré : sans
/// empreinte enregistrée, le verrou n'offrirait aucune sortie plus rapide que
/// l'écran de connexion, vers lequel le 401 ramène déjà.
class SessionLockNotifier extends StateNotifier<bool> {
  SessionLockNotifier() : super(false);

  DateTime? _leftAt;

  /// L'application passe en arrière-plan : on note l'heure de départ.
  void markBackgrounded() {
    _leftAt ??= DateTime.now();
  }

  /// Retour au premier plan : verrouille si l'absence a dépassé le délai.
  Future<void> evaluateOnResume() async {
    final leftAt = _leftAt;
    _leftAt = null;
    if (leftAt == null || state) return;

    final away = DateTime.now().difference(leftAt);
    if (away < AppConfig.sessionIdleTimeout) return;

    if (!await BiometricService.isEnabled()) return;

    debugPrint('[SessionLock] Absence de ${away.inSeconds}s : verrouillage');
    if (mounted) state = true;
  }

  void unlock() {
    _leftAt = null;
    if (mounted) state = false;
  }
}
