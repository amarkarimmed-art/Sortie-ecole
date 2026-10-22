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

  @override
  String get enDirect => 'En direct';

  @override
  String get reconnexionEnCours => 'Reconnexion...';

  @override
  String get miseAJourEnCours => 'Mise à jour en cours...';

  @override
  String get statutPrevenu => 'Prévenu';

  @override
  String get sansClasse => 'Sans classe';

  @override
  String get boutonParti => 'Parti';

  @override
  String get erreurDepart => 'Erreur lors du départ de l\'élève';

  @override
  String get appTitle => 'Sortie d\'école — App école';

  @override
  String get loginTitre => 'Connexion Espace École';

  @override
  String get loginSousTitre =>
      'Portail d\'accueil et surveillance des sorties d\'élèves';

  @override
  String get loginBadgePersonnel => 'Personnel scolaire';

  @override
  String get loginIdentifiantLabel => 'Identifiant / Login';

  @override
  String get loginIdentifiantHint => 'ex. surveillant@alamal';

  @override
  String get loginMotDePasseLabel => 'Mot de passe';

  @override
  String get loginMotDePasseHint => 'Votre mot de passe';

  @override
  String get loginBoutonSeConnecter => 'Se connecter';

  @override
  String get loginErreurIdentifiantRequis =>
      'Veuillez saisir votre identifiant';

  @override
  String get loginErreurMotDePasseRequis =>
      'Veuillez saisir votre mot de passe';

  @override
  String get loginErreurIdentifiantsIncorrects =>
      'Login ou mot de passe incorrect';

  @override
  String get loginErreurEcoleSuspendue =>
      'École suspendue, contactez l\'administration';

  @override
  String get loginErreurRoleNonAutorise =>
      'Accès réservé aux surveillants et agents d\'accueil';

  @override
  String get loginErreurTropDeTentatives =>
      'Trop de tentatives, réessayez dans une minute';

  @override
  String get deconnexion => 'Déconnexion';

  @override
  String get loginNumeroLabel => 'Numéro de téléphone';

  @override
  String get loginNumeroHint => '6 12 34 56 78';

  @override
  String get loginIndicatifMaroc => '+212';

  @override
  String get loginAideSaisie =>
      'Saisissez votre numéro de mobile professionnel';

  @override
  String get loginBoutonEnvoyer => 'Recevoir le code SMS';

  @override
  String get loginErreurTelephoneRequis =>
      'Veuillez saisir votre numéro de téléphone';

  @override
  String get loginErreurTelephoneInvalide =>
      'Numéro de téléphone invalide (format attendu : 06/07XXXXXXXX)';

  @override
  String get loginTitreOtp => 'Vérification du code SMS';

  @override
  String loginSousTitreOtp(String phone) {
    return 'Saisissez le code secret à 6 chiffres envoyé au $phone';
  }

  @override
  String get loginOtpLabel => 'Code de vérification';

  @override
  String get loginOtpHint => '000000';

  @override
  String get loginBoutonValider => 'Valider et se connecter';

  @override
  String get loginBoutonModifierNumero => 'Modifier le numéro';

  @override
  String get loginBoutonRenvoyer => 'Renvoyer le code';

  @override
  String loginRenvoyerDans(int seconds) {
    return 'Renvoyer dans ${seconds}s';
  }

  @override
  String get loginErreurOtpRequis => 'Veuillez saisir le code à 6 chiffres';

  @override
  String get loginErreurOtpInvalide =>
      'Le code doit comporter exactement 6 chiffres';

  @override
  String get loginErreurOtpEchoue =>
      'Code SMS incorrect ou expiré. Veuillez réessayer.';

  @override
  String get loginErreurUtilisateurIntrouvable =>
      'Utilisateur introuvable. Veuillez contacter l\'administration de l\'établissement.';

  @override
  String get loginErreurReseau =>
      'Erreur de connexion. Vérifiez votre réseau internet.';

  @override
  String get loginBadgeSecurite =>
      'Conforme CNDP & Loi 09-08 — Données protégées';

  @override
  String get loginSucces => 'Connexion réussie. Bienvenue !';

  @override
  String get loginChangerLangue => 'Changer la langue';

  @override
  String get roleSurveillant => 'Surveillant';

  @override
  String get roleAgent => 'Agent d\'accueil';

  @override
  String get roleDirection => 'Direction';

  @override
  String get dansLePerimetre => 'Dans le périmètre';

  @override
  String get enApproche => 'En approche';

  @override
  String sortieEnCours(String time) {
    return 'Sortie en cours jusqu\'à $time';
  }

  @override
  String get sortieFermee => 'Sortie fermée';

  @override
  String sortieCommenceA(String time) {
    return 'Sortie fermée, prochaine ouverture à $time';
  }

  @override
  String nouvelleArrivee(String name) {
    return 'Nouvelle arrivée : $name';
  }

  @override
  String parentLabel(String name) {
    return 'Parent : $name';
  }
}
