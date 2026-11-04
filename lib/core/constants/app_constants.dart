class AppConstants {
  AppConstants._();

  static const String appName = '6DX';
  static const String appTag = '6DX';

  /// GitHub OAuth (https://github.com/settings/developers)
  static const String githubClientId = String.fromEnvironment(
    'Ov23liw4p0LMObMu8l9b',
    defaultValue: 'Ov23li6MnH0CEEPyRk6',
  );
  static const String githubClientSecret = String.fromEnvironment(
    'd73fe18de841e457ed7b2130898c078bf7a682ef',
    defaultValue: '',
  );
  static const String githubScopes = 'read:user user:email repo read:org';

  /// OAuth redirect used by the mobile (custom scheme) and web flows.
  static const String githubRedirectUri = 'sixdx://oauth/callback';

  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxRetryCount = 3;

  static const String keyAccessToken = 'access_token';
  static const String keyUser = 'user';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyLocale = 'locale';
  static const String keyThemeMode = 'theme_mode';
}
