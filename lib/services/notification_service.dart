import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Affichage des notifications locales (canal `sendprocolis_channel`).
///
/// En complément de l'affichage, ce service relaie le tap sur une
/// notification locale vers [onNotificationTap], ce qui permet de naviguer
/// vers la page métier correspondante (les messages reçus au premier plan
/// sont affichés localement, leur tap doit ouvrir la même destination qu'une
/// push FCM).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Callback appelé quand l'utilisateur tape sur une notification locale.
  /// Reçoit le `payload` (généralement les données FCM encodées en JSON).
  static void Function(String? payload)? _onNotificationTap;
  static String? _pendingPayload;

  static void Function(String? payload)? get onNotificationTap =>
      _onNotificationTap;

  static set onNotificationTap(void Function(String? payload)? handler) {
    _onNotificationTap = handler;
    final pending = _pendingPayload;
    if (handler != null && pending != null) {
      _pendingPayload = null;
      handler(pending);
    }
  }

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'sendprocolis_channel',
    'SENDPROCOLIS Notifications',
    channelDescription: 'Notifications des colis',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const DarwinNotificationDetails _iosDetails =
      DarwinNotificationDetails();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // App relancée depuis une notification (terminée).
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _onNotificationResponse(launchDetails!.notificationResponse);
    }
  }

  static void _onNotificationResponse(NotificationResponse? response) {
    if (response == null) return;
    if (_onNotificationTap != null) {
      _onNotificationTap!(response.payload);
    } else {
      _pendingPayload = response.payload;
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    Map<String, dynamic>? data,
  }) async {
    // Les données structurées sont encodées en JSON pour être restituées au
    // tap (navigation). `payload` reste prioritaire pour la rétro-compatibilité.
    final effectivePayload =
        payload ?? (data != null ? jsonEncode(data) : null);
    const NotificationDetails details = NotificationDetails(
      android: _androidDetails,
      iOS: _iosDetails,
    );
    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: effectivePayload,
    );
  }

  static Future<void> showParcelStatusNotification(
      String trackingNumber, String status, String location) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: 'Mise à jour colis',
      body: 'Colis $trackingNumber: $status à $location',
      payload: trackingNumber,
    );
  }

  static Future<void> showDeliveryNotification(
      String trackingNumber, String receiverName) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: '🎉 Colis livré !',
      body: 'Colis $trackingNumber livré à $receiverName',
      payload: trackingNumber,
    );
  }
}
