import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Base URL of the 6DX Go backend, set at build time:
  ///
  /// ```
  /// # local network (beta APK on a phone)
  /// flutter build apk --dart-define=API_BASE_URL=http://192.168.1.11:8080
  /// # server by IP, before the domain exists
  /// flutter build apk --dart-define=API_BASE_URL=http://<server-ip>:8080
  /// # production
  /// flutter build apk --dart-define=API_BASE_URL=https://api.<domain>
  /// ```
  ///
  /// Without an override a **debug** build talks to the local backend
  /// (`go run ./cmd/api`) on port 8080: Android's emulator reaches the host
  /// through 10.0.2.2, every other target uses localhost. A **release** build
  /// has no fallback — it must be told where the server is (see [isMisconfigured]).
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

  /// A release build without `--dart-define=API_BASE_URL` would quietly talk
  /// to localhost on the user's phone. The app shows a clear error instead.
  static bool get isMisconfigured =>
      kReleaseMode && _apiBaseUrlOverride.isEmpty;

  /// Whether the API is reached over plain HTTP (local network / server IP
  /// before the domain and its certificate exist).
  static bool get isInsecure => apiBaseUrl.startsWith('http://');
}
