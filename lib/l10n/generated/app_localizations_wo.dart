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

  @override
  String get insuranceSheetTitle => 'Aarool mbind mii';

  @override
  String get insuranceSheetSubtitle =>
      'Xamle njëg lu nekk ci mbind mi ngir am devis assurance.';

  @override
  String get insuranceDeclaredValueLabel => 'Njëg lu xamle (FCFA)';

  @override
  String get insuranceCrossBorderToggle =>
      'Yónnent ci biir dëkk yu ñu wuute (+15%)';

  @override
  String get insuranceQuoteCta => 'Jël devis bi';

  @override
  String get insuranceConfirmCta => 'Dëgël';

  @override
  String insuranceSubscribedSnack(int amount) {
    return 'Mbind aaraa na — njëgam $amount FCFA.';
  }

  @override
  String get internationalEstimateTitle => 'Jéem yónnent bu biir réew yi';

  @override
  String get internationalEstimateCurrency => 'Xaalis';

  @override
  String get internationalEstimateDeclareValue =>
      'Xamle njëg (CN22/CN23 soxla)';

  @override
  String get internationalEstimateCta => 'Jël devis bi';

  @override
  String get backupsTitle => 'Denkaane yi';

  @override
  String get backupsEmptyMessage =>
      'Jëfandikoo bitóng « Denkaane bees » ngir sos benn.';

  @override
  String get backupsNewDumpCta => 'Denkaane bees';

  @override
  String get backupsDownloadCta => 'Télécharger';

  @override
  String get backupsRestoreCta => 'Delloo';

  @override
  String get backupsRestoreConfirmTitle =>
      'Ndax nga bëgg delloo denkaane bii ?';

  @override
  String get notificationsDeleteAllCta => 'Fort lépp';

  @override
  String get notificationsDeleteAllConfirm =>
      'Sa notification yi yépp dañu nar a far. Jëf jii du mën a soppi.';

  @override
  String get logoutAllCta => 'Génn ci jumtukaay yépp';

  @override
  String get logoutAllConfirmBody =>
      'Sa session yépp dañu nar a tëj, moom itam ci sa jumtukaay yu ci des. Soxla nga duggaat fu nekk.';

  @override
  String get scoreRefundCta => 'Delloo puwaañ yi';

  @override
  String get scoreRefundReasonLabel => 'Lu tax';

  @override
  String get supportTransferCta => 'Yóbbu';

  @override
  String get supportTransferSelectAgent => 'Yóbbu ci';

  @override
  String get leadCreateTitle => 'Prospect bees';

  @override
  String get leadNameLabel => 'Tur *';

  @override
  String get ticketEditTitle => 'Soppi ticket bi';

  @override
  String get incidentEditTitle => 'Soppi incident bi';

  @override
  String get parcelEventsTitle => 'Xew-xew yu mbind mi';

  @override
  String get parcelTemplatesTitle => 'Sama modèle mbind';

  @override
  String get parcelTemplatesEmpty => 'Amul modèle bu bind.';

  @override
  String get parcelTemplatesSaveCta => 'Denc';

  @override
  String get csvImportTitle => 'Boole yóbbu CSV';

  @override
  String get csvImportPickFile => 'Tànn benn fichier';

  @override
  String csvImportRunning(int done, int total) {
    return 'Yóbbu di jàll… $done/$total';
  }

  @override
  String get experienceLoadFailed => 'Récap bi amul. Jéemal ak internet.';

  @override
  String get experienceOverdueNotice =>
      'Waxtu jaloore bi weesu na. Jokkoo ak awtokat bi.';

  @override
  String experienceLastPositionFresh(String timestamp) {
    return 'Barab mu mujj : $timestamp. Barab mu bees.';
  }

  @override
  String experienceLastPositionStale(String timestamp) {
    return 'Barab mu mujj : $timestamp. Barab mu yagg, oto bi mën na soppeeku.';
  }

  @override
  String get experienceFinanceTitle => 'Récapitulatif xaalis';

  @override
  String get experienceAgreedPrice => 'Njëg la wax';

  @override
  String get experiencePaymentsConfirmed => 'Pajeman yi dëgër';

  @override
  String get experienceCommissionEstimated => 'Komisyon (xayma)';

  @override
  String get experienceCommissionRecorded => 'Komisyon (bind)';

  @override
  String get experienceNetAfterCommissionEstimated =>
      'Net ginnaaw komisyon (xayma)';

  @override
  String get experienceNetAfterCommission => 'Net ginnaaw komisyon';

  @override
  String get experienceCommissionPaid => 'Komisyon bi fay';

  @override
  String get experienceDebtCreated => 'Bor bu yor ci mbind mii';

  @override
  String get experienceAccountCommissionDebt => 'Bor bu kompt bi yor fii';

  @override
  String get experienceParcelPenaltyDue => 'Amandas yu desu fay';

  @override
  String experienceShareReceipt(String amount) {
    return 'Séddele reçu bu $amount';
  }

  @override
  String get experienceReportIssue => 'Tàggat benn jafe-jafe';

  @override
  String get experienceContactSupport => 'Waxtaan ak support bi';

  @override
  String get experienceSendSimilar => 'Yónnee mbind mu niroo';

  @override
  String experienceFollowComplaint(String subject, String status) {
    return '$subject — $status\nToppatoo réclamation bi';
  }

  @override
  String get complaintReasonLabel => 'Lu tax';

  @override
  String get complaintReasonDelay => 'Yeex';

  @override
  String get complaintReasonDamage => 'Mbind mu yàqu';

  @override
  String get complaintReasonMissing => 'Mbind mu réer';

  @override
  String get complaintReasonPayment => 'Pajeman';

  @override
  String get complaintReasonOther => 'Beneen jafe-jafe';

  @override
  String get complaintMessageLabel => 'Bind jafe-jafe bi';

  @override
  String get complaintMessageValidator =>
      'Bind jafe-jafe bi ci 10 araf lu jëkk.';

  @override
  String complaintPhotoAttached(int index) {
    return 'Nataal $index ci la boole';
  }

  @override
  String get complaintRemovePhoto => 'Dindi nataal bi';

  @override
  String complaintAddPhoto(int count) {
    return 'Yokk ab nataal ($count/4)';
  }

  @override
  String get complaintSending => 'Di yónnee…';

  @override
  String get complaintSubmit => 'Yónnee réclamation bi';

  @override
  String get complaintPhotoError => 'Nataal bi dañu ko yónneewul. Jéemal.';

  @override
  String get complaintSubmitError =>
      'Réclamation bi dëgëlul. Lu nga bind dencu na ; jéemal.';

  @override
  String get helpGuideLanguageLabel => 'Làkk bu ndigël yi';

  @override
  String get helpGuideLangFr => 'Farañse';

  @override
  String get helpGuideLangWo => 'Wolof';

  @override
  String get helpGuidePlay => 'Dégg';

  @override
  String get helpGuideStop => 'Taxaw';

  @override
  String get helpGuideAudioError => 'Dégg bi amul. Bind bi mën nga ko jàng.';

  @override
  String get helpGuideNoneAvailableFr => 'Ndigël yi ci farañse amagul.';

  @override
  String get helpGuideNoneAvailableWo => 'Ndigël yi ci wolof amagul.';

  @override
  String get helpGuideContactSupport => 'Ñaan ndimbal ci support bi';

  @override
  String get qualityScreenTitle => 'Qualité liggéey bi';

  @override
  String get qualityScreenHeader =>
      'Indicateurs ci 30 fan yu mujj. Yeex yi jëfandikoo nañu xayma jaloore yi bind.';

  @override
  String get qualityScreenError => 'Indicateurs du am léegi.';

  @override
  String get qualityScreenRefresh => 'Yeesalaat';

  @override
  String get qualityParcelsCreated => 'Mbind yi ñu bind';

  @override
  String get qualityParcelsDelivered => 'Mbind yi ñu jaloore';

  @override
  String get qualityDeliveriesOverdue => 'Jaloore yu yeex';

  @override
  String get qualityPaymentsFailed => 'Pajeman yi dañu failé';

  @override
  String get qualityCreationsStarted => 'Bind yi ñu tambali';

  @override
  String get qualityCreationsAbandoned => 'Bind yu bàyyi ginnaaw 24 waxtu';

  @override
  String get qualityFirstResponse => 'Jëkkal tontu bu support';

  @override
  String get qualityNotYetMeasured => 'Amul xayma leegi';

  @override
  String qualityMinutes(int minutes) {
    return '$minutes simili';
  }

  @override
  String qualityFooter(String sample) {
    return 'Bind yu bàyyi : formulaires yu bind te ñu dëgëluwul ginnaaw 24 waxtu. Yeex bu support bi ñu xayma ci $sample waxtaan yu am tontu.';
  }

  @override
  String get kycDeleteCta => 'Far';

  @override
  String get kycDeleteConfirmTitle => 'Ndax da nga bëgg far KYC bii ?';

  @override
  String get kycDeleteConfirmBody =>
      'Dokimaa yi ak historique dañu nar far ba fàww.';

  @override
  String get kycRequestInfoCta => 'Ñaan xibaar bu gën';

  @override
  String get kycRequestInfoTitle => 'Ñaan xibaar bu bees';

  @override
  String get kycRequestInfoMessageLabel => 'Bataaxal bu jëfandikoo bi';

  @override
  String get kycRequestInfoSubmit => 'Yónnee ñaan bi';

  @override
  String get supportCloseCta => 'Tëjl';

  @override
  String get supportCloseTitle => 'Tëjl waxtaan bi';

  @override
  String get supportCloseCategoryLabel => 'Kategori';

  @override
  String get supportCloseCategoryResolved => 'Jëpp';

  @override
  String get supportCloseCategoryDuplicate => 'Ñaari yoon';

  @override
  String get supportCloseCategorySpam => 'Spam';

  @override
  String get supportCloseCategoryNoAnswer => 'Amul tontu';

  @override
  String get supportCloseReasonLabel => 'Lu tax ba nga tëjl';

  @override
  String get supportCloseReasonValidator => 'Wax lu tax (5 araf lu jëkk).';

  @override
  String get supportCloseSubmit => 'Tëjl';

  @override
  String get aiAssistantOpenCta => 'Jàngalekat IA';

  @override
  String get aiAssistantPrefilledSnack =>
      'Formulaire bi mu xam na ak jàngalekat bi.';

  @override
  String get aiAssistantVoiceRecord => 'Wax';

  @override
  String get aiAssistantVoiceRecording => 'Di bind…';

  @override
  String get aiAssistantVoiceStop => 'Taxaw';

  @override
  String get aiAssistantVoiceTranscribing => 'Di tekki…';

  @override
  String get aiAssistantVoiceUnavailable => 'Tekki baat amul. Bindal sa ñaan.';

  @override
  String get aiAssistantVoicePermission =>
      'Jox ndigël microphone ci reglaas yi ngir mën wax.';

  @override
  String get batchStopEventsTitle => 'Xew-xew yu yoon wi';

  @override
  String get batchStopEventsEmpty => 'Amul xew-xew ci mbooloo mii.';

  @override
  String get invoicesSectionTitle => 'Facture yi';

  @override
  String get invoicesEmpty => 'Amul facture leegi.';

  @override
  String get invoicesDownloadCta => 'Télécharger';

  @override
  String get invoicesViewAllCta => 'Xool facture yépp';

  @override
  String invoicesIssuedOn(String date) {
    return 'Génne ci $date';
  }

  @override
  String get disputesTitle => 'Sama kontanaas yi';

  @override
  String get disputesEmpty => 'Amul kontanaas leegi.';

  @override
  String get disputesOpenCta => 'Ubbi kontanaas';

  @override
  String get disputesStatusOpen => 'Ubbi';

  @override
  String get disputesStatusInReview => 'Ñu ngi xool';

  @override
  String get disputesStatusResolved => 'Jëpp';

  @override
  String get disputesStatusRejected => 'Bañ';

  @override
  String get disputesCategoryDamage => 'Mbind mu yàqu';

  @override
  String get disputesCategoryLost => 'Mbind mu réer';

  @override
  String get disputesCategoryDelay => 'Yeex gu réew';

  @override
  String get disputesCategoryPayment => 'Jafe-jafe pajeman';

  @override
  String get disputesCategoryOther => 'Beneen';

  @override
  String get disputesNewTitle => 'Kontanaas bu bees';

  @override
  String get disputesCategoryLabel => 'Kategori';

  @override
  String get disputesSubjectLabel => 'Jamono (du soxla)';

  @override
  String get disputesDescriptionLabel => 'Bind jafe-jafe bi';

  @override
  String get disputesDescriptionValidator =>
      'Bind jafe-jafe bi ci 20 araf lu jëkk.';

  @override
  String get disputesClaimedAmountLabel => 'Njëg li ñu laaj (du soxla)';

  @override
  String get disputesSubmit => 'Yónnee kontanaas bi';

  @override
  String get disputesSubmitting => 'Di yónnee…';

  @override
  String get disputesSubmitError =>
      'Kontanaas bi yónneewul. Xoolal internet bi te jéemaat.';

  @override
  String get disputesDetailTitle => 'Ñaw kontanaas bi';

  @override
  String get disputesCommentLabel => 'Yokk ab waxtaan';

  @override
  String get disputesCommentSend => 'Yónnee';

  @override
  String get disputesResolutionNote => 'Bataaxal li jëpp';

  @override
  String get disputesEventsTitle => 'Taariix bi';

  @override
  String get disputesParcelLink => 'Xool mbind mi';
}
