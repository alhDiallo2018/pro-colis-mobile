import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:procolis/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'initialize' ? true : null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('transmet le logo au système avec l’aperçu et la destination du message',
      () async {
    await NotificationService.initialize();
    await NotificationService.showNotification(
      id: 42,
      title: 'Nouveau message',
      body: 'Votre colis est arrivé',
      data: {'type': 'message', 'senderId': 'expediteur'},
    );

    // Vérifier la frontière native : un widget de l'app ne permet pas de
    // contrôler l'icône réellement demandée au tiroir de notifications Android.
    final initialization =
        calls.singleWhere((call) => call.method == 'initialize');
    expect(initialization.arguments['defaultIcon'], 'ic_stat_sendprocolis');
    final shown = calls.singleWhere((call) => call.method == 'show').arguments;
    expect(shown['body'], 'Votre colis est arrivé');
    expect(shown['platformSpecifics']['icon'], 'ic_stat_sendprocolis');
    expect(shown['platformSpecifics'], containsPair('colorAlpha', 255));
    expect(shown['platformSpecifics'], containsPair('colorRed', 1));
    expect(shown['platformSpecifics'], containsPair('colorGreen', 137));
    expect(shown['platformSpecifics'], containsPair('colorBlue', 130));
    expect(jsonDecode(shown['payload'] as String), {
      'type': 'message',
      'senderId': 'expediteur',
    });
  });
}
