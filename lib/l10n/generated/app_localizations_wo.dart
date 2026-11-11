// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Wolof (`wo`).
class AppLocalizationsWo extends AppLocalizations {
  AppLocalizationsWo([String locale = 'wo']) : super(locale);

  @override
  String get brandName => 'SendProColis';

  @override
  String get navHome => 'Kër';

  @override
  String get navSend => 'Yónnee';

  @override
  String get navTrack => 'Toppatoo';

  @override
  String get navProfile => 'Sama xabaar';

  @override
  String trackingEtaLive(int minutes, int min, int max) {
    return 'Dina agsi ci ~$minutes simili ($min–$max)';
  }

  @override
  String get trackingEtaArriving => 'Dina agsi léegi';

  @override
  String get trackingDriverStopped => 'Awtokat bi dafa taxaw';

  @override
  String get trackingPositionStale => 'Barab bu yagg';

  @override
  String get trackingAnomalyTitle => 'Xoolal yoonu mbindum bi';

  @override
  String get trackingAnomalyCritical => 'Yëngu-yëngu ci yoon wi';

  @override
  String get ocrScanLabel => 'Scanne palanka bi';

  @override
  String get ocrNoFieldsDetected => 'Benn làkk dañu gis.';

  @override
  String get ocrPreviewTitle => 'Dëgg yi feeñ';

  @override
  String get ocrPreviewHint => 'Toppatoo bi la masu jëfandikoo.';

  @override
  String get ocrActionUse => 'Jëfandikoo';

  @override
  String get ocrActionCancel => 'Bañ';

  @override
  String get aiAssistantTitle => 'Jàngalekat';

  @override
  String get aiAssistantHint => 'Wax nga sa yónnent…';

  @override
  String get aiAssistantFillForm => 'Def ko ci formulaire bi';

  @override
  String get promiseSlotMorning => 'Suba';

  @override
  String get promiseSlotAfternoon => 'Bëccëg';

  @override
  String get promiseSlotEvening => 'Ngoon';

  @override
  String get errorNetwork => 'Internet jàll';

  @override
  String get errorRetry => 'Jéemaat';
}
