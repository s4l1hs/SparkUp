// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get marketWatcher => 'Marktbeobachter';

  @override
  String get instantMarketAlarms => 'Sofortige Marktalarme';

  @override
  String get continueWithGoogle => 'Mit Google fortfahren';

  @override
  String get followedAlarms => 'Verfolgte Alarme';

  @override
  String get noAlarmsYet => 'Es wurden noch keine Alarme gesetzt.';

  @override
  String get setAlarm => 'Setzen';

  @override
  String get watchMarkets => 'Märkte beobachten';

  @override
  String get settings => 'Einstellungen';

  @override
  String get general => 'Allgemein';

  @override
  String get applicationLanguage => 'Anwendungssprache';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get forAllAlarms => 'Für alle Alarme';

  @override
  String get account => 'Konto';

  @override
  String get signOut => 'Abmelden';

  @override
  String get language => 'Deutsch';

  @override
  String get selectLanguage => 'Sprache auswählen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get save => 'Speichern';

  @override
  String get symbol => 'Symbol';

  @override
  String get name => 'Name';

  @override
  String get price => 'Preis';

  @override
  String get noDataFound => 'Keine Daten gefunden';

  @override
  String get theAlarmHasNotBeenSetYet => 'Der Alarm wurde noch nicht gesetzt.';

  @override
  String get selectMarket => 'Markt auswählen';

  @override
  String get selectSymbol => 'Symbol auswählen';

  @override
  String get selectChangePercent => 'Änderung % auswählen';

  @override
  String get editAlarm => 'Alarm bearbeiten';

  @override
  String get watchMarket => 'Markt beobachten';

  @override
  String get signInWithGoogle => 'Mit Google anmelden';

  @override
  String get crypto => 'KRYPTO';

  @override
  String get metals => 'METALLE';

  @override
  String get noData => 'Keine Daten';

  @override
  String get pleaseSignInFirst => 'Bitte zuerst anmelden';

  @override
  String get couldNotGetNotificationToken =>
      'Benachrichtigungstoken konnte nicht abgerufen werden. Bitte erneut versuchen.';

  @override
  String alarmAlreadyExists(Object displaySymbol, Object market) {
    return 'Alarm für $displaySymbol in $market existiert bereits';
  }

  @override
  String marketSymbolsCouldNotBeLoaded(Object market) {
    return '$market-Symbole konnten nicht geladen werden.';
  }

  @override
  String get noMarketDataFound => 'Keine Marktdaten gefunden';

  @override
  String get watchMarketChart => 'Markt beobachten 📈';

  @override
  String get gram => 'Gramm';

  @override
  String get metalGold => 'Gold';

  @override
  String get metalSilver => 'Silber';

  @override
  String get metalCopper => 'Kupfer';
}
