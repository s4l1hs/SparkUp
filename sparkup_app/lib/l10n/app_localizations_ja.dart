// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get marketWatcher => 'マーケットウォッチャー';

  @override
  String get instantMarketAlarms => '即時マーケットアラーム';

  @override
  String get continueWithGoogle => 'Googleで続行';

  @override
  String get followedAlarms => 'フォロー中のアラーム';

  @override
  String get noAlarmsYet => 'まだアラームが設定されていません。';

  @override
  String get setAlarm => '設定';

  @override
  String get watchMarkets => 'マーケットを監視';

  @override
  String get settings => '設定';

  @override
  String get general => '一般';

  @override
  String get applicationLanguage => 'アプリの言語';

  @override
  String get notifications => '通知';

  @override
  String get forAllAlarms => 'すべてのアラームに対して';

  @override
  String get account => 'アカウント';

  @override
  String get signOut => 'ログアウト';

  @override
  String get language => '日本語';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get edit => '編集';

  @override
  String get save => '保存';

  @override
  String get symbol => 'シンボル';

  @override
  String get name => '名前';

  @override
  String get price => '価格';

  @override
  String get noDataFound => 'データが見つかりません';

  @override
  String get theAlarmHasNotBeenSetYet => 'アラームはまだ設定されていません。';

  @override
  String get selectMarket => 'マーケットを選択';

  @override
  String get selectSymbol => 'シンボルを選択';

  @override
  String get selectChangePercent => '変化率 % を選択';

  @override
  String get editAlarm => 'アラームを編集';

  @override
  String get watchMarket => 'マーケットを監視';

  @override
  String get signInWithGoogle => 'Googleでログイン';

  @override
  String get crypto => '暗号資産';

  @override
  String get metals => '金属';

  @override
  String get noData => 'データなし';

  @override
  String get pleaseSignInFirst => 'まずサインインしてください';

  @override
  String get couldNotGetNotificationToken => '通知トークンを取得できませんでした。再試行してください。';

  @override
  String alarmAlreadyExists(Object displaySymbol, Object market) {
    return '$market に $displaySymbol のアラームはすでに存在します';
  }

  @override
  String marketSymbolsCouldNotBeLoaded(Object market) {
    return '$market のシンボルを読み込めませんでした。';
  }

  @override
  String get noMarketDataFound => 'マーケットデータが見つかりません';

  @override
  String get watchMarketChart => 'マーケットを監視 📈';

  @override
  String get gram => 'グラム';

  @override
  String get metalGold => 'ゴールド';

  @override
  String get metalSilver => '銀';

  @override
  String get metalCopper => '銅';
}
