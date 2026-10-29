import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Un flux natif maintient le GPS lorsque l'écran se verrouille. Un simple
/// Timer Dart ne suffit pas : Android et iOS suspendent les tâches ordinaires.
LocationSettings backgroundLocationSettings({
  required String title,
  required String text,
  Duration interval = const Duration(seconds: 10),
}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: interval,
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: title,
        notificationText: text,
        notificationChannelName: 'Partage de position ProColis',
        notificationIcon: const AndroidResource(name: 'ic_stat_sendprocolis'),
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      activityType: ActivityType.automotiveNavigation,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  }
  return const LocationSettings(
      accuracy: LocationAccuracy.high, distanceFilter: 0);
}

bool isRecentPosition(Position position, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(position.timestamp);
  return age >= const Duration(seconds: -5) &&
      age <= const Duration(seconds: 60);
}
