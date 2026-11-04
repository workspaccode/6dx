class AppEndpoints {
  AppEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.6dx.app/v1',
  );

  static const String githubBaseUrl = 'https://api.github.com';

  /// GitHub OAuth (device flow + token exchange) lives here.
  static const String githubOAuthBaseUrl = 'https://github.com';

  // Auth — the email/password endpoints of the 6DX REST API. Projects, tasks
  // and the workspace projection are read from Supabase instead (see
  // `supabase/migrations`).
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
}
