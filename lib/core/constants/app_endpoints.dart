class AppEndpoints {
  AppEndpoints._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.6dx.app/v1',
  );

  static const String githubBaseUrl = 'https://api.github.com';

  /// GitHub OAuth (device flow + token exchange) lives here.
  static const String githubOAuthBaseUrl = 'https://github.com';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String workspaces = '/workspaces';

  // Projects
  static const String projects = '/projects';

  // Tasks
  static const String tasks = '/tasks';

  // Notifications
  static const String notifications = '/notifications';
}
