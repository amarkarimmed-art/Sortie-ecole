// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get ecranSurveillanceTitre => 'Surveillance des sorties';

  @override
  String get chargementFile => 'Chargement de la file...';

  @override
  String get aucunEleveAppele => 'Aucun élève appelé pour le moment';

  @override
  String get reessayer => 'Réessayer';

  @override
  String get erreurChargement => 'Erreur lors du chargement de la file';

  @override
  String classeTitre(String className) {
    return 'Classe $className';
  }

  @override
  String heureAppel(String time) {
    return 'Appelé à $time';
  }

  @override
  String get reconnexionReussie => 'Reconnexion réussie — file resynchronisée';
}
