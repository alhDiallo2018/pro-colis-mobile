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

  @override
  String get manifestTitle => 'Lëpp lu navette bi yor';

  @override
  String get manifestStopsCount => 'Taxawaay yi';

  @override
  String get manifestOffersCount => 'Mbind yi';

  @override
  String get manifestPicked => 'Yëf yu nar a yónnee';

  @override
  String get manifestDropOffs => 'Yëf yu nar a jox';

  @override
  String get manifestEmpty => 'Amul mbind lu tax ci yoon wii leegi.';

  @override
  String manifestUnassigned(int count) {
    return 'Mbind yu amul taxawaay ($count)';
  }

  @override
  String get reachedStopsTitle => 'Taxawaay yi am';

  @override
  String get reachedStopsEmpty => 'Benn taxawaay amul ci yoon wii leegi.';

  @override
  String get reachedStopsLoadFailed => 'Mënuma tudd';

  @override
  String get optimizeRouteTitle => 'Yoon wu yombalu';

  @override
  String get optimizeRouteEmpty => 'Amul mbind lu nar a toppatoo.';

  @override
  String get optimizeRouteDistance => 'Rëyaay';

  @override
  String get optimizeRouteImprovement => 'Njariñ 2-opt';

  @override
  String get optimizeRouteSteps => 'Yoon yi';

  @override
  String get handoverInitiateTitle => 'Yóbbu bees bu bees';

  @override
  String get handoverInitiateExplain =>
      'Jox mbind mii beneen awtokat. Dañu nar a génne PIN ak QR : wonal ko awtokat bu dikk ba nga mën a wax ni lu baax.';

  @override
  String get handoverInitiateDriverFieldLabel => 'ID awtokat bu dikk';

  @override
  String get handoverInitiateDriverFieldHelper => 'UUID awtokat bi';

  @override
  String get handoverInitiateSubmit => 'Génne PIN ak QR';

  @override
  String get handoverInitiateWarning =>
      'Kod yii du bu yëg beneen yoon. Jox leen awtokat bu dikk léegi.';

  @override
  String get handoverPinLabel => 'Kod PIN';

  @override
  String get handoverQrLabel => 'QR (won ko walla yónnee ko)';

  @override
  String get handoverCopy => 'Nangu ci';

  @override
  String get handoverDone => 'Jëkk';

  @override
  String get handoverConfirmTitle => 'Wax ni yóbbu bi baax na';

  @override
  String get handoverConfirmExplain =>
      'Ñaawal lu awtokat bu génn wax la ndax nga nangu mbind mii.';

  @override
  String get handoverConfirmIdLabel => 'ID yóbbu bi';

  @override
  String get handoverConfirmPinLabel => 'PIN (6 lëmb)';

  @override
  String get handoverConfirmQrLabel => 'QR';

  @override
  String get handoverConfirmQrHelper => 'Scanne walla toggal QR bi';

  @override
  String get handoverConfirmScanTooltip => 'Scanne QR bi';

  @override
  String get handoverConfirmSubmit => 'Wax ni nangu nga ko';

  @override
  String get handoverConfirmSuccess => 'Yóbbu baax na';

  @override
  String get handoverConfirmSuccessBody =>
      'Mbind mii nekk na sa boor leegi. Topp jaloore bi.';

  @override
  String get shipmentBatchesTitle => 'Sama mbooleem yónnent';

  @override
  String get shipmentBatchesEmpty => 'Amul mbooloo leegi.';

  @override
  String get shipmentBatchesCreate => 'Mbooloo bees';

  @override
  String shipmentBatchParcelCount(int count) {
    return '$count mbind';
  }

  @override
  String get shipmentBatchDetailTitle => 'Ñaw mbooloo bi';

  @override
  String get shipmentBatchAttach => 'Boole ab mbind';

  @override
  String get shipmentBatchClose => 'Tëjl';

  @override
  String shipmentBatchParcelsHeader(int count) {
    return 'Mbind yu nekk ci mbooloo ($count)';
  }
}
