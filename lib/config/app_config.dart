/// Configuration réseau partagée par tous les clients HTTP de l'application.
///
/// Centraliser ces valeurs évite qu'un service secondaire (notifications,
/// diffusion, paiement) cible une autre API que le client principal.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:18081/api/v1',
  );

  static const String _configuredPublicAppUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: '',
  );

  /// Origine publique de l'application, utilisée pour les liens partageables.
  ///
  /// Sur le web, `Uri.base` permet de suivre automatiquement le domaine qui
  /// sert le build. Sur mobile, l'origine de l'API constitue un repli cohérent
  /// lorsque `APP_BASE_URL` n'a pas été injectée.
  static String get publicAppUrl {
    if (_configuredPublicAppUrl.trim().isNotEmpty) {
      return _withoutTrailingSlash(_configuredPublicAppUrl.trim());
    }

    final runtimeUri = Uri.base;
    if (runtimeUri.hasScheme &&
        (runtimeUri.scheme == 'http' || runtimeUri.scheme == 'https')) {
      return runtimeUri.origin;
    }

    final apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri != null &&
        apiUri.hasScheme &&
        (apiUri.scheme == 'http' || apiUri.scheme == 'https')) {
      return apiUri.origin;
    }

    return 'https://sendprocolis.com';
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

  static String _withoutTrailingSlash(String value) {
    var result = value;
    while (result.endsWith('/') && result.length > 1) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
