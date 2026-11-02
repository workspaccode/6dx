import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/local_storage_service.dart';

/// `SharedPreferences` based storage — created once at startup.
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw UnimplementedError('localStorageServiceProvider must be overridden');
});

/// App theme mode (persisted).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(localStorageServiceProvider).themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(localStorageServiceProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Selected locale — `null` follows the system locale.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => ref.watch(localStorageServiceProvider).locale;

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final storage = ref.read(localStorageServiceProvider);
    if (locale == null) {
      await storage.setLocale('');
    } else {
      await storage.setLocale(locale.languageCode);
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
