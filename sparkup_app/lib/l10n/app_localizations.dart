import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('ja'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Spark Up'**
  String get appName;

  /// No description provided for @appSlogan.
  ///
  /// In en, this message translates to:
  /// **'Your daily dose of knowledge, challenge, and quiz.'**
  String get appSlogan;

  /// No description provided for @startNewQuiz.
  ///
  /// In en, this message translates to:
  /// **'Brain Quiz'**
  String get startNewQuiz;

  /// No description provided for @startNewQuizSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show your genius 🔥'**
  String get startNewQuizSubtitle;

  /// No description provided for @startWithOneBolt.
  ///
  /// In en, this message translates to:
  /// **'Start with 1 ⚡'**
  String get startWithOneBolt;

  /// No description provided for @energyLabel.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get energyLabel;

  /// No description provided for @quizFinished.
  ///
  /// In en, this message translates to:
  /// **'Quiz Finished!'**
  String get quizFinished;

  /// No description provided for @yourScore.
  ///
  /// In en, this message translates to:
  /// **'Your Score'**
  String get yourScore;

  /// No description provided for @trueFalseTitle.
  ///
  /// In en, this message translates to:
  /// **'True / False'**
  String get trueFalseTitle;

  /// No description provided for @startTrueFalseProblems.
  ///
  /// In en, this message translates to:
  /// **'True/False Test'**
  String get startTrueFalseProblems;

  /// No description provided for @startTrueFalseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Think fast and win 🔥'**
  String get startTrueFalseSubtitle;

  /// No description provided for @trueLabel.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get trueLabel;

  /// No description provided for @falseLabel.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get falseLabel;

  /// No description provided for @great.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get great;

  /// No description provided for @quizCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Quiz could not start'**
  String get quizCouldNotStart;

  /// No description provided for @navMainMenu.
  ///
  /// In en, this message translates to:
  /// **'Main Menu'**
  String get navMainMenu;

  /// No description provided for @navQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get navQuiz;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @loginFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please check your network and try again.'**
  String get loginFailedMessage;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @applicationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Application Language'**
  String get applicationLanguage;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @forAllAlarms.
  ///
  /// In en, this message translates to:
  /// **'For all facts and challenges'**
  String get forAllAlarms;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @signOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmation;

  /// No description provided for @noDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noDataAvailable;

  /// No description provided for @yourRank.
  ///
  /// In en, this message translates to:
  /// **'Your Rank'**
  String get yourRank;

  /// No description provided for @rankMaster.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get rankMaster;

  /// No description provided for @rankDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get rankDiamond;

  /// No description provided for @rankGold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get rankGold;

  /// No description provided for @rankSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get rankSilver;

  /// No description provided for @rankBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get rankBronze;

  /// No description provided for @rankIron.
  ///
  /// In en, this message translates to:
  /// **'Iron'**
  String get rankIron;

  /// No description provided for @chooseYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Plan'**
  String get chooseYourPlan;

  /// No description provided for @planFree.
  ///
  /// In en, this message translates to:
  /// **'Free Plan'**
  String get planFree;

  /// No description provided for @planPro.
  ///
  /// In en, this message translates to:
  /// **'Pro Plan'**
  String get planPro;

  /// No description provided for @planUltra.
  ///
  /// In en, this message translates to:
  /// **'Ultra Plan'**
  String get planUltra;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @questionsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Questions/Day'**
  String get questionsPerDay;

  /// No description provided for @challengesPerDay.
  ///
  /// In en, this message translates to:
  /// **'Challenges/Day'**
  String get challengesPerDay;

  /// No description provided for @notificationPerDay.
  ///
  /// In en, this message translates to:
  /// **'Notification/Day'**
  String get notificationPerDay;

  /// No description provided for @notificationsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Notifications/Day'**
  String get notificationsPerDay;

  /// No description provided for @unlimitedQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Quizzes'**
  String get unlimitedQuizzes;

  /// No description provided for @unlimitedChallenges.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Challenges'**
  String get unlimitedChallenges;

  /// No description provided for @purchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Subscription successfully updated.'**
  String get purchaseSuccess;

  /// No description provided for @purchaseError.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed'**
  String get purchaseError;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @freeTrial.
  ///
  /// In en, this message translates to:
  /// **'Free Tier'**
  String get freeTrial;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @insufficientEnergy.
  ///
  /// In en, this message translates to:
  /// **'Insufficient energy ⚡'**
  String get insufficientEnergy;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @pointsEarned.
  ///
  /// In en, this message translates to:
  /// **'Points Earned'**
  String get pointsEarned;

  /// No description provided for @pointsPerQuestion.
  ///
  /// In en, this message translates to:
  /// **'points per question'**
  String get pointsPerQuestion;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get incorrect;

  /// No description provided for @secondsSuffix.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get secondsSuffix;

  /// No description provided for @unstoppable.
  ///
  /// In en, this message translates to:
  /// **'UNSTOPPABLE 🔥'**
  String get unstoppable;

  /// No description provided for @errorCouldNotLoadData.
  ///
  /// In en, this message translates to:
  /// **'Could not load data.'**
  String get errorCouldNotLoadData;

  /// No description provided for @topPlayers.
  ///
  /// In en, this message translates to:
  /// **'Top Players'**
  String get topPlayers;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSince;

  /// No description provided for @anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get anonymous;

  /// No description provided for @failedToSaveNotification.
  ///
  /// In en, this message translates to:
  /// **'Failed to save notification setting'**
  String get failedToSaveNotification;

  /// No description provided for @failedToSaveLanguage.
  ///
  /// In en, this message translates to:
  /// **'Failed to save language'**
  String get failedToSaveLanguage;

  /// No description provided for @failedToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get failedToLoadProfile;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// No description provided for @limited.
  ///
  /// In en, this message translates to:
  /// **'Limited'**
  String get limited;

  /// No description provided for @category_history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get category_history;

  /// No description provided for @category_science.
  ///
  /// In en, this message translates to:
  /// **'Science'**
  String get category_science;

  /// No description provided for @category_art.
  ///
  /// In en, this message translates to:
  /// **'Art'**
  String get category_art;

  /// No description provided for @category_sports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get category_sports;

  /// No description provided for @category_technology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get category_technology;

  /// No description provided for @category_cinema_tv.
  ///
  /// In en, this message translates to:
  /// **'Cinema & TV'**
  String get category_cinema_tv;

  /// No description provided for @category_music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get category_music;

  /// No description provided for @category_nature_animals.
  ///
  /// In en, this message translates to:
  /// **'Nature & Animals'**
  String get category_nature_animals;

  /// No description provided for @category_geography_travel.
  ///
  /// In en, this message translates to:
  /// **'Geography & Travel'**
  String get category_geography_travel;

  /// No description provided for @category_mythology.
  ///
  /// In en, this message translates to:
  /// **'Mythology'**
  String get category_mythology;

  /// No description provided for @category_philosophy.
  ///
  /// In en, this message translates to:
  /// **'Philosophy'**
  String get category_philosophy;

  /// No description provided for @category_literature.
  ///
  /// In en, this message translates to:
  /// **'Literature'**
  String get category_literature;

  /// No description provided for @category_space_astronomy.
  ///
  /// In en, this message translates to:
  /// **'Space & Astronomy'**
  String get category_space_astronomy;

  /// No description provided for @category_health_fitness.
  ///
  /// In en, this message translates to:
  /// **'Health & Fitness'**
  String get category_health_fitness;

  /// No description provided for @category_economics_finance.
  ///
  /// In en, this message translates to:
  /// **'Economics & Finance'**
  String get category_economics_finance;

  /// No description provided for @category_architecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get category_architecture;

  /// No description provided for @category_video_games.
  ///
  /// In en, this message translates to:
  /// **'Video Games'**
  String get category_video_games;

  /// No description provided for @category_general_culture.
  ///
  /// In en, this message translates to:
  /// **'General Culture'**
  String get category_general_culture;

  /// No description provided for @category_fun_facts.
  ///
  /// In en, this message translates to:
  /// **'Fun Facts'**
  String get category_fun_facts;

  /// No description provided for @performance_title.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance_title;

  /// No description provided for @performance_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your progress and improve.'**
  String get performance_subtitle;

  /// No description provided for @overall_score.
  ///
  /// In en, this message translates to:
  /// **'Overall Score'**
  String get overall_score;

  /// No description provided for @category_breakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get category_breakdown;

  /// No description provided for @no_data_available_yet.
  ///
  /// In en, this message translates to:
  /// **'No data available yet'**
  String get no_data_available_yet;

  /// No description provided for @correct_label.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct_label;

  /// No description provided for @excellent_job.
  ///
  /// In en, this message translates to:
  /// **'Excellent Job! 🚀'**
  String get excellent_job;

  /// No description provided for @keep_pushing.
  ///
  /// In en, this message translates to:
  /// **'Keep Pushing! 💪'**
  String get keep_pushing;

  /// No description provided for @dart.
  ///
  /// In en, this message translates to:
  /// **'Dart'**
  String get dart;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @pointsGain.
  ///
  /// In en, this message translates to:
  /// **'{points} points!'**
  String pointsGain(Object points);

  /// No description provided for @livesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} lives left'**
  String livesLeft(Object count);

  /// No description provided for @streakBonus.
  ///
  /// In en, this message translates to:
  /// **'Streak bonus: {bonus}'**
  String streakBonus(Object bonus);

  /// No description provided for @streakBonusFire.
  ///
  /// In en, this message translates to:
  /// **'🔥 Streak bonus: {bonus}'**
  String streakBonusFire(Object bonus);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'de',
        'en',
        'es',
        'fr',
        'hi',
        'it',
        'ja',
        'ru',
        'tr',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
