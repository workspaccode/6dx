class AppConstants {
  AppConstants._();

  static const String appName = '6DX';
  static const String appTag = '6DX';

  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxRetryCount = 3;

  static const String keyAccessToken = 'access_token';
  static const String keyUser = 'user';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyLocale = 'locale';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLastGroup = 'last_group_id';
}
