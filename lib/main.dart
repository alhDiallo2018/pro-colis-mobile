import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await NotificationService.initialize();
  // Push FCM : dégrade proprement si les fichiers de config Firebase
  // (google-services.json / GoogleService-Info.plist) sont absents.
  await PushNotificationService.initialize();
  runApp(const ProviderScope(child: ProColisApp()));
}
