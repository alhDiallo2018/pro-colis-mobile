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
}
