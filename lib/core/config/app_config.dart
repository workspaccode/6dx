class AppConfig {
  AppConfig._();

  // --- Supabase (authentication + database) ------------------------------

  /// Supabase project URL, e.g. `https://abcdefgh.supabase.co`.
  ///
  /// Override with `--dart-define=SUPABASE_URL=...`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ifrpswaclrrsshspdmzd.supabase.co',
  );

  /// Supabase publishable (anon) key. Safe to ship in the app.
  ///
  /// Override with `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_eYtVhUSrk6QDblHyUaCq6g_CzskyhRY',
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

  /// GitHub scopes requested from Supabase — identity only.
  ///
  /// Repository access is granted separately through a GitHub App (see
  /// `supabase/functions/github-app`), so the app never asks for `repo` and the
  /// user is never forced to hand over every private repository.
  static const String githubScopes = 'read:user user:email';
}
