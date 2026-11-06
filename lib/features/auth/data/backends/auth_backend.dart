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

  /// Whether the GitHub sign-in needs a short code the user types on
  /// github.com (the device flow), instead of a browser redirect that comes
  /// back through a deep link.
  bool get usesDeviceCode;

  /// Restores a previously stored session, if any.
  Future<AuthUser?> restoreSession();

  /// Starts the GitHub sign-in flow and resolves once the user is signed in.
  Future<AuthUser> signInWithGithub();

  /// E-mail + password sign-in.
  ///
  /// Only the Supabase backend supports it; the GitHub device-flow fallback has
  /// no user database of its own.
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Creates an account and sends the confirmation code.
  ///
  /// Returns the pending user: with e-mail confirmation enabled there is no
  /// session until [verifyOtp] succeeds.
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  /// Confirms a sign-up code.
  Future<AuthUser> verifyOtp({required String email, required String otp});

  /// Ends the session.
  Future<void> signOut();

  /// Emits whenever the session changes (sign-in, sign-out, token refresh).
  Stream<AuthUser?> get authStateChanges;
}
