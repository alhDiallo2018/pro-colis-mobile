// mobile/lib/services/push_notification_service.dart
//
// Notifications push via Firebase Cloud Messaging (FCM).
//
// IMPORTANT — configuration Firebase requise pour activer le push :
//   TODO: placer `google-services.json` dans `android/app/` (console Firebase >
//         Paramètres du projet > Vos applications > Android), puis activer le
//         plugin Gradle `com.google.gms.google-services` (voir les TODO dans
//         android/settings.gradle et android/app/build.gradle.kts).
//   TODO: placer `GoogleService-Info.plist` dans `ios/Runner/` (console
//         Firebase > Vos applications > iOS) et l'ajouter au target Runner
//         dans Xcode. Activer aussi la capability "Push Notifications" et
//         "Background Modes > Remote notifications".
//
// Sans ces fichiers, `Firebase.initializeApp()` échoue : ce service est conçu
// pour dégrader proprement — l'app continue de fonctionner, le push est
// simplement désactivé.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api/client.dart';
import 'api/notifications_api.dart';
import 'notification_service.dart';

/// Handler des messages reçus quand l'app est en background / terminée.
/// Doit être une fonction top-level annotée `vm:entry-point` (exécutée dans
/// un isolate séparé par le plugin firebase_messaging).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Fichiers de config Firebase absents : rien à faire.
    return;
  }

  // Les messages contenant un bloc `notification` sont affichés
  // automatiquement par le système en background. On n'affiche manuellement
  // que les messages "data-only".
  if (message.notification == null && message.data.isNotEmpty) {
    try {
      await NotificationService.initialize();
      await NotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.hashCode,
        title: message.data['title']?.toString() ?? 'SENDPROCOLIS',
        body: message.data['body']?.toString() ?? '',
        payload: message.data['trackingNumber']?.toString(),
      );
    } catch (_) {
      // Jamais bloquant.
    }
  }
}

class PushNotificationService {
  PushNotificationService._();

  static bool _firebaseReady = false;
  static bool _listenersAttached = false;
  static String? _currentToken;

  static NotificationsApi? _notificationsApiOverride;
  static NotificationsApi get _api =>
      _notificationsApiOverride ??= NotificationsApi(ApiClient());

  /// `true` si Firebase a pu être initialisé (fichiers de config présents).
  static bool get isAvailable => _firebaseReady;

  /// Initialise Firebase + FCM. À appeler depuis `main()` après l'init des
  /// notifications locales. Ne lève jamais : sans config Firebase, le push
  /// est simplement désactivé.
  static Future<void> initialize() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      debugPrint(
          'PushNotificationService: Firebase non configuré, push désactivé '
          '(ajouter google-services.json / GoogleService-Info.plist). $e');
      return;
    }

    try {
      await _setupMessaging();
    } catch (e) {
      debugPrint('PushNotificationService: erreur init FCM: $e');
    }
  }

  static Future<void> _setupMessaging() async {
    if (_listenersAttached) return;
    _listenersAttached = true;

    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Handler background (non supporté sur le web).
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // Demande de permission (Android 13+ / iOS / web).
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS : laisser le système afficher les notifications en foreground.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Message reçu pendant que l'app est au premier plan.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // L'utilisateur a tapé la notification (app en background).
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // L'app a été lancée depuis une notification (app terminée).
    final RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpenedApp(initialMessage);
    }

    // Rafraîchissement du token FCM -> ré-enregistrement côté backend.
    messaging.onTokenRefresh.listen((String token) {
      _currentToken = token;
      unawaited(_sendTokenToBackend(token));
    });
  }

  static void _onForegroundMessage(RemoteMessage message) {
    // Sur iOS le système affiche déjà la notification en foreground
    // (setForegroundNotificationPresentationOptions ci-dessus).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return;

    final String? title =
        message.notification?.title ?? message.data['title']?.toString();
    final String? body =
        message.notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    unawaited(NotificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch.hashCode,
      title: title ?? 'SENDPROCOLIS',
      body: body ?? '',
      payload: message.data['trackingNumber']?.toString(),
    ));
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    // TODO: brancher la navigation (ex: ouvrir le détail du colis via
    // message.data['trackingNumber'] / message.data['parcelId']).
    debugPrint(
        'PushNotificationService: notification ouverte, data=${message.data}');
  }

  /// Récupère le token FCM courant et l'envoie au backend.
  /// À appeler quand l'utilisateur est authentifié (après login / au
  /// démarrage avec une session existante). Échoue silencieusement.
  static Future<void> registerTokenWithBackend() async {
    if (!_firebaseReady) return;
    try {
      _currentToken ??= await FirebaseMessaging.instance.getToken();
      final String? token = _currentToken;
      if (token == null || token.isEmpty) return;
      await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('PushNotificationService: getToken impossible: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      await _api.registerDeviceToken(token);
    } catch (_) {
      // Endpoint peut-être pas encore disponible côté serveur : silencieux.
    }
  }
}
