import '../../domain/entities/auth_user.dart';

/// A pluggable authentication backend.
///
/// 6DX talks to Supabase Auth by default (GitHub OAuth, PKCE, no client
/// secret in the app). When Supabase is not configured the app falls back to
/// the GitHub OAuth device flow, so the tester build still works with nothing
/// but a GitHub client id.
abstract interface class AuthBackend {
  /// Human readable name, shown in the login screen.
  String get name;

  /// Whether the backend is ready to be used.
  bool get isConfigured;

  /// Restores a previously stored session, if any.
  Future<AuthUser?> restoreSession();

  /// Starts the GitHub sign-in flow and resolves once the user is signed in.
  Future<AuthUser> signInWithGithub();

  /// Ends the session.
  Future<void> signOut();

  /// Emits whenever the session changes (sign-in, sign-out, token refresh).
  Stream<AuthUser?> get authStateChanges;
}
