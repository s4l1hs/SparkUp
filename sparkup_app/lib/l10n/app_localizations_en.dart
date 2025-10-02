// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get marketWatcher => 'Market Watcher';

  @override
  String get instantMarketAlarms => 'Instant market alarms';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get followedAlarms => 'Followed Alarms';

  @override
  String get noAlarmsYet => 'No alarms have been set yet.';

  @override
  String get setAlarm => 'Set';

  @override
  String get watchMarkets => 'Watch Markets';

  @override
  String get settings => 'Settings';

  @override
  String get general => 'General';

  @override
  String get applicationLanguage => 'Application Language';

  @override
  String get notifications => 'Notifications';

  @override
  String get forAllAlarms => 'For all alarms';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign Out';

  @override
  String get language => 'English';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get symbol => 'Symbol';

  @override
  String get name => 'Name';

  @override
  String get price => 'Price';

  @override
  String get noDataFound => 'No data found';

  @override
  String get theAlarmHasNotBeenSetYet => 'The alarm has not been set yet.';

  @override
  String get selectMarket => 'Select Market';

  @override
  String get selectSymbol => 'Select Symbol';

  @override
  String get selectChangePercent => 'Select Change %';

  @override
  String get editAlarm => 'Edit Alarm';

  @override
  String get watchMarket => 'Watch Market';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get crypto => 'CRYPTO';

  @override
  String get metals => 'METALS';

  @override
  String get noData => 'No Data';

  @override
  String get pleaseSignInFirst => 'Please sign in first';

  @override
  String get couldNotGetNotificationToken =>
      'Could not get notification token. Please try again.';

  @override
  String alarmAlreadyExists(Object displaySymbol, Object market) {
    return 'Alarm already exists for $displaySymbol in $market';
  }

  @override
  String marketSymbolsCouldNotBeLoaded(Object market) {
    return '$market symbols could not be loaded.';
  }

  @override
  String get noMarketDataFound => 'No Market Data Found';

  @override
  String get watchMarketChart => 'Watch Market 📈';

  @override
  String get gram => 'Gram';

  @override
  String get metalGold => 'Gold';

  @override
  String get metalSilver => 'Silver';

  @override
  String get metalCopper => 'Copper';
}
