/// Hosts the app talks to.
///
/// Everything except the GitHub endpoints goes through the 6DX API
/// (`AppConfig.apiBaseUrl`); these are the only absolute GitHub hosts left.
class AppEndpoints {
  AppEndpoints._();

  static const String githubBaseUrl = 'https://api.github.com';

  /// github.com itself is only reached by the backend now: the device-flow
  /// endpoints are proxied (see `backend/internal/api/auth_flow.go`) because
  /// they send no CORS headers.
  static const String githubOAuthBaseUrl = 'https://github.com';
}