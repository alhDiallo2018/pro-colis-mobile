import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_wo.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('wo')
  ];

  /// Nom commercial de la plateforme
  ///
  /// In fr, this message translates to:
  /// **'SendProColis'**
  String get brandName;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get navSend;

  /// No description provided for @navTrack.
  ///
  /// In fr, this message translates to:
  /// **'Suivre'**
  String get navTrack;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// Badge ETA dynamique
  ///
  /// In fr, this message translates to:
  /// **'Arrive dans ~{minutes} min ({min}–{max})'**
  String trackingEtaLive(int minutes, int min, int max);

  /// No description provided for @trackingEtaArriving.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée imminente'**
  String get trackingEtaArriving;

  /// No description provided for @trackingDriverStopped.
  ///
  /// In fr, this message translates to:
  /// **'Chauffeur à l\'arrêt'**
  String get trackingDriverStopped;

  /// No description provided for @trackingPositionStale.
  ///
  /// In fr, this message translates to:
  /// **'Position ancienne'**
  String get trackingPositionStale;

  /// No description provided for @trackingAnomalyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification trajet recommandée'**
  String get trackingAnomalyTitle;

  /// No description provided for @trackingAnomalyCritical.
  ///
  /// In fr, this message translates to:
  /// **'Alerte trajet'**
  String get trackingAnomalyCritical;

  /// No description provided for @ocrScanLabel.
  ///
  /// In fr, this message translates to:
  /// **'Scanner une étiquette'**
  String get ocrScanLabel;

  /// No description provided for @ocrNoFieldsDetected.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte exploitable détecté.'**
  String get ocrNoFieldsDetected;

  /// No description provided for @ocrPreviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Champs détectés'**
  String get ocrPreviewTitle;

  /// No description provided for @ocrPreviewHint.
  ///
  /// In fr, this message translates to:
  /// **'Vérifiez avant de pré-remplir.'**
  String get ocrPreviewHint;

  /// No description provided for @ocrActionUse.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser'**
  String get ocrActionUse;

  /// No description provided for @ocrActionCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get ocrActionCancel;

  /// No description provided for @aiAssistantTitle.
  ///
  /// In fr, this message translates to:
  /// **'Assistant'**
  String get aiAssistantTitle;

  /// No description provided for @aiAssistantHint.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez votre expédition…'**
  String get aiAssistantHint;

  /// No description provided for @aiAssistantFillForm.
  ///
  /// In fr, this message translates to:
  /// **'Remplir le formulaire avec ces infos'**
  String get aiAssistantFillForm;

  /// No description provided for @promiseSlotMorning.
  ///
  /// In fr, this message translates to:
  /// **'Matin'**
  String get promiseSlotMorning;

  /// No description provided for @promiseSlotAfternoon.
  ///
  /// In fr, this message translates to:
  /// **'Après-midi'**
  String get promiseSlotAfternoon;

  /// No description provided for @promiseSlotEvening.
  ///
  /// In fr, this message translates to:
  /// **'Soir'**
  String get promiseSlotEvening;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Connexion interrompue'**
  String get errorNetwork;

  /// No description provided for @errorRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get errorRetry;

  /// No description provided for @manifestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Manifeste navette'**
  String get manifestTitle;

  /// No description provided for @manifestStopsCount.
  ///
  /// In fr, this message translates to:
  /// **'Arrêts'**
  String get manifestStopsCount;

  /// No description provided for @manifestOffersCount.
  ///
  /// In fr, this message translates to:
  /// **'Colis'**
  String get manifestOffersCount;

  /// No description provided for @manifestPicked.
  ///
  /// In fr, this message translates to:
  /// **'À embarquer'**
  String get manifestPicked;

  /// No description provided for @manifestDropOffs.
  ///
  /// In fr, this message translates to:
  /// **'À remettre'**
  String get manifestDropOffs;

  /// No description provided for @manifestEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun colis assigné à ce trajet pour le moment.'**
  String get manifestEmpty;

  /// No description provided for @manifestUnassigned.
  ///
  /// In fr, this message translates to:
  /// **'Colis sans arrêt affecté ({count})'**
  String manifestUnassigned(int count);

  /// No description provided for @reachedStopsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Arrêts atteints'**
  String get reachedStopsTitle;

  /// No description provided for @reachedStopsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun arrêt encore atteint sur ce trajet.'**
  String get reachedStopsEmpty;

  /// No description provided for @reachedStopsLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Chargement impossible'**
  String get reachedStopsLoadFailed;

  /// No description provided for @optimizeRouteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Tournée optimisée'**
  String get optimizeRouteTitle;

  /// No description provided for @optimizeRouteEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun colis à ordonner.'**
  String get optimizeRouteEmpty;

  /// No description provided for @optimizeRouteDistance.
  ///
  /// In fr, this message translates to:
  /// **'Distance'**
  String get optimizeRouteDistance;

  /// No description provided for @optimizeRouteImprovement.
  ///
  /// In fr, this message translates to:
  /// **'Gain 2-opt'**
  String get optimizeRouteImprovement;

  /// No description provided for @optimizeRouteSteps.
  ///
  /// In fr, this message translates to:
  /// **'Étapes'**
  String get optimizeRouteSteps;

  /// No description provided for @handoverInitiateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle correspondance'**
  String get handoverInitiateTitle;

  /// No description provided for @handoverInitiateExplain.
  ///
  /// In fr, this message translates to:
  /// **'Transférer ce colis à un autre chauffeur. Un PIN et un code QR seront générés : montrez-les au chauffeur entrant pour valider la remise.'**
  String get handoverInitiateExplain;

  /// No description provided for @handoverInitiateDriverFieldLabel.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant du chauffeur entrant'**
  String get handoverInitiateDriverFieldLabel;

  /// No description provided for @handoverInitiateDriverFieldHelper.
  ///
  /// In fr, this message translates to:
  /// **'UUID du driver cible'**
  String get handoverInitiateDriverFieldHelper;

  /// No description provided for @handoverInitiateSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Générer PIN + QR'**
  String get handoverInitiateSubmit;

  /// No description provided for @handoverInitiateWarning.
  ///
  /// In fr, this message translates to:
  /// **'Ces codes ne seront plus affichés. Communiquez-les immédiatement au chauffeur entrant.'**
  String get handoverInitiateWarning;

  /// No description provided for @handoverPinLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code PIN'**
  String get handoverPinLabel;

  /// No description provided for @handoverQrLabel.
  ///
  /// In fr, this message translates to:
  /// **'Jeton QR (à afficher ou partager)'**
  String get handoverQrLabel;

  /// No description provided for @handoverCopy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get handoverCopy;

  /// No description provided for @handoverDone.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get handoverDone;

  /// No description provided for @handoverConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer une correspondance'**
  String get handoverConfirmTitle;

  /// No description provided for @handoverConfirmExplain.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez les informations communiquées par le chauffeur sortant pour prendre en charge ce colis.'**
  String get handoverConfirmExplain;

  /// No description provided for @handoverConfirmIdLabel.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant de la correspondance'**
  String get handoverConfirmIdLabel;

  /// No description provided for @handoverConfirmPinLabel.
  ///
  /// In fr, this message translates to:
  /// **'PIN (6 chiffres)'**
  String get handoverConfirmPinLabel;

  /// No description provided for @handoverConfirmQrLabel.
  ///
  /// In fr, this message translates to:
  /// **'Jeton QR'**
  String get handoverConfirmQrLabel;

  /// No description provided for @handoverConfirmQrHelper.
  ///
  /// In fr, this message translates to:
  /// **'Scannez ou collez le jeton reçu'**
  String get handoverConfirmQrHelper;

  /// No description provided for @handoverConfirmScanTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le QR'**
  String get handoverConfirmScanTooltip;

  /// No description provided for @handoverConfirmSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer la prise en charge'**
  String get handoverConfirmSubmit;

  /// No description provided for @handoverConfirmSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Correspondance confirmée'**
  String get handoverConfirmSuccess;

  /// No description provided for @handoverConfirmSuccessBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce colis vous est maintenant assigné. Poursuivez la livraison.'**
  String get handoverConfirmSuccessBody;

  /// No description provided for @shipmentBatchesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes lots d\'expédition'**
  String get shipmentBatchesTitle;

  /// No description provided for @shipmentBatchesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun lot pour le moment.'**
  String get shipmentBatchesEmpty;

  /// No description provided for @shipmentBatchesCreate.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau lot'**
  String get shipmentBatchesCreate;

  /// No description provided for @shipmentBatchParcelCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} colis'**
  String shipmentBatchParcelCount(int count);

  /// No description provided for @shipmentBatchDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détail du lot'**
  String get shipmentBatchDetailTitle;

  /// No description provided for @shipmentBatchAttach.
  ///
  /// In fr, this message translates to:
  /// **'Rattacher un colis'**
  String get shipmentBatchAttach;

  /// No description provided for @shipmentBatchClose.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer'**
  String get shipmentBatchClose;

  /// No description provided for @shipmentBatchParcelsHeader.
  ///
  /// In fr, this message translates to:
  /// **'Colis du lot ({count})'**
  String shipmentBatchParcelsHeader(int count);

  /// No description provided for @insuranceSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protéger ce colis'**
  String get insuranceSheetTitle;

  /// No description provided for @insuranceSheetSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Déclarez la valeur du contenu pour obtenir un devis d\'assurance instantané.'**
  String get insuranceSheetSubtitle;

  /// No description provided for @insuranceDeclaredValueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Valeur déclarée (FCFA)'**
  String get insuranceDeclaredValueLabel;

  /// No description provided for @insuranceCrossBorderToggle.
  ///
  /// In fr, this message translates to:
  /// **'Envoi transfrontalier (+15% de prime)'**
  String get insuranceCrossBorderToggle;

  /// No description provided for @insuranceQuoteCta.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir le devis'**
  String get insuranceQuoteCta;

  /// No description provided for @insuranceConfirmCta.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get insuranceConfirmCta;

  /// No description provided for @insuranceSubscribedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Colis assuré — prime {amount} FCFA.'**
  String insuranceSubscribedSnack(int amount);

  /// No description provided for @internationalEstimateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Simuler un envoi international'**
  String get internationalEstimateTitle;

  /// No description provided for @internationalEstimateCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Devise'**
  String get internationalEstimateCurrency;

  /// No description provided for @internationalEstimateDeclareValue.
  ///
  /// In fr, this message translates to:
  /// **'Déclaration de valeur (CN22/CN23 requis)'**
  String get internationalEstimateDeclareValue;

  /// No description provided for @internationalEstimateCta.
  ///
  /// In fr, this message translates to:
  /// **'Obtenir le devis'**
  String get internationalEstimateCta;

  /// No description provided for @backupsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegardes'**
  String get backupsTitle;

  /// No description provided for @backupsEmptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez le bouton « Nouveau dump » pour en créer une.'**
  String get backupsEmptyMessage;

  /// No description provided for @backupsNewDumpCta.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau dump'**
  String get backupsNewDumpCta;

  /// No description provided for @backupsDownloadCta.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get backupsDownloadCta;

  /// No description provided for @backupsRestoreCta.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get backupsRestoreCta;

  /// No description provided for @backupsRestoreConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer cette sauvegarde ?'**
  String get backupsRestoreConfirmTitle;

  /// No description provided for @notificationsDeleteAllCta.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get notificationsDeleteAllCta;

  /// No description provided for @notificationsDeleteAllConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos notifications seront supprimées. Cette action est irréversible.'**
  String get notificationsDeleteAllConfirm;

  /// No description provided for @logoutAllCta.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter tous les appareils'**
  String get logoutAllCta;

  /// No description provided for @logoutAllConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos sessions seront terminées, y compris sur vos autres appareils. Vous devrez vous reconnecter partout.'**
  String get logoutAllConfirmBody;

  /// No description provided for @scoreRefundCta.
  ///
  /// In fr, this message translates to:
  /// **'Rembourser des points'**
  String get scoreRefundCta;

  /// No description provided for @scoreRefundReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get scoreRefundReasonLabel;

  /// No description provided for @supportTransferCta.
  ///
  /// In fr, this message translates to:
  /// **'Transférer'**
  String get supportTransferCta;

  /// No description provided for @supportTransferSelectAgent.
  ///
  /// In fr, this message translates to:
  /// **'Transférer à'**
  String get supportTransferSelectAgent;

  /// No description provided for @leadCreateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau prospect'**
  String get leadCreateTitle;

  /// No description provided for @leadNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom *'**
  String get leadNameLabel;

  /// No description provided for @ticketEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Éditer le ticket'**
  String get ticketEditTitle;

  /// No description provided for @incidentEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Éditer l\'incident'**
  String get incidentEditTitle;

  /// No description provided for @parcelEventsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Événements du colis'**
  String get parcelEventsTitle;

  /// No description provided for @parcelTemplatesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes modèles de colis'**
  String get parcelTemplatesTitle;

  /// No description provided for @parcelTemplatesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun modèle enregistré.'**
  String get parcelTemplatesEmpty;

  /// No description provided for @parcelTemplatesSaveCta.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get parcelTemplatesSaveCta;

  /// No description provided for @csvImportTitle.
  ///
  /// In fr, this message translates to:
  /// **'Import groupé CSV'**
  String get csvImportTitle;

  /// No description provided for @csvImportPickFile.
  ///
  /// In fr, this message translates to:
  /// **'Choisir un fichier'**
  String get csvImportPickFile;

  /// No description provided for @csvImportRunning.
  ///
  /// In fr, this message translates to:
  /// **'Import en cours… {done}/{total}'**
  String csvImportRunning(int done, int total);

  /// No description provided for @experienceLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif indisponible. Réessayez avec une connexion.'**
  String get experienceLoadFailed;

  /// No description provided for @experienceOverdueNotice.
  ///
  /// In fr, this message translates to:
  /// **'L\'heure estimée de livraison est dépassée. Contactez le chauffeur pour une mise à jour.'**
  String get experienceOverdueNotice;

  /// No description provided for @experienceLastPositionFresh.
  ///
  /// In fr, this message translates to:
  /// **'Dernière position : {timestamp}. Position récente.'**
  String experienceLastPositionFresh(String timestamp);

  /// No description provided for @experienceLastPositionStale.
  ///
  /// In fr, this message translates to:
  /// **'Dernière position : {timestamp}. Position ancienne, le véhicule peut avoir bougé.'**
  String experienceLastPositionStale(String timestamp);

  /// No description provided for @experienceFinanceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif financier'**
  String get experienceFinanceTitle;

  /// No description provided for @experienceAgreedPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix convenu'**
  String get experienceAgreedPrice;

  /// No description provided for @experiencePaymentsConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Paiements confirmés'**
  String get experiencePaymentsConfirmed;

  /// No description provided for @experienceCommissionEstimated.
  ///
  /// In fr, this message translates to:
  /// **'Commission (estimation)'**
  String get experienceCommissionEstimated;

  /// No description provided for @experienceCommissionRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Commission (enregistrée)'**
  String get experienceCommissionRecorded;

  /// No description provided for @experienceNetAfterCommissionEstimated.
  ///
  /// In fr, this message translates to:
  /// **'Net après commission (estimé)'**
  String get experienceNetAfterCommissionEstimated;

  /// No description provided for @experienceNetAfterCommission.
  ///
  /// In fr, this message translates to:
  /// **'Net après commission'**
  String get experienceNetAfterCommission;

  /// No description provided for @experienceCommissionPaid.
  ///
  /// In fr, this message translates to:
  /// **'Commission réglée'**
  String get experienceCommissionPaid;

  /// No description provided for @experienceDebtCreated.
  ///
  /// In fr, this message translates to:
  /// **'Dette créée sur ce colis'**
  String get experienceDebtCreated;

  /// No description provided for @experienceAccountCommissionDebt.
  ///
  /// In fr, this message translates to:
  /// **'Dette actuelle du compte'**
  String get experienceAccountCommissionDebt;

  /// No description provided for @experienceParcelPenaltyDue.
  ///
  /// In fr, this message translates to:
  /// **'Pénalités restant à régler'**
  String get experienceParcelPenaltyDue;

  /// No description provided for @experienceShareReceipt.
  ///
  /// In fr, this message translates to:
  /// **'Partager le reçu de {amount}'**
  String experienceShareReceipt(String amount);

  /// No description provided for @experienceReportIssue.
  ///
  /// In fr, this message translates to:
  /// **'Signaler un problème'**
  String get experienceReportIssue;

  /// No description provided for @experienceContactSupport.
  ///
  /// In fr, this message translates to:
  /// **'Conversation avec le support'**
  String get experienceContactSupport;

  /// No description provided for @experienceSendSimilar.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer un colis similaire'**
  String get experienceSendSimilar;

  /// No description provided for @experienceFollowComplaint.
  ///
  /// In fr, this message translates to:
  /// **'{subject} — {status}\nSuivre cette réclamation'**
  String experienceFollowComplaint(String subject, String status);

  /// No description provided for @complaintReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif'**
  String get complaintReasonLabel;

  /// No description provided for @complaintReasonDelay.
  ///
  /// In fr, this message translates to:
  /// **'Retard'**
  String get complaintReasonDelay;

  /// No description provided for @complaintReasonDamage.
  ///
  /// In fr, this message translates to:
  /// **'Colis endommagé'**
  String get complaintReasonDamage;

  /// No description provided for @complaintReasonMissing.
  ///
  /// In fr, this message translates to:
  /// **'Colis manquant'**
  String get complaintReasonMissing;

  /// No description provided for @complaintReasonPayment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement'**
  String get complaintReasonPayment;

  /// No description provided for @complaintReasonOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre problème'**
  String get complaintReasonOther;

  /// No description provided for @complaintMessageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème'**
  String get complaintMessageLabel;

  /// No description provided for @complaintMessageValidator.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème en au moins 10 caractères.'**
  String get complaintMessageValidator;

  /// No description provided for @complaintPhotoAttached.
  ///
  /// In fr, this message translates to:
  /// **'Photo {index} jointe'**
  String complaintPhotoAttached(int index);

  /// No description provided for @complaintRemovePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Retirer la photo'**
  String get complaintRemovePhoto;

  /// No description provided for @complaintAddPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo ({count}/4)'**
  String complaintAddPhoto(int count);

  /// No description provided for @complaintSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get complaintSending;

  /// No description provided for @complaintSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la réclamation'**
  String get complaintSubmit;

  /// No description provided for @complaintPhotoError.
  ///
  /// In fr, this message translates to:
  /// **'Photo non envoyée. Réessayez.'**
  String get complaintPhotoError;

  /// No description provided for @complaintSubmitError.
  ///
  /// In fr, this message translates to:
  /// **'Réclamation non confirmée. Votre saisie est conservée ; réessayez.'**
  String get complaintSubmitError;

  /// No description provided for @helpGuideLanguageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Langue des consignes'**
  String get helpGuideLanguageLabel;

  /// No description provided for @helpGuideLangFr.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get helpGuideLangFr;

  /// No description provided for @helpGuideLangWo.
  ///
  /// In fr, this message translates to:
  /// **'Wolof'**
  String get helpGuideLangWo;

  /// No description provided for @helpGuidePlay.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get helpGuidePlay;

  /// No description provided for @helpGuideStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get helpGuideStop;

  /// No description provided for @helpGuideAudioError.
  ///
  /// In fr, this message translates to:
  /// **'Lecture indisponible. Le texte reste accessible.'**
  String get helpGuideAudioError;

  /// No description provided for @helpGuideNoneAvailableFr.
  ///
  /// In fr, this message translates to:
  /// **'Les consignes en français ne sont pas encore disponibles.'**
  String get helpGuideNoneAvailableFr;

  /// No description provided for @helpGuideNoneAvailableWo.
  ///
  /// In fr, this message translates to:
  /// **'Les consignes en wolof ne sont pas encore disponibles.'**
  String get helpGuideNoneAvailableWo;

  /// No description provided for @helpGuideContactSupport.
  ///
  /// In fr, this message translates to:
  /// **'Demander de l\'aide au support'**
  String get helpGuideContactSupport;

  /// No description provided for @qualityScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Qualité de service'**
  String get qualityScreenTitle;

  /// No description provided for @qualityScreenHeader.
  ///
  /// In fr, this message translates to:
  /// **'Indicateurs sur les 30 derniers jours. Les retards utilisent les estimations de livraison enregistrées.'**
  String get qualityScreenHeader;

  /// No description provided for @qualityScreenError.
  ///
  /// In fr, this message translates to:
  /// **'Indicateurs temporairement indisponibles.'**
  String get qualityScreenError;

  /// No description provided for @qualityScreenRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get qualityScreenRefresh;

  /// No description provided for @qualityParcelsCreated.
  ///
  /// In fr, this message translates to:
  /// **'Colis créés'**
  String get qualityParcelsCreated;

  /// No description provided for @qualityParcelsDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Colis livrés'**
  String get qualityParcelsDelivered;

  /// No description provided for @qualityDeliveriesOverdue.
  ///
  /// In fr, this message translates to:
  /// **'Livraisons en retard'**
  String get qualityDeliveriesOverdue;

  /// No description provided for @qualityPaymentsFailed.
  ///
  /// In fr, this message translates to:
  /// **'Paiements échoués'**
  String get qualityPaymentsFailed;

  /// No description provided for @qualityCreationsStarted.
  ///
  /// In fr, this message translates to:
  /// **'Créations commencées'**
  String get qualityCreationsStarted;

  /// No description provided for @qualityCreationsAbandoned.
  ///
  /// In fr, this message translates to:
  /// **'Abandons présumés après 24 h'**
  String get qualityCreationsAbandoned;

  /// No description provided for @qualityFirstResponse.
  ///
  /// In fr, this message translates to:
  /// **'Première réponse du support'**
  String get qualityFirstResponse;

  /// No description provided for @qualityNotYetMeasured.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de mesure'**
  String get qualityNotYetMeasured;

  /// No description provided for @qualityMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String qualityMinutes(int minutes);

  /// No description provided for @qualityFooter.
  ///
  /// In fr, this message translates to:
  /// **'Abandons présumés : formulaires instrumentés sans création confirmée après 24 h. Délai du support calculé sur {sample} conversation(s) avec réponse enregistrée.'**
  String qualityFooter(String sample);

  /// No description provided for @kycDeleteCta.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get kycDeleteCta;

  /// No description provided for @kycDeleteConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette vérification ?'**
  String get kycDeleteConfirmTitle;

  /// No description provided for @kycDeleteConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Les documents et l\'historique de vérification seront définitivement effacés.'**
  String get kycDeleteConfirmBody;

  /// No description provided for @kycRequestInfoCta.
  ///
  /// In fr, this message translates to:
  /// **'Demander un complément'**
  String get kycRequestInfoCta;

  /// No description provided for @kycRequestInfoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Demande d\'informations complémentaires'**
  String get kycRequestInfoTitle;

  /// No description provided for @kycRequestInfoMessageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Message pour l\'utilisateur'**
  String get kycRequestInfoMessageLabel;

  /// No description provided for @kycRequestInfoSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la demande'**
  String get kycRequestInfoSubmit;

  /// No description provided for @supportCloseCta.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer'**
  String get supportCloseCta;

  /// No description provided for @supportCloseTitle.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer la conversation'**
  String get supportCloseTitle;

  /// No description provided for @supportCloseCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get supportCloseCategoryLabel;

  /// No description provided for @supportCloseCategoryResolved.
  ///
  /// In fr, this message translates to:
  /// **'Résolu'**
  String get supportCloseCategoryResolved;

  /// No description provided for @supportCloseCategoryDuplicate.
  ///
  /// In fr, this message translates to:
  /// **'Doublon'**
  String get supportCloseCategoryDuplicate;

  /// No description provided for @supportCloseCategorySpam.
  ///
  /// In fr, this message translates to:
  /// **'Spam'**
  String get supportCloseCategorySpam;

  /// No description provided for @supportCloseCategoryNoAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Sans réponse'**
  String get supportCloseCategoryNoAnswer;

  /// No description provided for @supportCloseReasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Motif de clôture'**
  String get supportCloseReasonLabel;

  /// No description provided for @supportCloseReasonValidator.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un motif (min. 5 caractères).'**
  String get supportCloseReasonValidator;

  /// No description provided for @supportCloseSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Clôturer'**
  String get supportCloseSubmit;

  /// No description provided for @aiAssistantOpenCta.
  ///
  /// In fr, this message translates to:
  /// **'Assistant IA'**
  String get aiAssistantOpenCta;

  /// No description provided for @aiAssistantPrefilledSnack.
  ///
  /// In fr, this message translates to:
  /// **'Formulaire pré-rempli depuis l\'assistant.'**
  String get aiAssistantPrefilledSnack;

  /// No description provided for @aiAssistantVoiceRecord.
  ///
  /// In fr, this message translates to:
  /// **'Dicter'**
  String get aiAssistantVoiceRecord;

  /// No description provided for @aiAssistantVoiceRecording.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement…'**
  String get aiAssistantVoiceRecording;

  /// No description provided for @aiAssistantVoiceStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get aiAssistantVoiceStop;

  /// No description provided for @aiAssistantVoiceTranscribing.
  ///
  /// In fr, this message translates to:
  /// **'Transcription…'**
  String get aiAssistantVoiceTranscribing;

  /// No description provided for @aiAssistantVoiceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Transcription vocale indisponible. Veuillez saisir votre demande.'**
  String get aiAssistantVoiceUnavailable;

  /// No description provided for @aiAssistantVoicePermission.
  ///
  /// In fr, this message translates to:
  /// **'Autorisez le microphone dans les réglages pour dicter.'**
  String get aiAssistantVoicePermission;

  /// No description provided for @batchStopEventsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Événements de la tournée'**
  String get batchStopEventsTitle;

  /// No description provided for @batchStopEventsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement enregistré pour ce lot.'**
  String get batchStopEventsEmpty;

  /// No description provided for @invoicesSectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Factures'**
  String get invoicesSectionTitle;

  /// No description provided for @invoicesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune facture disponible.'**
  String get invoicesEmpty;

  /// No description provided for @invoicesDownloadCta.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get invoicesDownloadCta;

  /// No description provided for @invoicesViewAllCta.
  ///
  /// In fr, this message translates to:
  /// **'Voir toutes les factures'**
  String get invoicesViewAllCta;

  /// No description provided for @invoicesIssuedOn.
  ///
  /// In fr, this message translates to:
  /// **'Émise le {date}'**
  String invoicesIssuedOn(String date);

  /// No description provided for @disputesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes litiges'**
  String get disputesTitle;

  /// No description provided for @disputesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun litige en cours.'**
  String get disputesEmpty;

  /// No description provided for @disputesOpenCta.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir un litige'**
  String get disputesOpenCta;

  /// No description provided for @disputesStatusOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert'**
  String get disputesStatusOpen;

  /// No description provided for @disputesStatusInReview.
  ///
  /// In fr, this message translates to:
  /// **'En cours d\'étude'**
  String get disputesStatusInReview;

  /// No description provided for @disputesStatusResolved.
  ///
  /// In fr, this message translates to:
  /// **'Résolu'**
  String get disputesStatusResolved;

  /// No description provided for @disputesStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Rejeté'**
  String get disputesStatusRejected;

  /// No description provided for @disputesCategoryDamage.
  ///
  /// In fr, this message translates to:
  /// **'Colis endommagé'**
  String get disputesCategoryDamage;

  /// No description provided for @disputesCategoryLost.
  ///
  /// In fr, this message translates to:
  /// **'Colis perdu'**
  String get disputesCategoryLost;

  /// No description provided for @disputesCategoryDelay.
  ///
  /// In fr, this message translates to:
  /// **'Retard important'**
  String get disputesCategoryDelay;

  /// No description provided for @disputesCategoryPayment.
  ///
  /// In fr, this message translates to:
  /// **'Litige de paiement'**
  String get disputesCategoryPayment;

  /// No description provided for @disputesCategoryOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get disputesCategoryOther;

  /// No description provided for @disputesNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau litige'**
  String get disputesNewTitle;

  /// No description provided for @disputesCategoryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get disputesCategoryLabel;

  /// No description provided for @disputesSubjectLabel.
  ///
  /// In fr, this message translates to:
  /// **'Objet (optionnel)'**
  String get disputesSubjectLabel;

  /// No description provided for @disputesDescriptionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème'**
  String get disputesDescriptionLabel;

  /// No description provided for @disputesDescriptionValidator.
  ///
  /// In fr, this message translates to:
  /// **'Décrivez le problème en au moins 20 caractères.'**
  String get disputesDescriptionValidator;

  /// No description provided for @disputesClaimedAmountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Montant réclamé (optionnel)'**
  String get disputesClaimedAmountLabel;

  /// No description provided for @disputesSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Soumettre le litige'**
  String get disputesSubmit;

  /// No description provided for @disputesSubmitting.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get disputesSubmitting;

  /// No description provided for @disputesSubmitError.
  ///
  /// In fr, this message translates to:
  /// **'Litige non soumis. Vérifiez votre connexion et réessayez.'**
  String get disputesSubmitError;

  /// No description provided for @disputesDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détail du litige'**
  String get disputesDetailTitle;

  /// No description provided for @disputesCommentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un commentaire'**
  String get disputesCommentLabel;

  /// No description provided for @disputesCommentSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get disputesCommentSend;

  /// No description provided for @disputesResolutionNote.
  ///
  /// In fr, this message translates to:
  /// **'Note de résolution'**
  String get disputesResolutionNote;

  /// No description provided for @disputesEventsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get disputesEventsTitle;

  /// No description provided for @disputesParcelLink.
  ///
  /// In fr, this message translates to:
  /// **'Voir le colis'**
  String get disputesParcelLink;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'wo'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'wo':
      return AppLocalizationsWo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
