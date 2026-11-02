import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStorageService> create() async =>
      LocalStorageService(await SharedPreferences.getInstance());

  bool get onboardingDone => _prefs.getBool(AppConstants.keyOnboardingDone) ?? false;

  Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(AppConstants.keyOnboardingDone, value);

  Locale? get locale {
    final code = _prefs.getString(AppConstants.keyLocale);
    return code == null ? null : Locale(code);
  }

  Future<void> setLocale(String code) => _prefs.setString(AppConstants.keyLocale, code);

  ThemeMode get themeMode {
    final value = _prefs.getString(AppConstants.keyThemeMode);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(AppConstants.keyThemeMode, mode.name);
}
