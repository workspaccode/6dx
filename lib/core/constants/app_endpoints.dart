/// Hosts the app talks to.
///
/// Everything except the GitHub endpoints goes through the 6DX API
/// (`AppConfig.apiBaseUrl`); these are the only absolute GitHub hosts left.
class AppEndpoints {
  AppEndpoints._();

  static const String githubBaseUrl = 'https://api.github.com';

  /// GitHub OAuth (device flow) lives here.
  static const String githubOAuthBaseUrl = 'https://github.com';
}