import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/auth_user.dart';
import 'auth_backend.dart';

/// Supabase Auth backend.
///
/// GitHub is an OAuth provider of Supabase: the app only receives a PKCE
/// code through the deep link, Supabase exchanges it server side — so no
/// GitHub client secret ever ships inside the app.
class SupabaseAuthBackend implements AuthBackend {
  SupabaseAuthBackend({required SecureStorageService secureStorage})
      : _secureStorage = secureStorage;

  final SecureStorageService _secureStorage;
  StreamController<AuthUser?>? _controller;

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  String get name => 'Supabase';

  @override
  bool get isConfigured => AppConfig.useSupabaseAuth;

  @override
  bool get usesDeviceCode => false;

  @override
  Stream<AuthUser?> get authStateChanges {
    final controller = _controller ??= StreamController<AuthUser?>.broadcast(
      onListen: () {
        _client.auth.onAuthStateChange.listen(_onAuthStateChange);
      },
    );
    return controller.stream;
  }

  Future<void> _onAuthStateChange(sb.AuthState state) async {
    final token = state.session?.accessToken;
    if (token == null) {
      await _secureStorage.deleteAccessToken();
      AppLogger.action('Auth', 'session changed: signed out');
    } else {
      // The API layer reads the bearer token from the secure storage.
      await _secureStorage.writeAccessToken(token);
      AppLogger.action('Auth', 'session changed: ${state.event.name}');
    }
    _controller?.add(_mapUser(state.session?.user, state.session?.accessToken));
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final session = await _client.auth.getSession();
    if (session == null) {
      AppLogger.action('Auth', 'restore session: no Supabase session');
      return null;
    }
    await _secureStorage.writeAccessToken(session.accessToken);
    AppLogger.action(
      'Auth',
      'restore session: ok (${session.user.email ?? session.user.id})',
    );
    return _mapUser(session.user, session.accessToken);
  }

  @override
  Future<AuthUser> signInWithGithub() async {
    // The session never comes back from `signInWithOAuth` itself: the SDK
    // receives it through the deep link once the user approved the app in the
    // browser. Listen *before* opening the browser so the event cannot be
    // missed.
    final completer = Completer<sb.Session>();
    final subscription = _client.auth.onAuthStateChange.listen((state) {
      final session = state.session;
      if (session != null && !completer.isCompleted) {
        completer.complete(session);
      }
    });

    try {
      AppLogger.action(
        'Auth',
        'sign-in with GitHub: opening the browser, '
            'redirect ${AppConfig.supabaseRedirectUrl}',
      );
      final started = await _client.auth.signInWithOAuth(
        sb.OAuthProvider.github,
        redirectTo: AppConfig.supabaseRedirectUrl,
        scopes: AppConfig.githubScopes,
      );
      if (!started) {
        throw StateError('تعذّر فتح صفحة تسجيل الدخول.');
      }

      final session = await completer.future.timeout(
        _signInTimeout,
        onTimeout: () => throw TimeoutException(_redirectMissing),
      );
      AppLogger.action('Auth', 'sign-in with GitHub: the deep link arrived');
      await _secureStorage.writeAccessToken(session.accessToken);
      return _mapUser(session.user, session.accessToken)!;
    } finally {
      await subscription.cancel();
    }
  }

  /// How long the app waits for the browser to hand the session back.
  static const Duration _signInTimeout = Duration(minutes: 2);

