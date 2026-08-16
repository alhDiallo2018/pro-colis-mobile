import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api_service.dart';

/// Synchronise le badge numérique sur l'icône de l'application (Android + iOS).
///
/// Le badge reflète le **nombre réel d'éléments non lus** côté SendProColis
/// (notifications + messages, source de vérité : le backend), jamais le nombre
/// de push FCM reçues.
///
/// Côté Android, chaque launcher est adressé via son broadcast dédié
/// (Samsung, Sony, HTC, LG, Huawei, ZTE, OPPO/Vivo). Lorsque le launcher ne
/// supporte pas les badges numériques (ex. Pixel/stock), l'appel est un no-op :
/// aucun crash, aucun effet de bord. Côté iOS, `AppDelegate` applique le compte
/// via `UNUserNotificationCenter`, ce qui couvre aussi la remise à zéro après
/// lecture — la charge APNs ne sait que l'incrémenter.
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

  /// Interroge le backend pour le nombre d'éléments non lus puis applique le
  /// badge. À appeler au démarrage, à la reprise d'activité et après toute
  /// lecture.
  static Future<void> refresh() async {
    if (kIsWeb) return;
    try {
      final count = await ApiService().getUnreadBadgeCount();
      await setCount(count);
    } catch (_) {
      // Le badge sera resynchronisé au prochain cycle.
    }
  }

  /// Applique le compte transporté par une push (`data['badge']`).
  ///
  /// Le serveur joint le nombre de non-lus à chaque message : le badge est donc
  /// juste dès la réception, sans aller-retour réseau — indispensable quand la
  /// push arrive alors que l'application est en arrière-plan ou fermée.
  /// Retourne `false` si la charge ne portait pas de compte exploitable, à
  /// charge de l'appelant de retomber sur [refresh].
  static Future<bool> applyFromPushData(Map<String, dynamic> data) async {
    if (kIsWeb) return false;
    final raw = data['badge'];
    final count = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (count == null) return false;
    await setCount(count);
    return true;
  }
}
