// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get marketWatcher => 'Osservatore di Mercato';

  @override
  String get instantMarketAlarms => 'Allarmi di mercato istantanei';

  @override
  String get continueWithGoogle => 'Continua con Google';

  @override
  String get followedAlarms => 'Allarmi seguiti';

  @override
  String get noAlarmsYet => 'Non sono ancora stati impostati allarmi.';

  @override
  String get setAlarm => 'Imposta';

  @override
  String get watchMarkets => 'Osserva i mercati';

  @override
  String get settings => 'Impostazioni';

  @override
  String get general => 'Generale';

  @override
  String get applicationLanguage => 'Lingua dell\'applicazione';

  @override
  String get notifications => 'Notifiche';

  @override
  String get forAllAlarms => 'Per tutti gli allarmi';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Disconnetti';

  @override
  String get language => 'Italiano';

  @override
  String get selectLanguage => 'Seleziona lingua';

  @override
  String get cancel => 'Annulla';

  @override
  String get delete => 'Elimina';

  @override
  String get edit => 'Modifica';

  @override
  String get save => 'Salva';

  @override
  String get symbol => 'Simbolo';

  @override
  String get name => 'Nome';

  @override
  String get price => 'Prezzo';

  @override
  String get noDataFound => 'Nessun dato trovato';

  @override
  String get theAlarmHasNotBeenSetYet =>
      'L’allarme non è ancora stato impostato.';

  @override
  String get selectMarket => 'Seleziona mercato';

  @override
  String get selectSymbol => 'Seleziona simbolo';

  @override
  String get selectChangePercent => 'Seleziona variazione %';

  @override
  String get editAlarm => 'Modifica allarme';

  @override
  String get watchMarket => 'Osserva mercato';

  @override
  String get signInWithGoogle => 'Accedi con Google';

  @override
  String get crypto => 'CRYPTO';

  @override
  String get metals => 'METALLI';

  @override
  String get noData => 'Nessun dato';

  @override
  String get pleaseSignInFirst => 'Accedi prima, per favore';

  @override
  String get couldNotGetNotificationToken =>
      'Impossibile ottenere il token di notifica. Riprova.';

  @override
  String alarmAlreadyExists(Object displaySymbol, Object market) {
    return 'Esiste già un allarme per $displaySymbol in $market';
  }

  @override
  String marketSymbolsCouldNotBeLoaded(Object market) {
    return 'Impossibile caricare i simboli di $market.';
  }

  @override
  String get noMarketDataFound => 'Nessun dato di mercato trovato';

  @override
  String get watchMarketChart => 'Osserva mercato 📈';

  @override
  String get gram => 'Grammo';

  @override
  String get metalGold => 'Oro';

  @override
  String get metalSilver => 'Argento';

  @override
  String get metalCopper => 'Rame';
}
