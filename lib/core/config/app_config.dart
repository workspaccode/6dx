import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Base URL of the 6DX Go backend.
  ///
  /// Override per environment:
  /// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
  ///
  /// Without an override the local backend (`go run ./cmd/api`) is assumed on
  /// port 8080. Android's emulator reaches the host machine through 10.0.2.2;
  /// every other target (iOS simulator, desktop, web) uses localhost. A
  /// physical phone needs the machine's LAN address.
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
