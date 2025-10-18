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

  /// No description provided for @dailyFact.
  ///
  /// In en, this message translates to:
  /// **'Daily Fact'**
  String get dailyFact;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @tapToLoadNewChallenge.
  ///
  /// In en, this message translates to:
  /// **'Tap to load a new challenge'**
  String get tapToLoadNewChallenge;

  /// No description provided for @noChallengeAvailable.
  ///
  /// In en, this message translates to:
  /// **'No new challenge available.'**
  String get noChallengeAvailable;

  /// No description provided for @challengeCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Challenge could not be loaded.'**
  String get challengeCouldNotBeLoaded;

  /// No description provided for @startNewQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start New Quiz'**
  String get startNewQuiz;

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

  /// No description provided for @great.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get great;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @quizCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'Quiz could not start'**
  String get quizCouldNotStart;

  /// No description provided for @questionDataIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Question data is empty.'**
  String get questionDataIsEmpty;

  /// No description provided for @navMainMenu.
  ///
  /// In en, this message translates to:
  /// **'Main Menu'**
  String get navMainMenu;

  /// No description provided for @navInfo.
  ///
  /// In en, this message translates to:
  /// **'Fact'**
  String get navInfo;

  /// No description provided for @navQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get navQuiz;

  /// No description provided for @navChallenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get navChallenge;

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

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @infoNotFound.
  ///
  /// In en, this message translates to:
  /// **'Knowledge not found for your preferred topics.'**
  String get infoNotFound;

  /// No description provided for @selectYourInterests.
  ///
  /// In en, this message translates to:
  /// **'Select Your Interests'**
  String get selectYourInterests;

  /// No description provided for @preferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences saved successfully!'**
  String get preferencesSaved;

  /// No description provided for @preferencesCouldNotBeSaved.
  ///
  /// In en, this message translates to:
  /// **'Preferences could not be saved.'**
  String get preferencesCouldNotBeSaved;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get saving;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

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

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @noDataFound.
  ///
  /// In en, this message translates to:
  /// **'No data found'**
  String get noDataFound;

  /// No description provided for @navLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get navLeaderboard;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action is irreversible and all your data, including your score, will be permanently lost.'**
  String get deleteAccountConfirmation;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

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

  /// No description provided for @errorCouldNotSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Could not save changes'**
  String get errorCouldNotSaveChanges;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get selected;

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

  /// No description provided for @subscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptions;

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

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

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

  /// No description provided for @subscriptionNote.
  ///
  /// In en, this message translates to:
  /// **'This is a purchase simulation. Must be integrated with a real payment system.'**
  String get subscriptionNote;

  /// No description provided for @limitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Limit Exceeded'**
  String get limitExceeded;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @streakBonus.
  ///
  /// In en, this message translates to:
  /// **'Streak Bonus'**
  String get streakBonus;

  /// No description provided for @maxStreak.
  ///
  /// In en, this message translates to:
  /// **'Max Streak'**
  String get maxStreak;

  /// No description provided for @streakBroken.
  ///
  /// In en, this message translates to:
  /// **'Streak Broken'**
  String get streakBroken;

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

  /// No description provided for @errorSubmittingAnswer.
  ///
  /// In en, this message translates to:
  /// **'Error submitting answer.'**
  String get errorSubmittingAnswer;

  /// No description provided for @wrongAnswerResetStreak.
  ///
  /// In en, this message translates to:
  /// **'Wrong answer! Streak reset.'**
  String get wrongAnswerResetStreak;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

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

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

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

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @failedToSaveName.
  ///
  /// In en, this message translates to:
  /// **'Failed to save name'**
  String get failedToSaveName;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @enterValidName.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid name'**
  String get enterValidName;

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

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get pleaseWait;

  /// No description provided for @challenge.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get challenge;

  /// No description provided for @hintTapToReload.
  ///
  /// In en, this message translates to:
  /// **'Tap to reload'**
  String get hintTapToReload;

  /// No description provided for @loadNewChallenge.
  ///
  /// In en, this message translates to:
  /// **'Load new challenge'**
  String get loadNewChallenge;

  /// No description provided for @challengeIntro.
  ///
  /// In en, this message translates to:
  /// **'Get short, engaging creative challenges to boost your skills.'**
  String get challengeIntro;

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
