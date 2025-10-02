// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get marketWatcher => 'Piyasa Gözcüsü';

  @override
  String get instantMarketAlarms => 'Anlık piyasa alarmları';

  @override
  String get continueWithGoogle => 'Google ile devam et';

  @override
  String get followedAlarms => 'Takip Edilen Alarmlar';

  @override
  String get noAlarmsYet => 'Henüz alarm kurulmadı.';

  @override
  String get setAlarm => 'Kur';

  @override
  String get watchMarkets => 'Piyasaları Takip Et';

  @override
  String get settings => 'Ayarlar';

  @override
  String get general => 'Genel';

  @override
  String get applicationLanguage => 'Uygulama Dili';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get forAllAlarms => 'Tüm alarmlar için';

  @override
  String get account => 'Hesap';

  @override
  String get signOut => 'Çıkış Yap';

  @override
  String get language => 'Türkçe';

  @override
  String get selectLanguage => 'Dil Seç';

  @override
  String get cancel => 'İptal';

  @override
  String get delete => 'Sil';

  @override
  String get edit => 'Düzenle';

  @override
  String get save => 'Kaydet';

  @override
  String get symbol => 'Sembol';

  @override
  String get name => 'İsim';

  @override
  String get price => 'Fiyat';

  @override
  String get noDataFound => 'Veri bulunamadı';

  @override
  String get theAlarmHasNotBeenSetYet => 'Henüz alarm kurulmadı.';

  @override
  String get selectMarket => 'Piyasa Seç';

  @override
  String get selectSymbol => 'Sembol Seç';

  @override
  String get selectChangePercent => 'Değişim % Seç';

  @override
  String get editAlarm => 'Alarmı Düzenle';

  @override
  String get watchMarket => 'Piyasayı Takip Et';

  @override
  String get signInWithGoogle => 'Google ile giriş yap';

  @override
  String get crypto => 'KRİPTO';

  @override
  String get metals => 'METALLER';

  @override
  String get noData => 'Veri Yok';

  @override
  String get pleaseSignInFirst => 'Lütfen önce giriş yapın';

  @override
  String get couldNotGetNotificationToken =>
      'Bildirim anahtarı alınamadı. Lütfen tekrar deneyin.';

  @override
  String alarmAlreadyExists(Object displaySymbol, Object market) {
    return '$market içinde $displaySymbol için alarm zaten mevcut';
  }

  @override
  String marketSymbolsCouldNotBeLoaded(Object market) {
    return '$market sembolleri yüklenemedi.';
  }

  @override
  String get noMarketDataFound => 'Piyasa verisi bulunamadı';

  @override
  String get watchMarketChart => 'Piyasayı Takip Et 📈';

  @override
  String get gram => 'Gram';

  @override
  String get metalGold => 'Altın';

  @override
  String get metalSilver => 'Gümüş';

  @override
  String get metalCopper => 'Bakır';
}
