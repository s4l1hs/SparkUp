// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get marketWatcher => 'Наблюдатель за рынком';

  @override
  String get instantMarketAlarms => 'Мгновенные рыночные оповещения';

  @override
  String get continueWithGoogle => 'Продолжить через Google';

  @override
  String get followedAlarms => 'Отслеживаемые оповещения';

  @override
  String get noAlarmsYet => 'Оповещения ещё не установлены.';

  @override
  String get setAlarm => 'Установить';

  @override
  String get watchMarkets => 'Следить за рынками';

  @override
  String get settings => 'Настройки';

  @override
  String get general => 'Общие';

  @override
  String get applicationLanguage => 'Язык приложения';

  @override
  String get notifications => 'Уведомления';

  @override
  String get forAllAlarms => 'Для всех оповещений';

  @override
  String get account => 'Аккаунт';

  @override
  String get signOut => 'Выйти';

  @override
  String get language => 'Русский';

  @override
  String get selectLanguage => 'Выбрать язык';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Редактировать';

  @override
  String get save => 'Сохранить';

  @override
  String get symbol => 'Символ';

  @override
  String get name => 'Имя';

  @override
  String get price => 'Цена';

  @override
  String get noDataFound => 'Данные не найдены';

  @override
  String get theAlarmHasNotBeenSetYet => 'Оповещение ещё не установлено.';

  @override
  String get selectMarket => 'Выбрать рынок';

  @override
  String get selectSymbol => 'Выбрать символ';

  @override
  String get selectChangePercent => 'Выбрать изменение %';

  @override
  String get editAlarm => 'Редактировать оповещение';

  @override
  String get watchMarket => 'Следить за рынком';

  @override
  String get signInWithGoogle => 'Войти через Google';

  @override
  String get crypto => 'КРИПТО';

  @override
  String get metals => 'МЕТАЛЛЫ';

  @override
  String get noData => 'Нет данных';

  @override
  String get pleaseSignInFirst => 'Пожалуйста, сначала войдите';

  @override
  String get couldNotGetNotificationToken =>
      'Не удалось получить токен уведомлений. Попробуйте снова.';

  @override
  String alarmAlreadyExists(Object displaySymbol, Object market) {
    return 'Оповещение для $displaySymbol на $market уже существует';
  }

  @override
  String marketSymbolsCouldNotBeLoaded(Object market) {
    return 'Не удалось загрузить символы $market.';
  }

  @override
  String get noMarketDataFound => 'Рыночные данные не найдены';

  @override
  String get watchMarketChart => 'Следить за рынком 📈';

  @override
  String get gram => 'Грамм';

  @override
  String get metalGold => 'Золото';

  @override
  String get metalSilver => 'Серебро';

  @override
  String get metalCopper => 'Медь';
}
