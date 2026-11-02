import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage_service.dart';
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
    } else {
      // The API layer reads the bearer token from the secure storage.
      await _secureStorage.writeAccessToken(token);
    }
    _controller?.add(_mapUser(state.session?.user, state.session?.accessToken));
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final session = await _client.auth.getSession();
    if (session == null) return null;
    await _secureStorage.writeAccessToken(session.accessToken);
    return _mapUser(session.user, session.accessToken);
  }

  @override
  Future<AuthUser> signInWithGithub() async {
    final started = await _client.auth.signInWithOAuth(
      sb.OAuthProvider.github,
      redirectTo: AppConfig.supabaseRedirectUrl,
      scopes: AppConfig.githubScopes,
    );
    if (!started) {
      throw StateError('تعذّر فتح صفحة تسجيل الدخول');
    }

    // The SDK listens for the deep link itself (`detectSessionInUri`) and
    // exchanges the PKCE code for a session.
    final session = await _client.auth
        .getSession()
        .timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException('انتهت مهلة تسجيل الدخول');
    });
    if (session == null) {
      throw StateError('لم تكتمل عملية تسجيل الدخول');
    }
    await _secureStorage.writeAccessToken(session.accessToken);
    return _mapUser(session.user, session.accessToken)!;
  }

  @override
  Future<void> signOut() async {
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