  /// Shown when the deep link never arrives — the usual cause is a redirect
  /// URL that Supabase does not allow yet.
  static const String _redirectMissing =
      'لم يعُد التطبيق من GitHub. أضف رابط إعادة التوجيه التالي في '
      'Supabase ← Authentication ← URL Configuration ← Redirect URLs، ثم أعد '
      'المحاولة: io.supabase.flutter://login-callback';

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    AppLogger.action('Auth', 'sign-in with password: $email');
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = response.session;
      if (session == null) {
        throw const sb.AuthException('لم تُنشأ جلسة — أكّد بريدك أولًا.');
      }
      await _secureStorage.writeAccessToken(session.accessToken);
      AppLogger.action('Auth', 'sign-in with password: ok');
      return _mapUser(session.user, session.accessToken)!;
    } on sb.AuthException catch (error) {
      AppLogger.action('Auth', 'sign-in with password: FAILED', error.message);
      throw sb.AuthException(_describeAuth(error));
    }
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    AppLogger.action('Auth', 'sign-up: $email');
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': displayName},
      );
      final user = response.user;
      if (user == null) {
        throw const sb.AuthException('تعذّر إنشاء الحساب.');
      }
      final session = response.session;
      if (session != null) {
        await _secureStorage.writeAccessToken(session.accessToken);
      }
      AppLogger.action(
        'Auth',
        'sign-up: ok (${session == null ? 'confirmation required' : 'signed in'})',
      );
      return _mapUser(user, session?.accessToken)!;
    } on sb.AuthException catch (error) {
      AppLogger.action('Auth', 'sign-up: FAILED', error.message);
      throw sb.AuthException(_describeAuth(error));
    }
  }

  @override
  Future<AuthUser> verifyOtp({
    required String email,
    required String otp,
  }) async {
    AppLogger.action('Auth', 'verifying the code sent to $email');
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: otp,
        type: sb.OtpType.signup,
      );
      final session = response.session;
      if (session == null) {
        throw const sb.AuthException('الكود صحيح لكن لم تُنشأ جلسة.');
      }
      await _secureStorage.writeAccessToken(session.accessToken);
      AppLogger.action('Auth', 'verify code: ok');
      return _mapUser(session.user, session.accessToken)!;
    } on sb.AuthException catch (error) {
      AppLogger.action('Auth', 'verify code: FAILED', error.message);
      throw sb.AuthException(_describeAuth(error));
    }
  }

  /// Supabase answers in English; the screens are Arabic.
  static String _describeAuth(sb.AuthException error) {
    final code = error.code;
    final message = error.message.toLowerCase();
    if (code == 'invalid_credentials' || message.contains('invalid login')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (code == 'email_not_confirmed' || message.contains('not confirmed')) {
      return 'أكّد بريدك الإلكتروني أولًا — تحقّق من رمز التأكيد.';
    }
    if (code == 'user_already_exists' || message.contains('already registered')) {
      return 'هذا البريد مسجّل بالفعل — جرّب تسجيل الدخول.';
    }
    if (code == 'weak_password' || message.contains('password should be')) {
      return 'كلمة المرور ضعيفة — استخدم 8 أحرف على الأقل.';
    }
    if (code == 'over_email_send_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('too many')) {
      return 'تم إرسال أكواد كثيرة — انتظر قليلًا ثم أعد المحاولة.';
    }
    if (code == 'otp_expired' || message.contains('expired')) {
      return 'انتهت صلاحية الكود — اطلب كودًا جديدًا.';
    }
    if (code == 'signup_disabled') {
      return 'إنشاء الحسابات غير مفعّل على هذا المشروع.';
    }
    return error.message;
  }

  @override
  Future<void> signOut() async {
    AppLogger.action('Auth', 'sign-out: clearing the Supabase session');
    await _client.auth.signOut();
    await _secureStorage.deleteAccessToken();
  }

  AuthUser? _mapUser(sb.User? user, String? accessToken) {
    if (user == null) return null;
    final metadata = user.userMetadata;
    return AuthUser(
      id: user.id,
      login: metadata?['user_name'] as String? ??
          metadata?['preferred_username'] as String? ??
          user.email?.split('@').first ??
          'user',
      name: metadata?['full_name'] as String? ??
          metadata?['name'] as String? ??
          user.email?.split('@').first,
      email: user.email,
      avatarUrl: metadata?['avatar_url'] as String? ?? user.userMetadata?['picture'],
      accessToken: accessToken,
    );
  }
}
