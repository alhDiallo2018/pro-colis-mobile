// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get brandName => 'SendProColis';

  @override
  String get navHome => 'Home';

  @override
  String get navSend => 'Send';

  @override
  String get navTrack => 'Track';

  @override
  String get navProfile => 'Profile';

  @override
  String trackingEtaLive(int minutes, int min, int max) {
    return 'Arrives in ~$minutes min ($min–$max)';
  }

  @override
  String get trackingEtaArriving => 'Arriving soon';

  @override
  String get trackingDriverStopped => 'Driver stopped';

  @override
  String get trackingPositionStale => 'Stale position';

  @override
  String get trackingAnomalyTitle => 'Trajectory check recommended';

  @override
  String get trackingAnomalyCritical => 'Trajectory alert';

  @override
  String get ocrScanLabel => 'Scan a label';

  @override
  String get ocrNoFieldsDetected => 'No readable text detected.';

  @override
  String get ocrPreviewTitle => 'Detected fields';

  @override
  String get ocrPreviewHint => 'Review before applying.';

  @override
  String get ocrActionUse => 'Apply';

  @override
  String get ocrActionCancel => 'Cancel';

  @override
  String get aiAssistantTitle => 'Assistant';

  @override
  String get aiAssistantHint => 'Describe your shipment…';

  @override
  String get aiAssistantFillForm => 'Fill the form with these details';

  @override
  String get promiseSlotMorning => 'Morning';

  @override
  String get promiseSlotAfternoon => 'Afternoon';

  @override
  String get promiseSlotEvening => 'Evening';

  @override
  String get errorNetwork => 'Connection lost';

  @override
  String get errorRetry => 'Retry';
}
