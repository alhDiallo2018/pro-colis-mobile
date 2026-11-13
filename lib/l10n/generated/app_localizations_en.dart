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

  @override
  String get experienceLoadFailed =>
      'Summary unavailable. Try again with a connection.';

  @override
  String get experienceOverdueNotice =>
      'The estimated delivery time has passed. Contact the driver for an update.';

  @override
  String experienceLastPositionFresh(String timestamp) {
    return 'Last position: $timestamp. Recent position.';
  }

  @override
  String experienceLastPositionStale(String timestamp) {
    return 'Last position: $timestamp. Old position, the vehicle may have moved.';
  }

  @override
  String get experienceFinanceTitle => 'Financial summary';

  @override
  String get experienceAgreedPrice => 'Agreed price';

  @override
  String get experiencePaymentsConfirmed => 'Confirmed payments';

  @override
  String get experienceCommissionEstimated => 'Commission (estimate)';

  @override
  String get experienceCommissionRecorded => 'Commission (recorded)';

  @override
  String get experienceNetAfterCommissionEstimated =>
      'Net after commission (estimate)';

  @override
  String get experienceNetAfterCommission => 'Net after commission';

  @override
  String get experienceCommissionPaid => 'Commission paid';

  @override
  String get experienceDebtCreated => 'Debt created on this parcel';

  @override
  String get experienceAccountCommissionDebt => 'Current account debt';

  @override
  String get experienceParcelPenaltyDue => 'Penalties remaining to pay';

  @override
  String experienceShareReceipt(String amount) {
    return 'Share the receipt for $amount';
  }

  @override
  String get experienceReportIssue => 'Report an issue';

  @override
  String get experienceContactSupport => 'Talk to support';

  @override
  String get experienceSendSimilar => 'Send a similar parcel';

  @override
  String experienceFollowComplaint(String subject, String status) {
    return '$subject — $status\nFollow this complaint';
  }

  @override
  String get complaintReasonLabel => 'Reason';

  @override
  String get complaintReasonDelay => 'Delay';

  @override
  String get complaintReasonDamage => 'Damaged parcel';

  @override
  String get complaintReasonMissing => 'Missing parcel';

  @override
  String get complaintReasonPayment => 'Payment';

  @override
  String get complaintReasonOther => 'Other issue';

  @override
  String get complaintMessageLabel => 'Describe the issue';

  @override
  String get complaintMessageValidator =>
      'Describe the issue in at least 10 characters.';

  @override
  String complaintPhotoAttached(int index) {
    return 'Photo $index attached';
  }

  @override
  String get complaintRemovePhoto => 'Remove photo';

  @override
  String complaintAddPhoto(int count) {
    return 'Add a photo ($count/4)';
  }

  @override
  String get complaintSending => 'Sending…';

  @override
  String get complaintSubmit => 'Submit the complaint';

  @override
  String get complaintPhotoError => 'Photo not sent. Try again.';

  @override
  String get complaintSubmitError =>
      'Complaint not confirmed. Your input is kept; try again.';

  @override
  String get helpGuideLanguageLabel => 'Guide language';

  @override
  String get helpGuideLangFr => 'French';

  @override
  String get helpGuideLangWo => 'Wolof';

  @override
  String get helpGuidePlay => 'Listen';

  @override
  String get helpGuideStop => 'Stop';

  @override
  String get helpGuideAudioError =>
      'Playback unavailable. The text is still accessible.';

  @override
  String get helpGuideNoneAvailableFr =>
      'Guides in French are not yet available.';

  @override
  String get helpGuideNoneAvailableWo =>
      'Guides in Wolof are not yet available.';

  @override
  String get helpGuideContactSupport => 'Ask support for help';

  @override
  String get qualityScreenTitle => 'Service quality';

  @override
  String get qualityScreenHeader =>
      'Metrics for the past 30 days. Delays use recorded delivery estimates.';

  @override
  String get qualityScreenError => 'Metrics temporarily unavailable.';

  @override
  String get qualityScreenRefresh => 'Refresh';

  @override
  String get qualityParcelsCreated => 'Parcels created';

  @override
  String get qualityParcelsDelivered => 'Parcels delivered';

  @override
  String get qualityDeliveriesOverdue => 'Overdue deliveries';

  @override
  String get qualityPaymentsFailed => 'Failed payments';

  @override
  String get qualityCreationsStarted => 'Creations started';

  @override
  String get qualityCreationsAbandoned => 'Presumed abandoned after 24h';

  @override
  String get qualityFirstResponse => 'Support first response';

  @override
  String get qualityNotYetMeasured => 'No measurement yet';

  @override
  String qualityMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String qualityFooter(String sample) {
    return 'Presumed abandons: instrumented forms without a confirmed creation after 24h. Support delay computed on $sample conversation(s) with a recorded reply.';
  }

  @override
  String get kycDeleteCta => 'Delete';

  @override
  String get kycDeleteConfirmTitle => 'Delete this verification?';

  @override
  String get kycDeleteConfirmBody =>
      'Documents and verification history will be permanently removed.';

  @override
  String get kycRequestInfoCta => 'Request more info';

  @override
  String get kycRequestInfoTitle => 'Request additional information';

  @override
  String get kycRequestInfoMessageLabel => 'Message for the user';

  @override
  String get kycRequestInfoSubmit => 'Send request';

  @override
  String get supportCloseCta => 'Close';

  @override
  String get supportCloseTitle => 'Close the conversation';

  @override
  String get supportCloseCategoryLabel => 'Category';

  @override
  String get supportCloseCategoryResolved => 'Resolved';

  @override
  String get supportCloseCategoryDuplicate => 'Duplicate';

  @override
  String get supportCloseCategorySpam => 'Spam';

  @override
  String get supportCloseCategoryNoAnswer => 'No answer';

  @override
  String get supportCloseReasonLabel => 'Close reason';

  @override
  String get supportCloseReasonValidator =>
      'Provide a reason (min. 5 characters).';

  @override
  String get supportCloseSubmit => 'Close';

  @override
  String get aiAssistantOpenCta => 'AI Assistant';

  @override
  String get aiAssistantPrefilledSnack => 'Form prefilled from the assistant.';

  @override
  String get aiAssistantVoiceRecord => 'Dictate';

  @override
  String get aiAssistantVoiceRecording => 'Recording…';

  @override
  String get aiAssistantVoiceStop => 'Stop';

  @override
  String get aiAssistantVoiceTranscribing => 'Transcribing…';

  @override
  String get aiAssistantVoiceUnavailable =>
      'Voice transcription unavailable. Please type your request.';

  @override
  String get aiAssistantVoicePermission =>
      'Allow microphone access in settings to dictate.';

  @override
  String get batchStopEventsTitle => 'Trip events';

  @override
  String get batchStopEventsEmpty => 'No events recorded for this batch.';

  @override
  String get invoicesSectionTitle => 'Invoices';

  @override
  String get invoicesEmpty => 'No invoices available.';

  @override
  String get invoicesDownloadCta => 'Download';

  @override
  String get invoicesViewAllCta => 'View all invoices';

  @override
  String invoicesIssuedOn(String date) {
    return 'Issued on $date';
  }

  @override
  String get disputesTitle => 'My disputes';

  @override
  String get disputesEmpty => 'No open disputes.';

  @override
  String get disputesOpenCta => 'Open a dispute';

  @override
  String get disputesStatusOpen => 'Open';

  @override
  String get disputesStatusInReview => 'Under review';

  @override
  String get disputesStatusResolved => 'Resolved';

  @override
  String get disputesStatusRejected => 'Rejected';

  @override
  String get disputesCategoryDamage => 'Damaged parcel';

  @override
  String get disputesCategoryLost => 'Lost parcel';

  @override
  String get disputesCategoryDelay => 'Significant delay';

  @override
  String get disputesCategoryPayment => 'Payment dispute';

  @override
  String get disputesCategoryOther => 'Other';

  @override
  String get disputesNewTitle => 'New dispute';

  @override
  String get disputesCategoryLabel => 'Category';

  @override
  String get disputesSubjectLabel => 'Subject (optional)';

  @override
  String get disputesDescriptionLabel => 'Describe the issue';

  @override
  String get disputesDescriptionValidator =>
      'Describe the issue in at least 20 characters.';

  @override
  String get disputesClaimedAmountLabel => 'Claimed amount (optional)';

  @override
  String get disputesSubmit => 'Submit dispute';

  @override
  String get disputesSubmitting => 'Sending…';

  @override
  String get disputesSubmitError =>
      'Dispute not submitted. Check your connection and try again.';

  @override
  String get disputesDetailTitle => 'Dispute details';

  @override
  String get disputesCommentLabel => 'Add a comment';

  @override
  String get disputesCommentSend => 'Send';

  @override
  String get disputesResolutionNote => 'Resolution note';

  @override
  String get disputesEventsTitle => 'History';

  @override
  String get disputesParcelLink => 'View parcel';
}
