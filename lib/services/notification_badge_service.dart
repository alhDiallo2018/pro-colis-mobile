import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';

/// Synchronise le badge numérique sur l'icône de l'application (Android).
///
/// Le badge reflète le **nombre réel d'éléments non lus** côté SendProColis
/// (source de vérité : le backend), jamais le nombre de push FCM reçues.
///
/// Côté natif, chaque launcher est adressé via son broadcast dédié
/// (Samsung, Sony, HTC, LG, Huawei, ZTE, OPPO/Vivo). Lorsque le launcher ne
/// supporte pas les badges numériques (ex. Pixel/stock), l'appel est un no-op :
/// aucun crash, aucun effet de bord.
class NotificationBadgeService {
  NotificationBadgeService._();

  static const MethodChannel _channel = MethodChannel('sendprocolis/badge');

  /// Applique [count] comme badge. `0` ou moins supprime le badge.
  static Future<void> setCount(int count) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('setBadgeCount', count < 0 ? 0 : count);
    } on MissingPluginException {
      // Plateforme sans implémentation native (simulateurs, autres OS).
    } on PlatformException {
      // Launcher non supporté : le badge est ignoré.
    } catch (_) {
      // Jamais bloquant.
    }
  }

  /// Supprime le badge.
  static Future<void> remove() => setCount(0);

  /// Interroge le backend pour le nombre de notifications non lues puis
  /// applique le badge. À appeler au démarrage, à la reprise d'activité et
  /// après toute lecture.
  static Future<void> refresh() async {
    if (kIsWeb) return;
    try {
      final count = await ApiService().getUnreadNotificationsCount();
      await setCount(count);
    } catch (_) {
      // Le badge sera resynchronisé au prochain cycle.
    }
  }
}
