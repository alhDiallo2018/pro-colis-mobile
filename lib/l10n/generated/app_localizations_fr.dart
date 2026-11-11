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
}
