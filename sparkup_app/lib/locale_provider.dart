import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  // İlk açılışta cihaz dilini kullan
  Locale _locale = Locale(ui.PlatformDispatcher.instance.locale.languageCode);
  bool _userSetLanguage = false;

  Locale get locale => _locale;
  bool get userSetLanguage => _userSetLanguage;

  LocaleProvider() {
    _initFromPrefs();
  }

  Future<void> _initFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('user_language_code');
      final flag = prefs.getBool('user_set_language') ?? false;
      // Only apply saved language if the user explicitly set it before
      if (flag && savedCode != null && savedCode.isNotEmpty) {
        _locale = Locale(savedCode);
        _userSetLanguage = true;
      } else {
        _userSetLanguage = false;
      }
      notifyListeners();
    } catch (_) {
      // ignore errors, keep device locale
    }
  }

  /// Set locale; if [persist] is true, remember that the user explicitly chose this language.
  Future<void> setLocale(String languageCode, {bool persist = false}) async {
    _locale = Locale(languageCode);
    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_language_code', languageCode);
        await prefs.setBool('user_set_language', true);
        _userSetLanguage = true;
      } catch (_) {}
    }
    // Debug log for tracing unexpected resets
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      // ignore: avoid_print
      print('[LocaleProvider] setLocale -> $languageCode (persist=$persist)');
    }
    notifyListeners();
  }

  /// If you need to clear the user-chosen language (for testing)
  Future<void> clearUserLanguageChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_language_code');
      await prefs.remove('user_set_language');
    } catch (_) {}
    _userSetLanguage = false;
    _locale = Locale(ui.PlatformDispatcher.instance.locale.languageCode);
    notifyListeners();
  }
}
