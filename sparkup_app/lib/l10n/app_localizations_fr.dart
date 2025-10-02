// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get marketWatcher => 'Surveillant de Marché';

  @override
  String get instantMarketAlarms => 'Alertes de marché instantanées';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get followedAlarms => 'Alertes suivies';

  @override
  String get noAlarmsYet => 'Aucune alerte n\'a encore été définie.';

  @override
  String get setAlarm => 'Définir';

  @override
  String get watchMarkets => 'Surveiller les marchés';

  @override
  String get settings => 'Paramètres';

  @override
  String get general => 'Général';

  @override
  String get applicationLanguage => 'Langue de l\'application';

  @override
  String get notifications => 'Notifications';

  @override
  String get forAllAlarms => 'Pour toutes les alertes';

  @override
  String get account => 'Compte';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get language => 'Français';

  @override
  String get selectLanguage => 'Choisir la langue';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get save => 'Enregistrer';

  @override
  String get symbol => 'Symbole';

  @override
  String get name => 'Nom';

  @override
  String get price => 'Prix';

  @override
  String get noDataFound => 'Aucune donnée trouvée';

  @override
  String get theAlarmHasNotBeenSetYet => 'L’alerte n’a pas encore été définie.';

  @override
  String get selectMarket => 'Sélectionner le marché';

  @override
  String get selectSymbol => 'Sélectionner le symbole';

  @override
  String get selectChangePercent => 'Sélectionner le changement %';

  @override
  String get editAlarm => 'Modifier l’alerte';

  @override
  String get watchMarket => 'Surveiller le marché';

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String get crypto => 'CRYPTO';

  @override
  String get metals => 'MÉTAUX';

  @override
  String get noData => 'Aucune donnée';

  @override
  String get pleaseSignInFirst => 'Veuillez d’abord vous connecter';

  @override
  String get couldNotGetNotificationToken =>
      'Impossible d’obtenir le jeton de notification. Veuillez réessayer.';

  @override
  String alarmAlreadyExists(Object displaySymbol, Object market) {
    return 'Une alerte existe déjà pour $displaySymbol dans $market';
  }

  @override
  String marketSymbolsCouldNotBeLoaded(Object market) {
    return 'Les symboles $market n’ont pas pu être chargés.';
  }

  @override
  String get noMarketDataFound => 'Aucune donnée de marché trouvée';

  @override
  String get watchMarketChart => 'Surveiller le marché 📈';

  @override
  String get gram => 'Gramme';

  @override
  String get metalGold => 'Or';

  @override
  String get metalSilver => 'Argent';

  @override
  String get metalCopper => 'Cuivre';
}
