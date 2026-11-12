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

  @override
  String get manifestTitle => 'Shuttle manifest';

  @override
  String get manifestStopsCount => 'Stops';

  @override
  String get manifestOffersCount => 'Parcels';

  @override
  String get manifestPicked => 'To pick up';

  @override
  String get manifestDropOffs => 'To hand over';

  @override
  String get manifestEmpty => 'No parcels assigned to this trip yet.';

  @override
  String manifestUnassigned(int count) {
    return 'Parcels without assigned stop ($count)';
  }

  @override
  String get reachedStopsTitle => 'Reached stops';

  @override
  String get reachedStopsEmpty => 'No stops reached on this trip yet.';

  @override
  String get reachedStopsLoadFailed => 'Unable to load';

  @override
  String get optimizeRouteTitle => 'Optimised tour';

  @override
  String get optimizeRouteEmpty => 'No parcels to sort.';

  @override
  String get optimizeRouteDistance => 'Distance';

  @override
  String get optimizeRouteImprovement => '2-opt gain';

  @override
  String get optimizeRouteSteps => 'Steps';

  @override
  String get handoverInitiateTitle => 'New handover';

  @override
  String get handoverInitiateExplain =>
      'Transfer this parcel to another driver. A PIN and a QR code will be generated: show them to the incoming driver to validate the handover.';

  @override
  String get handoverInitiateDriverFieldLabel => 'Incoming driver ID';

  @override
  String get handoverInitiateDriverFieldHelper => 'Target driver UUID';

  @override
  String get handoverInitiateSubmit => 'Generate PIN + QR';

  @override
  String get handoverInitiateWarning =>
      'These codes will not be shown again. Share them immediately with the incoming driver.';

  @override
  String get handoverPinLabel => 'PIN code';

  @override
  String get handoverQrLabel => 'QR token (show or share)';

  @override
  String get handoverCopy => 'Copy';

  @override
  String get handoverDone => 'Done';

  @override
  String get handoverConfirmTitle => 'Confirm a handover';

  @override
  String get handoverConfirmExplain =>
      'Enter the information provided by the outgoing driver to take over this parcel.';

  @override
  String get handoverConfirmIdLabel => 'Handover ID';

  @override
  String get handoverConfirmPinLabel => 'PIN (6 digits)';

  @override
  String get handoverConfirmQrLabel => 'QR token';

  @override
  String get handoverConfirmQrHelper => 'Scan or paste the received token';

  @override
  String get handoverConfirmScanTooltip => 'Scan the QR';

  @override
  String get handoverConfirmSubmit => 'Confirm pickup';

  @override
  String get handoverConfirmSuccess => 'Handover confirmed';

  @override
  String get handoverConfirmSuccessBody =>
      'This parcel is now assigned to you. Continue the delivery.';

  @override
  String get shipmentBatchesTitle => 'My shipment batches';

  @override
  String get shipmentBatchesEmpty => 'No batches yet.';

  @override
  String get shipmentBatchesCreate => 'New batch';

  @override
  String shipmentBatchParcelCount(int count) {
    return '$count parcels';
  }

  @override
  String get shipmentBatchDetailTitle => 'Batch details';

  @override
  String get shipmentBatchAttach => 'Attach a parcel';

  @override
  String get shipmentBatchClose => 'Close';

  @override
  String shipmentBatchParcelsHeader(int count) {
    return 'Parcels in batch ($count)';
  }

  @override
  String get insuranceSheetTitle => 'Insure this parcel';

  @override
  String get insuranceSheetSubtitle =>
      'Declare the contents\' value to get an instant insurance quote.';

  @override
  String get insuranceDeclaredValueLabel => 'Declared value (XOF)';

  @override
  String get insuranceCrossBorderToggle =>
      'Cross-border shipment (+15% premium)';

  @override
  String get insuranceQuoteCta => 'Get a quote';

  @override
  String get insuranceConfirmCta => 'Confirm';

  @override
  String insuranceSubscribedSnack(int amount) {
    return 'Parcel insured — premium $amount XOF.';
  }

  @override
  String get internationalEstimateTitle => 'Simulate an international shipment';

  @override
  String get internationalEstimateCurrency => 'Currency';

  @override
  String get internationalEstimateDeclareValue =>
      'Declare value (CN22/CN23 required)';

  @override
  String get internationalEstimateCta => 'Get a quote';

  @override
  String get backupsTitle => 'Backups';

  @override
  String get backupsEmptyMessage =>
      'Use the \"New dump\" button to create one.';

  @override
  String get backupsNewDumpCta => 'New dump';

  @override
  String get backupsDownloadCta => 'Download';

  @override
  String get backupsRestoreCta => 'Restore';

  @override
  String get backupsRestoreConfirmTitle => 'Restore this backup?';

  @override
  String get notificationsDeleteAllCta => 'Clear all';

  @override
  String get notificationsDeleteAllConfirm =>
      'All your notifications will be deleted. This action cannot be undone.';

  @override
  String get logoutAllCta => 'Sign out all devices';

  @override
  String get logoutAllConfirmBody =>
      'All your sessions will end, including on other devices. You will need to sign in again everywhere.';

  @override
  String get scoreRefundCta => 'Refund points';

  @override
  String get scoreRefundReasonLabel => 'Reason';

  @override
  String get supportTransferCta => 'Transfer';

  @override
  String get supportTransferSelectAgent => 'Transfer to';

  @override
  String get leadCreateTitle => 'New lead';

  @override
  String get leadNameLabel => 'Name *';

  @override
  String get ticketEditTitle => 'Edit ticket';

  @override
  String get incidentEditTitle => 'Edit incident';

  @override
  String get parcelEventsTitle => 'Parcel events';

  @override
  String get parcelTemplatesTitle => 'My parcel templates';

  @override
  String get parcelTemplatesEmpty => 'No templates saved.';

  @override
  String get parcelTemplatesSaveCta => 'Save';

  @override
  String get csvImportTitle => 'Bulk CSV import';

  @override
  String get csvImportPickFile => 'Choose a file';

  @override
  String csvImportRunning(int done, int total) {
    return 'Importing… $done/$total';
  }
}
