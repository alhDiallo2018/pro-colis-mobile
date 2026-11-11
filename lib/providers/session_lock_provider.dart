// mobile/lib/providers/session_lock_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/biometric_service.dart';
import '../services/session_timeout_preference.dart';
import 'auth_provider.dart';

final sessionLockProvider =
    StateNotifierProvider<SessionLockNotifier, SessionLockStatus>((ref) {
  // En production, la duree d'inactivite vient de la preference utilisateur,
  // et l'absence de biometrie force un retour a l'ecran de connexion plutot
  // que de laisser l'application sans verrou.
  return SessionLockNotifier(
    timeoutReader: () async => (await SessionTimeoutStore.read()).duration,
    onForceLogout: () async {
      sessionExpiredNotice.value =
          'Session terminee selon votre reglage. Reconnectez-vous pour continuer.';
      await ref.read(authProvider.notifier).logout(forgetBiometrics: false);
    },
  );
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
typedef SessionTimeoutReader = Future<Duration> Function();
typedef SessionForceLogout = Future<void> Function();

/// Verrouillage de l'écran au lancement et après un arrière-plan prolongé.
///
/// Le verrou est local et independant de l'expiration serveur. Le passage en
/// arriere-plan ne supprime jamais les jetons et le retour peut fonctionner
/// sans connexion reseau. La verification API conserve ses propres limites.
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
    SessionTimeoutReader? timeoutReader,
    SessionForceLogout? onForceLogout,
  })  : _isBiometricEnabled = isBiometricEnabled ?? BiometricService.isEnabled,
        _now = now ?? DateTime.now,
        _readTimeout = timeoutReader ?? (() async => AppConfig.sessionLockTimeout),
        _onForceLogout = onForceLogout,
        super(SessionLockStatus.checking);

  final BiometricEnabledReader _isBiometricEnabled;
  final SessionClock _now;
  final SessionTimeoutReader _readTimeout;
  final SessionForceLogout? _onForceLogout;

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

  /// Retour au premier plan : verrouille si l'absence a depasse le delai, ou
  /// force un retour a la page de connexion si l'utilisateur n'a pas configure
  /// la biometrie (sinon le delai promis par les parametres n'aurait aucun
  /// effet sur son compte).
  Future<void> evaluateOnResume() async {
    final leftAt = _leftAt;
    _leftAt = null;
    if (leftAt == null || state != SessionLockStatus.unlocked) return;

    final away = _now().difference(leftAt);
    Duration timeout;
    try {
      timeout = await _readTimeout();
    } catch (_) {
      timeout = AppConfig.sessionLockTimeout;
    }
    if (away < timeout) return;

    try {
      if (await _isBiometricEnabled()) {
        debugPrint('[SessionLock] Absence de ${away.inSeconds}s : verrouillage');
        if (mounted) state = SessionLockStatus.locked;
        return;
      }
      // Sans biometrie, on ne peut pas afficher un verrou local credible : on
      // ramene l'utilisateur a la connexion pour respecter sa duree choisie.
      final forceLogout = _onForceLogout;
      if (forceLogout != null) {
        debugPrint(
            '[SessionLock] Absence de ${away.inSeconds}s : fermeture de session');
        await forceLogout();
      }
    } catch (error, stackTrace) {
      debugPrint('[SessionLock] Verification au retour impossible : $error');
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
