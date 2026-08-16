import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'api_service.dart';
import 'notification_badge_service.dart';

/// Transforme les données d'une notification push en une navigation réelle.
///
/// Chaque notification transporte un `type` et, selon le cas, un `parcelId` /
/// `advertisementId` / `notificationId`. Le tap ouvre directement la page
/// métier correspondante (détail colis, annonce, messages…) plutôt que le
/// simple écran d'accueil, et marque la notification comme lue côté backend.
class NotificationNavigation {
  NotificationNavigation._();

  /// Gère le tap sur une notification (foreground, background ou démarrage).
  ///
  /// [data] contient les clés FCM : `type`, `notificationId`, `parcelId`,
  /// `trackingNumber`, `advertisementId`, etc.
  static void handle(Map<String, String> data, GoRouter router) {
    final notificationId = data['notificationId'] ?? data['notification_id'];
    final type = data['type'] ?? '';
    final parcelId = data['parcelId'] ?? data['parcel_id'];
    final advertisementId =
        data['advertisementId'] ?? data['advertisement_id'];
    final route = _routeFor(type, parcelId, advertisementId);

    debugPrint(
      'NotificationNavigation: tap type=$type parcelId=$parcelId '
      'route=$route',
    );

    // Marque la notification comme lue sans bloquer la navigation.
    if (notificationId != null && notificationId.isNotEmpty) {
      unawaited(_markRead(notificationId));
    }

    // La route a pu être résolue : navigation immédiate.
    if (route != null) {
      try {
        router.push(route);
        return;
      } catch (e) {
        debugPrint('NotificationNavigation: navigation impossible: $e');
      }
    }

    // Repli : écran des notifications.
    try {
      router.push('/notifications');
    } catch (_) {}
  }

  static Future<void> _markRead(String notificationId) async {
    try {
      await ApiService().markNotificationAsRead(notificationId);
    } catch (_) {
      // L'ouverture de la notification depuis le centre de notifications
      // marquera l'élément lu à la prochaine synchronisation.
    }
    await NotificationBadgeService.refresh();
  }

  /// Détermine la destination depuis le type et les identifiants.
  static String? _routeFor(
    String type,
    String? parcelId,
    String? advertisementId,
  ) {
    final normalized = type.toLowerCase();

    if (parcelId != null && parcelId.isNotEmpty) {
      return '/parcel/${Uri.encodeComponent(parcelId)}';
    }

    if (advertisementId != null && advertisementId.isNotEmpty) {
      return '/advertisement/${Uri.encodeComponent(advertisementId)}';
    }

    if (normalized.contains('message')) return '/messages';

    if (normalized.contains('payment') ||
        normalized.contains('wallet') ||
        normalized.contains('commission') ||
        normalized.contains('withdrawal') ||
        normalized.contains('deposit') ||
        normalized.contains('refund')) {
      return '/wallet';
    }

    if (normalized.contains('bid') ||
        normalized.contains('offer') ||
        normalized.contains('proposition')) {
      return '/client/offres';
    }

    if (normalized.contains('support')) return '/support';

    return null;
  }
}
