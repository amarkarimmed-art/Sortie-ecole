import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('fr')
  ];

  /// No description provided for @ecranSurveillanceTitre.
  ///
  /// In fr, this message translates to:
  /// **'Surveillance des sorties'**
  String get ecranSurveillanceTitre;

  /// No description provided for @chargementFile.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de la file...'**
  String get chargementFile;

  /// No description provided for @aucunEleveAppele.
  ///
  /// In fr, this message translates to:
  /// **'Aucun élève appelé pour le moment'**
  String get aucunEleveAppele;

  /// No description provided for @reessayer.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get reessayer;

  /// No description provided for @erreurChargement.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du chargement de la file'**
  String get erreurChargement;

  /// No description provided for @classeTitre.
  ///
  /// In fr, this message translates to:
  /// **'Classe {className}'**
  String classeTitre(String className);

  /// No description provided for @heureAppel.
  ///
  /// In fr, this message translates to:
  /// **'Appelé à {time}'**
  String heureAppel(String time);

  /// No description provided for @reconnexionReussie.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion réussie — file resynchronisée'**
  String get reconnexionReussie;

  /// No description provided for @enDirect.
  ///
  /// In fr, this message translates to:
  /// **'En direct'**
  String get enDirect;

  /// No description provided for @reconnexionEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion...'**
  String get reconnexionEnCours;

  /// No description provided for @miseAJourEnCours.
  ///
  /// In fr, this message translates to:
  /// **'Mise à jour en cours...'**
  String get miseAJourEnCours;

  /// No description provided for @statutPrevenu.
  ///
  /// In fr, this message translates to:
  /// **'Prévenu'**
  String get statutPrevenu;

  /// No description provided for @sansClasse.
  ///
  /// In fr, this message translates to:
  /// **'Sans classe'**
  String get sansClasse;

  /// No description provided for @boutonParti.
  ///
  /// In fr, this message translates to:
  /// **'Parti'**
  String get boutonParti;

  /// No description provided for @erreurDepart.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du départ de l\'élève'**
  String get erreurDepart;

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sortie d\'école — App école'**
  String get appTitle;
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
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
