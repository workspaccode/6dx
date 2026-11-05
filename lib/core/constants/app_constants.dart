class AppConstants {
  AppConstants._();

  static const String appName = '6DX';
  static const String appTag = '6DX';

  /// GitHub OAuth app used by Supabase (https://github.com/settings/developers).
  ///
  /// Client **id** only: the device flow never needs the client secret, and a
  /// secret that ships inside an app is public anyway.
  /// Override with `--dart-define=GITHUB_CLIENT_ID=...`.
  static const String githubClientId = String.fromEnvironment(
    'GITHUB_CLIENT_ID',
    defaultValue: 'Ov23liw4p0LMObMu8l9b',
  );
  static const String githubScopes = 'read:user user:email';

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
