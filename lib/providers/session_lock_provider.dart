// mobile/lib/providers/session_lock_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/biometric_service.dart';

final sessionLockProvider =
    StateNotifierProvider<SessionLockNotifier, SessionLockStatus>((ref) {
  return SessionLockNotifier();
});

/// Les trois états sont distincts pour éviter d'afficher brièvement un écran
/// privé pendant la lecture asynchrone du stockage sécurisé au démarrage.
enum SessionLockStatus {
  checking,
  unlocked,
  locked,
}

typedef BiometricEnabledReader = Future<bool> Function();
typedef SessionClock = DateTime Function();

/// Verrouillage de l'écran au lancement et après un arrière-plan prolongé.
///
/// L'API ferme la session au-delà de `SESSION_IDLE_TIMEOUT`. Sans ce verrou,
/// l'utilisateur retrouverait ses écrans habituels dont chaque requête
/// répondrait 401, puis serait renvoyé à la connexion complète. Le verrou lui
/// offre le chemin court : une empreinte au lieu du PIN.
///
/// Au démarrage à froid, il empêche aussi une restauration silencieuse du jeton
/// de contourner l'option biométrique choisie dans les paramètres.
///
/// Il ne s'active que si le déverrouillage biométrique est configuré : sans
/// empreinte enregistrée, le verrou n'offrirait aucune sortie plus rapide que
/// l'écran de connexion, vers lequel le 401 ramène déjà.
class SessionLockNotifier extends StateNotifier<SessionLockStatus> {
  SessionLockNotifier({
    BiometricEnabledReader? isBiometricEnabled,
    SessionClock? now,
  })  : _isBiometricEnabled = isBiometricEnabled ?? BiometricService.isEnabled,
        _now = now ?? DateTime.now,
        super(SessionLockStatus.checking);

  final BiometricEnabledReader _isBiometricEnabled;
  final SessionClock _now;

  DateTime? _leftAt;
  bool _initialized = false;

  /// Résout le verrou avant de laisser apparaître l'application.
  ///
  /// Une biométrie configurée verrouille aussi un démarrage à froid : la
  /// restauration silencieuse du jeton ne doit pas permettre de contourner
  /// l'empreinte en tuant puis en relançant le processus.
  Future<void> initializeOnLaunch() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final enabled = await _isBiometricEnabled();
      if (!mounted) return;
      state = enabled ? SessionLockStatus.locked : SessionLockStatus.unlocked;
      if (enabled) {
        debugPrint(
            '[SessionLock] Démarrage à froid : verrouillage biométrique');
      }
    } catch (error, stackTrace) {
      // Une panne du stockage sécurisé ne doit pas enfermer un utilisateur
      // sans solution : l'authentification serveur reste la barrière de repli.
      debugPrint(
        '[SessionLock] Impossible de lire le réglage biométrique : $error',
      );
      debugPrintStack(
        label: '[SessionLock] Trace d’initialisation',
        stackTrace: stackTrace,
      );
      if (mounted) state = SessionLockStatus.unlocked;
    }
  }

  /// L'application passe en arrière-plan : on note l'heure de départ.
  void markBackgrounded() {
    _leftAt ??= _now();
  }

  /// Retour au premier plan : verrouille si l'absence a dépassé le délai.
  Future<void> evaluateOnResume() async {
    final leftAt = _leftAt;
    _leftAt = null;
    if (leftAt == null || state != SessionLockStatus.unlocked) return;

    final away = _now().difference(leftAt);
    if (away < AppConfig.sessionIdleTimeout) return;

    try {
      if (!await _isBiometricEnabled()) return;
      debugPrint('[SessionLock] Absence de ${away.inSeconds}s : verrouillage');
      if (mounted) state = SessionLockStatus.locked;
    } catch (error, stackTrace) {
      debugPrint('[SessionLock] Vérification au retour impossible : $error');
      debugPrintStack(
        label: '[SessionLock] Trace de reprise',
        stackTrace: stackTrace,
      );
    }
  }

  void unlock() {
    _leftAt = null;
    if (mounted) state = SessionLockStatus.unlocked;
  }
}
