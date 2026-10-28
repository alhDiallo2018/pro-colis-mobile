// mobile/lib/services/biometric_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'auth_session.dart';

/// Déverrouillage biométrique.
///
/// Le verrou local conserve la session et ses données synchronisées. Le réglage
/// est lié au compte, sans rejouer une connexion PIN ni mémoriser de nouveau PIN.
/// L'authentification système offre un repli par code de l'appareil hors ligne.
class BiometricService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final LocalAuthentication _auth = LocalAuthentication();

  static const String _enabledKey = 'biometric_enabled';
  static const String _pinKey = 'biometric_pin';
  static const String _ownerKey = 'biometric_owner_v2';
  static Future<bool>? _authentication;

  /// L'appareil dispose-t-il d'un capteur utilisable et configuré ?
  ///
  /// getAvailableBiometrics vérifie l'enrôlement réel : la présence d'un capteur
  /// seule ne suffit pas à promettre un déverrouillage biométrique.
  static Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException catch (error) {
      debugPrint('[Biometric] Capteur indisponible : ${error.message}');
      return false;
    }
  }

  /// Le déverrouillage est-il actif pour la session conservée sur cet appareil ?
  static Future<bool> isEnabled() async {
    try {
      if (await _storage.read(key: _enabledKey) != 'true') return false;
      if (await AuthSessionManager.instance.read() == null) return false;
      final owner = await _storage.read(key: _ownerKey);
      if (owner != null) {
        final cachedOwner = await currentOwner();
        // Un cache absent ne doit pas désactiver silencieusement le verrou.
        return cachedOwner == null || owner == cachedOwner;
      }
      // Compatibilité des installations antérieures ; le secret sera retiré
      // lors de la prochaine activation ou connexion vérifiée du même compte.
      final pin = await _storage.read(key: _pinKey);
      return pin != null && pin.isNotEmpty;
    } catch (error) {
      debugPrint('[Biometric] Lecture du réglage impossible : $error');
      return false;
    }
  }

  /// Demande l'empreinte. Ne rend `true` que si l'utilisateur s'est identifié.
  ///
  /// `biometricOnly` reste à false : le code de l'appareil est un repli
  /// légitime, et un capteur sale ou mouillé ne doit pas enfermer l'utilisateur
  /// dehors.
  static Future<bool> authenticate(String reason) {
    // Un dialogue natif peut rendre l'app inactive. Partager la même demande
    // évite deux prompts concurrents lors des callbacks de reprise.
    return _authentication ??=
        _authenticate(reason).whenComplete(() => _authentication = null);
  }

  static Future<bool> _authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (error) {
      debugPrint('[Biometric] Authentification refusée : ${error.message}');
      return false;
    }
  }

  static Future<String?> currentOwner() async {
    final session = await AuthSessionManager.instance.read();
    if (session == null) return null;
    final profile = await AuthSessionManager.instance
        .readCachedResponse(session.generation, '/auth/me');
    final user = profile?['data']?['user'];
    return user is Map ? user['id']?.toString() : null;
  }

  /// L'OS a déjà vérifié l'utilisateur. Lier le réglage à son compte, sans
  /// ouvrir une nouvelle session serveur ni supprimer son historique local.
  static Future<void> enableForSession(String userId) async {
    if (await currentOwner() != userId)
      throw StateError('Session locale indisponible');
    await _storage.write(key: _ownerKey, value: userId);
    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.delete(key: _pinKey);
  }

  /// Compatibilité des anciennes installations ; les nouvelles activations
  /// utilisent enableForSession et ne mémorisent plus le PIN.
  static Future<void> enable(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _enabledKey, value: 'true');
  }

  /// Désactive et efface le secret. Appelé aussi à la déconnexion explicite :
  /// garder le PIN d'un compte que l'utilisateur vient de quitter n'aurait
  /// aucune contrepartie de confort.
  static Future<void> disable() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _ownerKey);
  }

  static Future<String?> readPin() async => _storage.read(key: _pinKey);
}
