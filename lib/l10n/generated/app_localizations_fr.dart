// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get brandName => 'SendProColis';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSend => 'Envoyer';

  @override
  String get navTrack => 'Suivre';

  @override
  String get navProfile => 'Profil';

  @override
  String trackingEtaLive(int minutes, int min, int max) {
    return 'Arrive dans ~$minutes min ($min–$max)';
  }

  @override
  String get trackingEtaArriving => 'Arrivée imminente';

  @override
  String get trackingDriverStopped => 'Chauffeur à l\'arrêt';

  @override
  String get trackingPositionStale => 'Position ancienne';

  @override
  String get trackingAnomalyTitle => 'Vérification trajet recommandée';

  @override
  String get trackingAnomalyCritical => 'Alerte trajet';

  @override
  String get ocrScanLabel => 'Scanner une étiquette';

  @override
  String get ocrNoFieldsDetected => 'Aucun texte exploitable détecté.';

  @override
  String get ocrPreviewTitle => 'Champs détectés';

  @override
  String get ocrPreviewHint => 'Vérifiez avant de pré-remplir.';

  @override
  String get ocrActionUse => 'Utiliser';

  @override
  String get ocrActionCancel => 'Annuler';

  @override
  String get aiAssistantTitle => 'Assistant';

  @override
  String get aiAssistantHint => 'Décrivez votre expédition…';

  @override
  String get aiAssistantFillForm => 'Remplir le formulaire avec ces infos';

  @override
  String get promiseSlotMorning => 'Matin';

  @override
  String get promiseSlotAfternoon => 'Après-midi';

  @override
  String get promiseSlotEvening => 'Soir';

  @override
  String get errorNetwork => 'Connexion interrompue';

  @override
  String get errorRetry => 'Réessayer';

  @override
  String get manifestTitle => 'Manifeste navette';

  @override
  String get manifestStopsCount => 'Arrêts';

  @override
  String get manifestOffersCount => 'Colis';

  @override
  String get manifestPicked => 'À embarquer';

  @override
  String get manifestDropOffs => 'À remettre';

  @override
  String get manifestEmpty => 'Aucun colis assigné à ce trajet pour le moment.';

  @override
  String manifestUnassigned(int count) {
    return 'Colis sans arrêt affecté ($count)';
  }

  @override
  String get reachedStopsTitle => 'Arrêts atteints';

  @override
  String get reachedStopsEmpty => 'Aucun arrêt encore atteint sur ce trajet.';

  @override
  String get reachedStopsLoadFailed => 'Chargement impossible';

  @override
  String get optimizeRouteTitle => 'Tournée optimisée';

  @override
  String get optimizeRouteEmpty => 'Aucun colis à ordonner.';

  @override
  String get optimizeRouteDistance => 'Distance';

  @override
  String get optimizeRouteImprovement => 'Gain 2-opt';

  @override
  String get optimizeRouteSteps => 'Étapes';

  @override
  String get handoverInitiateTitle => 'Nouvelle correspondance';

  @override
  String get handoverInitiateExplain =>
      'Transférer ce colis à un autre chauffeur. Un PIN et un code QR seront générés : montrez-les au chauffeur entrant pour valider la remise.';

  @override
  String get handoverInitiateDriverFieldLabel =>
      'Identifiant du chauffeur entrant';

  @override
  String get handoverInitiateDriverFieldHelper => 'UUID du driver cible';

  @override
  String get handoverInitiateSubmit => 'Générer PIN + QR';

  @override
  String get handoverInitiateWarning =>
      'Ces codes ne seront plus affichés. Communiquez-les immédiatement au chauffeur entrant.';

  @override
  String get handoverPinLabel => 'Code PIN';

  @override
  String get handoverQrLabel => 'Jeton QR (à afficher ou partager)';

  @override
  String get handoverCopy => 'Copier';

  @override
  String get handoverDone => 'Terminé';

  @override
  String get handoverConfirmTitle => 'Confirmer une correspondance';

  @override
  String get handoverConfirmExplain =>
      'Saisissez les informations communiquées par le chauffeur sortant pour prendre en charge ce colis.';

  @override
  String get handoverConfirmIdLabel => 'Identifiant de la correspondance';

  @override
  String get handoverConfirmPinLabel => 'PIN (6 chiffres)';

  @override
  String get handoverConfirmQrLabel => 'Jeton QR';

  @override
  String get handoverConfirmQrHelper => 'Scannez ou collez le jeton reçu';

  @override
  String get handoverConfirmScanTooltip => 'Scanner le QR';

  @override
  String get handoverConfirmSubmit => 'Confirmer la prise en charge';

  @override
  String get handoverConfirmSuccess => 'Correspondance confirmée';

  @override
  String get handoverConfirmSuccessBody =>
      'Ce colis vous est maintenant assigné. Poursuivez la livraison.';

  @override
  String get shipmentBatchesTitle => 'Mes lots d\'expédition';

  @override
  String get shipmentBatchesEmpty => 'Aucun lot pour le moment.';

  @override
  String get shipmentBatchesCreate => 'Nouveau lot';

  @override
  String shipmentBatchParcelCount(int count) {
    return '$count colis';
  }

  @override
  String get shipmentBatchDetailTitle => 'Détail du lot';

  @override
  String get shipmentBatchAttach => 'Rattacher un colis';

  @override
  String get shipmentBatchClose => 'Clôturer';

  @override
  String shipmentBatchParcelsHeader(int count) {
    return 'Colis du lot ($count)';
  }

  @override
  String get insuranceSheetTitle => 'Protéger ce colis';

  @override
  String get insuranceSheetSubtitle =>
      'Déclarez la valeur du contenu pour obtenir un devis d\'assurance instantané.';

  @override
  String get insuranceDeclaredValueLabel => 'Valeur déclarée (FCFA)';

  @override
  String get insuranceCrossBorderToggle =>
      'Envoi transfrontalier (+15% de prime)';

  @override
  String get insuranceQuoteCta => 'Obtenir le devis';

  @override
  String get insuranceConfirmCta => 'Confirmer';

  @override
  String insuranceSubscribedSnack(int amount) {
    return 'Colis assuré — prime $amount FCFA.';
  }

  @override
  String get internationalEstimateTitle => 'Simuler un envoi international';

  @override
  String get internationalEstimateCurrency => 'Devise';

  @override
  String get internationalEstimateDeclareValue =>
      'Déclaration de valeur (CN22/CN23 requis)';

  @override
  String get internationalEstimateCta => 'Obtenir le devis';

  @override
  String get backupsTitle => 'Sauvegardes';

  @override
  String get backupsEmptyMessage =>
      'Utilisez le bouton « Nouveau dump » pour en créer une.';

  @override
  String get backupsNewDumpCta => 'Nouveau dump';

  @override
  String get backupsDownloadCta => 'Télécharger';

  @override
  String get backupsRestoreCta => 'Restaurer';

  @override
  String get backupsRestoreConfirmTitle => 'Restaurer cette sauvegarde ?';

  @override
  String get notificationsDeleteAllCta => 'Tout effacer';

  @override
  String get notificationsDeleteAllConfirm =>
      'Toutes vos notifications seront supprimées. Cette action est irréversible.';

  @override
  String get logoutAllCta => 'Déconnecter tous les appareils';

  @override
  String get logoutAllConfirmBody =>
      'Toutes vos sessions seront terminées, y compris sur vos autres appareils. Vous devrez vous reconnecter partout.';

  @override
  String get scoreRefundCta => 'Rembourser des points';

  @override
  String get scoreRefundReasonLabel => 'Motif';

  @override
  String get supportTransferCta => 'Transférer';

  @override
  String get supportTransferSelectAgent => 'Transférer à';

  @override
  String get leadCreateTitle => 'Nouveau prospect';

  @override
  String get leadNameLabel => 'Nom *';

  @override
  String get ticketEditTitle => 'Éditer le ticket';

  @override
  String get incidentEditTitle => 'Éditer l\'incident';

  @override
  String get parcelEventsTitle => 'Événements du colis';

  @override
  String get parcelTemplatesTitle => 'Mes modèles de colis';

  @override
  String get parcelTemplatesEmpty => 'Aucun modèle enregistré.';

  @override
  String get parcelTemplatesSaveCta => 'Enregistrer';

  @override
  String get csvImportTitle => 'Import groupé CSV';

  @override
  String get csvImportPickFile => 'Choisir un fichier';

  @override
  String csvImportRunning(int done, int total) {
    return 'Import en cours… $done/$total';
  }

  @override
  String get experienceLoadFailed =>
      'Récapitulatif indisponible. Réessayez avec une connexion.';

  @override
  String get experienceOverdueNotice =>
      'L\'heure estimée de livraison est dépassée. Contactez le chauffeur pour une mise à jour.';

  @override
  String experienceLastPositionFresh(String timestamp) {
    return 'Dernière position : $timestamp. Position récente.';
  }

  @override
  String experienceLastPositionStale(String timestamp) {
    return 'Dernière position : $timestamp. Position ancienne, le véhicule peut avoir bougé.';
  }

  @override
  String get experienceFinanceTitle => 'Récapitulatif financier';

  @override
  String get experienceAgreedPrice => 'Prix convenu';

  @override
  String get experiencePaymentsConfirmed => 'Paiements confirmés';

  @override
  String get experienceCommissionEstimated => 'Commission (estimation)';

  @override
  String get experienceCommissionRecorded => 'Commission (enregistrée)';

  @override
  String get experienceNetAfterCommissionEstimated =>
      'Net après commission (estimé)';

  @override
  String get experienceNetAfterCommission => 'Net après commission';

  @override
  String get experienceCommissionPaid => 'Commission réglée';

  @override
  String get experienceDebtCreated => 'Dette créée sur ce colis';

  @override
  String get experienceAccountCommissionDebt => 'Dette actuelle du compte';

  @override
  String get experienceParcelPenaltyDue => 'Pénalités restant à régler';

  @override
  String experienceShareReceipt(String amount) {
    return 'Partager le reçu de $amount';
  }

  @override
  String get experienceReportIssue => 'Signaler un problème';

  @override
  String get experienceContactSupport => 'Conversation avec le support';

  @override
  String get experienceSendSimilar => 'Envoyer un colis similaire';

  @override
  String experienceFollowComplaint(String subject, String status) {
    return '$subject — $status\nSuivre cette réclamation';
  }

  @override
  String get complaintReasonLabel => 'Motif';

  @override
  String get complaintReasonDelay => 'Retard';

  @override
  String get complaintReasonDamage => 'Colis endommagé';

  @override
  String get complaintReasonMissing => 'Colis manquant';

  @override
  String get complaintReasonPayment => 'Paiement';

  @override
  String get complaintReasonOther => 'Autre problème';

  @override
  String get complaintMessageLabel => 'Décrivez le problème';

  @override
  String get complaintMessageValidator =>
      'Décrivez le problème en au moins 10 caractères.';

  @override
  String complaintPhotoAttached(int index) {
    return 'Photo $index jointe';
  }

  @override
  String get complaintRemovePhoto => 'Retirer la photo';

  @override
  String complaintAddPhoto(int count) {
    return 'Ajouter une photo ($count/4)';
  }

  @override
  String get complaintSending => 'Envoi…';

  @override
  String get complaintSubmit => 'Envoyer la réclamation';

  @override
  String get complaintPhotoError => 'Photo non envoyée. Réessayez.';

  @override
  String get complaintSubmitError =>
      'Réclamation non confirmée. Votre saisie est conservée ; réessayez.';

  @override
  String get helpGuideLanguageLabel => 'Langue des consignes';

  @override
  String get helpGuideLangFr => 'Français';

  @override
  String get helpGuideLangWo => 'Wolof';

  @override
  String get helpGuidePlay => 'Écouter';

  @override
  String get helpGuideStop => 'Arrêter';

  @override
  String get helpGuideAudioError =>
      'Lecture indisponible. Le texte reste accessible.';

  @override
  String get helpGuideNoneAvailableFr =>
      'Les consignes en français ne sont pas encore disponibles.';

  @override
  String get helpGuideNoneAvailableWo =>
      'Les consignes en wolof ne sont pas encore disponibles.';

  @override
  String get helpGuideContactSupport => 'Demander de l\'aide au support';

  @override
  String get qualityScreenTitle => 'Qualité de service';

  @override
  String get qualityScreenHeader =>
      'Indicateurs sur les 30 derniers jours. Les retards utilisent les estimations de livraison enregistrées.';

  @override
  String get qualityScreenError => 'Indicateurs temporairement indisponibles.';

  @override
  String get qualityScreenRefresh => 'Actualiser';

  @override
  String get qualityParcelsCreated => 'Colis créés';

  @override
  String get qualityParcelsDelivered => 'Colis livrés';

  @override
  String get qualityDeliveriesOverdue => 'Livraisons en retard';

  @override
  String get qualityPaymentsFailed => 'Paiements échoués';

  @override
  String get qualityCreationsStarted => 'Créations commencées';

  @override
  String get qualityCreationsAbandoned => 'Abandons présumés après 24 h';

  @override
  String get qualityFirstResponse => 'Première réponse du support';

  @override
  String get qualityNotYetMeasured => 'Pas encore de mesure';

  @override
  String qualityMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String qualityFooter(String sample) {
    return 'Abandons présumés : formulaires instrumentés sans création confirmée après 24 h. Délai du support calculé sur $sample conversation(s) avec réponse enregistrée.';
  }

  @override
  String get kycDeleteCta => 'Supprimer';

  @override
  String get kycDeleteConfirmTitle => 'Supprimer cette vérification ?';

  @override
  String get kycDeleteConfirmBody =>
      'Les documents et l\'historique de vérification seront définitivement effacés.';

  @override
  String get kycRequestInfoCta => 'Demander un complément';

  @override
  String get kycRequestInfoTitle => 'Demande d\'informations complémentaires';

  @override
  String get kycRequestInfoMessageLabel => 'Message pour l\'utilisateur';

  @override
  String get kycRequestInfoSubmit => 'Envoyer la demande';

  @override
  String get supportCloseCta => 'Clôturer';

  @override
  String get supportCloseTitle => 'Clôturer la conversation';

  @override
  String get supportCloseCategoryLabel => 'Catégorie';

  @override
  String get supportCloseCategoryResolved => 'Résolu';

  @override
  String get supportCloseCategoryDuplicate => 'Doublon';

  @override
  String get supportCloseCategorySpam => 'Spam';

  @override
  String get supportCloseCategoryNoAnswer => 'Sans réponse';

  @override
  String get supportCloseReasonLabel => 'Motif de clôture';

  @override
  String get supportCloseReasonValidator =>
      'Indiquez un motif (min. 5 caractères).';

  @override
  String get supportCloseSubmit => 'Clôturer';

  @override
  String get aiAssistantOpenCta => 'Assistant IA';

  @override
  String get aiAssistantPrefilledSnack =>
      'Formulaire pré-rempli depuis l\'assistant.';

  @override
  String get aiAssistantVoiceRecord => 'Dicter';

  @override
  String get aiAssistantVoiceRecording => 'Enregistrement…';

  @override
  String get aiAssistantVoiceStop => 'Arrêter';

  @override
  String get aiAssistantVoiceTranscribing => 'Transcription…';

  @override
  String get aiAssistantVoiceUnavailable =>
      'Transcription vocale indisponible. Veuillez saisir votre demande.';

  @override
  String get aiAssistantVoicePermission =>
      'Autorisez le microphone dans les réglages pour dicter.';

  @override
  String get batchStopEventsTitle => 'Événements de la tournée';

  @override
  String get batchStopEventsEmpty => 'Aucun événement enregistré pour ce lot.';

  @override
  String get invoicesSectionTitle => 'Factures';

  @override
  String get invoicesEmpty => 'Aucune facture disponible.';

  @override
  String get invoicesDownloadCta => 'Télécharger';

  @override
  String get invoicesViewAllCta => 'Voir toutes les factures';

  @override
  String invoicesIssuedOn(String date) {
    return 'Émise le $date';
  }

  @override
  String get disputesTitle => 'Mes litiges';

  @override
  String get disputesEmpty => 'Aucun litige en cours.';

  @override
  String get disputesOpenCta => 'Ouvrir un litige';

  @override
  String get disputesStatusOpen => 'Ouvert';

  @override
  String get disputesStatusInReview => 'En cours d\'étude';

  @override
  String get disputesStatusResolved => 'Résolu';

  @override
  String get disputesStatusRejected => 'Rejeté';

  @override
  String get disputesCategoryDamage => 'Colis endommagé';

  @override
  String get disputesCategoryLost => 'Colis perdu';

  @override
  String get disputesCategoryDelay => 'Retard important';

  @override
  String get disputesCategoryPayment => 'Litige de paiement';

  @override
  String get disputesCategoryOther => 'Autre';

  @override
  String get disputesNewTitle => 'Nouveau litige';

  @override
  String get disputesCategoryLabel => 'Catégorie';

  @override
  String get disputesSubjectLabel => 'Objet (optionnel)';

  @override
  String get disputesDescriptionLabel => 'Décrivez le problème';

  @override
  String get disputesDescriptionValidator =>
      'Décrivez le problème en au moins 20 caractères.';

  @override
  String get disputesClaimedAmountLabel => 'Montant réclamé (optionnel)';

  @override
  String get disputesSubmit => 'Soumettre le litige';

  @override
  String get disputesSubmitting => 'Envoi…';

  @override
  String get disputesSubmitError =>
      'Litige non soumis. Vérifiez votre connexion et réessayez.';

  @override
  String get disputesDetailTitle => 'Détail du litige';

  @override
  String get disputesCommentLabel => 'Ajouter un commentaire';

  @override
  String get disputesCommentSend => 'Envoyer';

  @override
  String get disputesResolutionNote => 'Note de résolution';

  @override
  String get disputesEventsTitle => 'Historique';

  @override
  String get disputesParcelLink => 'Voir le colis';
}
