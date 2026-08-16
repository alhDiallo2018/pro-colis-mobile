// mobile/lib/services/biometric_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Déverrouillage biométrique.
///
/// L'API ferme la session après une minute d'inactivité : au retour de
/// l'utilisateur, la session est réellement morte côté serveur. Le
/// déverrouillage ne peut donc pas se contenter de révéler l'écran, il doit
/// rejouer une connexion. C'est pourquoi le PIN est conservé ici : l'empreinte
/// en commande la lecture, la reconnexion s'appuie dessus.
///
/// Limite assumée : la biométrie est un portail applicatif, le secret est
/// protégé par le Keychain / Keystore mais n'est pas lié cryptographiquement au
/// capteur. Un appareil rooté ou jailbreaké contourne le portail. Le secret
/// gardé étant un PIN à six chiffres, dont l'usage est de toute façon limité
/// par le serveur, ce niveau est proportionné.
class BiometricService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final LocalAuthentication _auth = LocalAuthentication();

  static const String _enabledKey = 'biometric_enabled';
  static const String _pinKey = 'biometric_pin';

  /// L'appareil dispose-t-il d'un capteur utilisable et configuré ?
  ///
  /// `isDeviceSupported` couvre le matériel, `canCheckBiometrics` le fait
  /// qu'au moins une empreinte soit enrôlée : un capteur présent mais vide
  /// ferait échouer la demande sans que l'utilisateur comprenne pourquoi.
  static Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (error) {
      debugPrint('[Biometric] Capteur indisponible : ${error.message}');
      return false;
    }
  }

  /// Le déverrouillage est-il actif ET exploitable (secret toujours présent) ?
  static Future<bool> isEnabled() async {
    try {
      if (await _storage.read(key: _enabledKey) != 'true') return false;
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
  static Future<bool> authenticate(String reason) async {
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

  /// Active le déverrouillage en confiant le PIN au stockage sécurisé.
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
  }

  static Future<String?> readPin() async => _storage.read(key: _pinKey);
}
