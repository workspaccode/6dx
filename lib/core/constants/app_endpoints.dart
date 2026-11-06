/// Hosts the app talks to.
///
/// Everything except the GitHub endpoints now goes through Supabase, so there
/// is no REST API of our own any more.
class AppEndpoints {
  AppEndpoints._();

  static const String githubBaseUrl = 'https://api.github.com';

  /// GitHub OAuth (device flow) lives here.
  static const String githubOAuthBaseUrl = 'https://github.com';
}