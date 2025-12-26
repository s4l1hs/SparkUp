// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Spark Up';

  @override
  String get appSlogan =>
      'Votre dose quotidienne de connaissances, de défis et de quiz.';

  @override
  String get dailyFact => 'Fait quotidien';

  @override
  String get source => 'Source';

  @override
  String get tapToLoadNewChallenge => 'Appuyez pour charger un nouveau défi';

  @override
  String get noChallengeAvailable => 'Aucun nouveau défi disponible.';

  @override
  String get challengeCouldNotBeLoaded => 'Le défi n\'a pas pu être chargé.';

  @override
  String get startNewQuiz => 'Commencer un nouveau quiz';

  @override
  String get startWithOneBolt => 'Commencer avec 1 ⚡';

  @override
  String get energyLabel => 'Énergie';

  @override
  String get quizFinished => 'Quiz terminé!';

  @override
  String get yourScore => 'Votre score';

  @override
  String get trueFalseTitle => 'Vrai / Faux';

  @override
  String get startTrueFalseProblems => 'Démarrer Vrai/Faux';

  @override
  String get trueLabel => 'Vrai';

  @override
  String get falseLabel => 'Faux';

  @override
  String get categoryLabel => 'Catégorie';

  @override
  String get great => 'Génial!';

  @override
  String get question => 'Question';

  @override
  String get quizCouldNotStart => 'Le quiz n\'a pas pu démarrer';

  @override
  String get questionDataIsEmpty => 'Les données du quiz sont vides.';

  @override
  String get navMainMenu => 'Sujets';

  @override
  String get navInfo => 'Fait';

  @override
  String get navQuiz => 'Quiz';

  @override
  String get navChallenge => 'Défi';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get loginFailedMessage =>
      'Échec de la connexion. Veuillez vérifier votre réseau et réessayer.';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get infoNotFound =>
      'Aucune connaissance trouvée pour vos sujets préférés.';

  @override
  String get selectYourInterests => 'Sélectionnez vos intérêts';

  @override
  String get preferencesSaved => 'Préférences enregistrées avec succès!';

  @override
  String get preferencesCouldNotBeSaved =>
      'Les préférences n\'ont pas pu être enregistrées.';

  @override
  String get error => 'Erreur';

  @override
  String get saving => 'Sauvegarde';

  @override
  String get settings => 'Paramètres';

  @override
  String get general => 'Général';

  @override
  String get applicationLanguage => 'Langue de l\'application';

  @override
  String get notifications => 'Notifications';

  @override
  String get forAllAlarms => 'Pour tous les faits et défis';

  @override
  String get account => 'Compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get language => 'Français';

  @override
  String get selectLanguage => 'Sélectionner la langue';

  @override
  String get refresh => 'Actualiser';

  @override
  String get noDataFound => 'Aucune donnée trouvée';

  @override
  String get navLeaderboard => 'Classement';

  @override
  String get deleteAccount => 'Supprimer le compte';

  @override
  String get deleteAccountConfirmation =>
      'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible et toutes vos données, y compris votre score, seront définitivement perdues.';

  @override
  String get delete => 'Supprimer';

  @override
  String get signOutConfirmation =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get noDataAvailable => 'Aucune donnée disponible';

  @override
  String get errorCouldNotSaveChanges =>
      'Impossible d\'enregistrer les modifications';

  @override
  String get selected => 'sélectionné';

  @override
  String get yourRank => 'Votre Rang';

  @override
  String get rankMaster => 'Maître';

  @override
  String get rankDiamond => 'Diamant';

  @override
  String get rankGold => 'Or';

  @override
  String get rankSilver => 'Argent';

  @override
  String get rankBronze => 'Bronze';

  @override
  String get rankIron => 'Fer';

  @override
  String get subscriptions => 'Abonnements';

  @override
  String get chooseYourPlan => 'Choisissez votre plan';

  @override
  String get planFree => 'Plan Gratuit';

  @override
  String get planPro => 'Plan Pro';

  @override
  String get planUltra => 'Plan Ultra';

  @override
  String get free => 'Gratuit';

  @override
  String get month => 'Mois';

  @override
  String get questionsPerDay => 'Questions/Jour';

  @override
  String get challengesPerDay => 'Défis/Jour';

  @override
  String get notificationPerDay => 'Notification/Jour';

  @override
  String get notificationsPerDay => 'Notifications/Jour';

  @override
  String get unlimitedQuizzes => 'Quizz Illimités';

  @override
  String get unlimitedChallenges => 'Défis Illimités';

  @override
  String get purchaseSuccess => 'Abonnement mis à jour avec succès.';

  @override
  String get purchaseError => 'Achat échoué';

  @override
  String get current => 'Actuel';

  @override
  String get active => 'Actif';

  @override
  String get freeTrial => 'Niveau Gratuit';

  @override
  String get upgrade => 'Mise à niveau';

  @override
  String get subscriptionNote =>
      'Ceci est une simulation d\'achat. Doit être intégré à un véritable système de paiement.';

  @override
  String get limitExceeded => 'Limite Dépassée';

  @override
  String get insufficientEnergy => 'Énergie insuffisante ⚡';

  @override
  String get streak => 'Série';

  @override
  String streakBonus(Object streak) {
    return 'Bonus de série x$streak';
  }

  @override
  String get maxStreak => 'Série Max';

  @override
  String get streakBroken => 'Série Rompue';

  @override
  String get points => 'Points';

  @override
  String get pointsEarned => 'Points Gagnés';

  @override
  String get pointsPerQuestion => 'points par question';

  @override
  String get errorSubmittingAnswer => 'Erreur lors de l\'envoi de la réponse.';

  @override
  String get wrongAnswerResetStreak =>
      'Mauvaise réponse ! Série réinitialisée.';

  @override
  String get correct => 'Correct';

  @override
  String get incorrect => 'Incorrect';

  @override
  String get unstoppable => 'INARRÊTABLE 🔥';

  @override
  String livesLeft(Object count) {
    return 'Il reste $count vies';
  }

  @override
  String pointsGain(Object points) {
    return '+$points Points';
  }

  @override
  String streakBonusFire(Object streak) {
    return 'Bonus de série x$streak 🔥';
  }

  @override
  String get errorCouldNotLoadData => 'Impossible de charger les données.';

  @override
  String get topPlayers => 'Meilleurs joueurs';

  @override
  String get yourName => 'Votre nom';

  @override
  String get changeLanguage => 'Changer la langue';

  @override
  String get memberSince => 'Membre depuis';

  @override
  String get anonymous => 'Anonyme';

  @override
  String get help => 'Aide';

  @override
  String get failedToSaveName => 'Impossible d\'enregistrer le nom';

  @override
  String get saved => 'Enregistré';

  @override
  String get enterValidName => 'Entrez un nom valide';

  @override
  String get failedToSaveNotification =>
      'Impossible d\'enregistrer la notification';

  @override
  String get failedToSaveLanguage => 'Impossible d\'enregistrer la langue';

  @override
  String get failedToLoadProfile => 'Échec du chargement du profil';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get loading => 'Chargement';

  @override
  String get pleaseWait => 'Veuillez patienter';

  @override
  String get challenge => 'Défi';

  @override
  String get hintTapToReload => 'Appuyez pour recharger';

  @override
  String get loadNewChallenge => 'Charger un nouveau défi';

  @override
  String get challengeIntro =>
      'Recevez de courtes missions engageantes pour stimuler vos compétences.';

  @override
  String get leaderboard => 'Classement';

  @override
  String get limited => 'Limité';

  @override
  String get category_history => 'Histoire';

  @override
  String get category_science => 'Science';

  @override
  String get category_art => 'Art';

  @override
  String get category_sports => 'Sports';

  @override
  String get category_technology => 'Technologie';

  @override
  String get category_cinema_tv => 'Cinéma / TV';

  @override
  String get category_music => 'Musique';

  @override
  String get category_nature_animals => 'Nature et Animaux';

  @override
  String get category_geography_travel => 'Géographie et Voyages';

  @override
  String get category_mythology => 'Mythologie';

  @override
  String get category_philosophy => 'Philosophie';

  @override
  String get category_literature => 'Littérature';

  @override
  String get category_space_astronomy => 'Espace et Astronomie';

  @override
  String get category_health_fitness => 'Santé et Fitness';

  @override
  String get category_economics_finance => 'Économie et Finances';

  @override
  String get category_architecture => 'Architecture';

  @override
  String get category_video_games => 'Jeux Vidéo';

  @override
  String get category_general_culture => 'Culture Générale';

  @override
  String get category_fun_facts => 'Anecdotes';

  @override
  String get performance_title => 'Performance';

  @override
  String get performance_subtitle => 'Suivez vos progrès et améliorez-vous.';

  @override
  String get overall_score => 'Score global';

  @override
  String get category_breakdown => 'Répartition par catégorie';

  @override
  String get no_data_available_yet =>
      'Aucune donnée disponible pour l\'instant';

  @override
  String get correct_label => 'Correct';

  @override
  String get excellent_job => 'Excellent ! 🚀';

  @override
  String get keep_pushing => 'Continuez comme ça ! 💪';
}
