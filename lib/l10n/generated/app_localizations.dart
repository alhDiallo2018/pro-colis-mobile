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
