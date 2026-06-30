import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'procolis_channel',
      'PRO COLIS Notifications',
      channelDescription: 'Notifications des colis',
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  static Future<void> showParcelStatusNotification(String trackingNumber, String status, String location) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: 'Mise à jour colis',
      body: 'Colis $trackingNumber: $status à $location',
      payload: trackingNumber,
    );
  }

  static Future<void> showDeliveryNotification(String trackingNumber, String receiverName) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: '🎉 Colis livré !',
      body: 'Colis $trackingNumber livré à $receiverName',
      payload: trackingNumber,
    );
  }
}
