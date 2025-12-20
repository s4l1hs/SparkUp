import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class LocaleProvider extends ChangeNotifier {
  // Default to device locale on first run so users see app in their language
  Locale _locale = Locale(ui.PlatformDispatcher.instance.locale.languageCode);

  Locale get locale => _locale;

  void setLocale(String languageCode) {
    _locale = Locale(languageCode);
    notifyListeners();
  }
}