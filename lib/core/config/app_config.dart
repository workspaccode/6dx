import '../constants/app_endpoints.dart';

class AppConfig {
  AppConfig._();

  /// When enabled the data layer serves the demo catalogue from
  /// `lib/core/demo/demo_data.dart` instead of hitting the production API.
  ///
  /// The default is `false`: a normal build never shows invented data — it
  /// renders whatever the API returns, an empty state, or an error state.
  /// Demo builds are opt-in:
  /// `flutter run --dart-define=USE_MOCK=true`
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );

  static bool get isProductionApiConfigured =>
      !AppEndpoints.baseUrl.contains('api.6dx.app');

  // --- Supabase (auth + optional database) -------------------------------

  /// Supabase project URL, e.g. `https://abcdefgh.supabase.co`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase publishable (anon) key. Safe to ship in the app.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Supabase is used for authentication only when it is configured.
  static bool get useSupabaseAuth =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Redirect URI GitHub sends the user back to. Must be registered in the
  /// Supabase dashboard (Authentication → URL Configuration).
  static const String supabaseRedirectUrl = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
    defaultValue: 'io.supabase.flutter://login-callback',
  );

  /// GitHub scopes requested from Supabase.
  static const String githubScopes = 'read:user user:email repo read:org';
}
