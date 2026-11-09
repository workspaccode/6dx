import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/errors/exceptions.dart';
import 'auth_error_messages.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/auth_user.dart';
import 'auth_backend.dart';

/// Firebase Auth backend — GitHub provider + e-mail/password.
///
/// Firebase signs a new account in immediately (there is no OTP step; the
/// optional verification e-mail is a link, never a typed code), so
/// [registerWithEmail] returns a user that already carries a session and the
/// app goes straight to the home screen. The GitHub sign-in opens the browser
/// and comes back through the platform deep link, like the Supabase PKCE
/// flow before it.
class FirebaseAuthBackend implements AuthBackend {
  FirebaseAuthBackend({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  static const String _tag = 'FirebaseAuth';

  final SecureStorageService _secureStorage;

  /// Resolved per use, not in the constructor: the data layer is also built in
  /// tests where Firebase was never initialised, and touching the instance
  /// eagerly would throw there.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  String get name => 'Firebase';

  @override
  bool get isConfigured => true;

  @override
  bool get usesDeviceCode => false;

  @override
  Stream<AuthUser?> get authStateChanges =>
      _auth.authStateChanges().asyncMap((user) async {
        if (user == null) {
          await _secureStorage.deleteAccessToken();
          AppLogger.action(_tag, 'session changed: signed out');
          return null;
        }
        final token = await user.getIdToken() ?? '';
        await _secureStorage.writeAccessToken(token);
        AppLogger.action(_tag, 'session changed: signed in as ${user.uid}');
        return _toAuthUser(user, token);
      });

  @override
  Future<AuthUser?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken() ?? '';
    await _secureStorage.writeAccessToken(token);
    return _toAuthUser(user, token);
  }

  @override
  Future<AuthUser> signInWithGithub() async {
    AppLogger.action(_tag, 'sign-in with GitHub: opening the browser');
    try {
      final credential = await _auth.signInWithProvider(
        GithubAuthProvider(),
      );
      final user = credential.user;
      if (user == null) {
        throw const ServerException('تعذّر تسجيل الدخول بـ GitHub.');
      }
      final token = await user.getIdToken() ?? '';
      await _secureStorage.writeAccessToken(token);
      return _toAuthUser(user, token);
    } on FirebaseAuthException catch (error) {
      AppLogger.action(_tag, 'sign-in with GitHub failed: ${error.message}');
      throw ServerException(describeAuthError(error));
    }
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const ServerException('تعذّر تسجيل الدخول.');
      }
      final token = await user.getIdToken() ?? '';
      await _secureStorage.writeAccessToken(token);
      return _toAuthUser(user, token);
    } on FirebaseAuthException catch (error) {
      throw ServerException(describeAuthError(error));
    }
  }

  /// Creates the account and the session in one step. Firebase has no OTP,
  /// so the app goes straight to the home screen after this returns.
  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      var user = credential.user;
      if (user == null) {
        throw const ServerException('تعذّر إنشاء الحساب.');
      }
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        await user.reload();
        user = _auth.currentUser ?? user;
      }
      final token = await user.getIdToken() ?? '';
      await _secureStorage.writeAccessToken(token);
      return _toAuthUser(user, token);
    } on FirebaseAuthException catch (error) {
      throw ServerException(describeAuthError(error));
    }
  }

  /// Kept for interface compatibility. With Firebase a sign-up needs no code:
  /// the session already exists, so the call confirms the current user.
  @override
  Future<AuthUser> verifyOtp({required String email, required String otp}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ServerException(
        'التسجيل مع Firebase لا يحتاج كود تأكيد — سجّل من جديد.',
      );
    }
    final token = await user.getIdToken() ?? '';
    await _secureStorage.writeAccessToken(token);
    return _toAuthUser(user, token);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AuthUser _toAuthUser(User user, String token) {
    final githubLogin = user.providerData
        .where((info) => info.providerId == 'github.com')
        .map((info) => info.displayName ?? info.uid)
        .firstOrNull;
    final email = user.email ??
        user.providerData.map((info) => info.email).firstOrNull;
    return AuthUser(
      id: user.uid,
      login: githubLogin ?? email ?? user.uid,
      name: user.displayName,
      email: email,
      avatarUrl: user.photoURL,
      accessToken: token,
    );
  }
}
