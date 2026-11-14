/// Configuration réseau partagée par tous les clients HTTP de l'application.
///
/// Centraliser ces valeurs évite qu'un service secondaire (notifications,
/// diffusion, paiement) cible une autre API que le client principal.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Mode TEST LOCAL — cible le backend démarré sur l'hôte (port 18081 du
    // docker-compose). Rappels par cible :
    //   - Flutter web / macOS / iOS Simulator → `http://localhost:18081`
    //   - Android Emulator (AVD)             → `http://10.0.2.2:18081`
    //   - Device physique                    → `http://<IP_LAN_de_votre_mac>:18081`
    // Pour un build de prod, injecter explicitement :
    //   flutter build apk --dart-define=API_BASE_URL=https://sendprocolis.com/api/v1
    defaultValue: 'http://localhost:18081/api/v1',
  );

  /// Verrou LOCAL uniquement : la biometrie protege l'ecran sans fermer la
  /// session reseau. L'ancien define reste accepte pour les scripts de build.
  static const int sessionLockTimeoutSeconds = int.fromEnvironment(
    'SESSION_LOCK_TIMEOUT_SECONDS',
    defaultValue:
        int.fromEnvironment('SESSION_IDLE_TIMEOUT_SECONDS', defaultValue: 60),
  );
  static Duration get sessionLockTimeout =>
      Duration(seconds: sessionLockTimeoutSeconds);

  static const String _configuredPublicAppUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: '',
  );

  /// Origine publique de l'application, utilisée pour les liens partageables.
  ///
  /// Sur le web, `Uri.base` permet de suivre automatiquement le domaine qui
  /// sert le build. Sur mobile, l'origine de l'API constitue un repli cohérent
  /// lorsque `APP_BASE_URL` n'a pas été injectée.
  /// Origine publique de référence utilisée dans les partages (QR, liens).
  /// Un fallback production garantit qu'un APK compilé sans `--dart-define`
  /// n'envoie jamais `localhost:...` à un destinataire.
  static const String _productionPublicAppUrl = 'https://sendprocolis.com';

  static String get publicAppUrl {
    if (_configuredPublicAppUrl.trim().isNotEmpty) {
      return _withoutTrailingSlash(_configuredPublicAppUrl.trim());
    }

    final runtimeUri = Uri.base;
    if (runtimeUri.hasScheme &&
        (runtimeUri.scheme == 'http' || runtimeUri.scheme == 'https') &&
        !_isLocalHost(runtimeUri.host)) {
      return runtimeUri.origin;
    }

    final apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri != null &&
        apiUri.hasScheme &&
        (apiUri.scheme == 'http' || apiUri.scheme == 'https') &&
        !_isLocalHost(apiUri.host)) {
      return apiUri.origin;
    }

    // Jamais de localhost dans un lien partagé : repli explicite sur le
    // domaine public, même en dev si rien n'est configuré.
    return _productionPublicAppUrl;
  }

  static bool _isLocalHost(String host) {
    final h = host.toLowerCase();
    return h == 'localhost' ||
        h == '127.0.0.1' ||
        h == '0.0.0.0' ||
        h == '10.0.2.2' ||
        h.endsWith('.local');
  }

  static String get mediaBaseUrl {
    var base = _withoutTrailingSlash(apiBaseUrl);
    for (final suffix in const ['/api/v1', '/api']) {
      if (base.endsWith(suffix)) {
        base = base.substring(0, base.length - suffix.length);
        break;
      }
    }
    return base;
  }

  static String resolveMediaUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = mediaBaseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  static String trackingUrl(String trackingNumber) {
    final encodedTrackingNumber = Uri.encodeComponent(trackingNumber);
    return '$publicAppUrl/track/$encodedTrackingNumber';
  }

  /// Hôte public affichable (sans schéma), dérivé de l'origine configurée.
  static String get publicHost {
    final uri = Uri.tryParse(publicAppUrl);
    return uri?.host.isNotEmpty == true ? uri!.host : 'localhost';
  }

  static String _withoutTrailingSlash(String value) {
    var result = value;
    while (result.endsWith('/') && result.length > 1) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
