import 'dart:async';

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/github_device_code.dart';
import '../datasources/github_auth_data_source.dart';
import 'auth_backend.dart';

/// GitHub OAuth **device flow** backend.
///
/// Used when Supabase is not configured. The user confirms a short code on
/// github.com and the app polls GitHub until the grant is approved.
class DeviceFlowAuthBackend implements AuthBackend {
  DeviceFlowAuthBackend({
    required GithubAuthDataSource github,
    required SecureStorageService secureStorage,
  })  : _github = github,
        _secureStorage = secureStorage;

  final GithubAuthDataSource _github;
  final SecureStorageService _secureStorage;

  @override
  String get name => 'GitHub Device Flow';

  @override
  bool get isConfigured => true;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  @override
  Future<AuthUser?> restoreSession() async {
    final token = await _secureStorage.readAccessToken();
    if (token == null || token.isEmpty) return null;
    try {
      final payload = await _github.fetchUser(token);
      return _toUser(payload, token);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AuthUser> signInWithGithub() async {
    final code = await _github.requestDeviceCode();
    final deviceCode = GithubDeviceCode(
      deviceCode: code.deviceCode,
      userCode: code.userCode,
      verificationUri: code.verificationUri,
      interval: code.interval,
      expiresIn: code.expiresIn,
    );
    return completeDeviceFlow(deviceCode);
  }

  /// Polls GitHub until the user approved the device, then signs in.
  Future<AuthUser> completeDeviceFlow(
    GithubDeviceCode deviceCode, {
    void Function(bool pending)? onPending,
  }) async {
    final deadline =
        DateTime.now().add(Duration(seconds: deviceCode.expiresIn));
    var token = await _github.pollAccessToken(
      deviceCode: deviceCode.deviceCode,
      interval: deviceCode.interval,
    );
    while (token == null) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('انتهت صلاحية رمز الدخول');
      }
      onPending?.call(true);
      await Future<void>.delayed(Duration(seconds: deviceCode.interval));
      token = await _github.pollAccessToken(
        deviceCode: deviceCode.deviceCode,
        interval: deviceCode.interval,
      );
    }

    await _secureStorage.writeAccessToken(token);
    final payload = await _github.fetchUser(token);
    final email = await _github.fetchPrimaryEmail(token);
    return _toUser(payload, token, email: email['email'] as String?);
  }

  @override
  Future<void> signOut() async {
    await _secureStorage.deleteAccessToken();
  }

  AuthUser _toUser(
    Map<String, dynamic> payload,
    String token, {
    String? email,
  }) {
    final metadata = payload['user'] as Map<String, dynamic>?;
    return AuthUser(
      id: '${payload['id']}',
      login: payload['login'] as String? ?? 'github-user',
      name: payload['name'] as String? ?? metadata?['name'] as String?,
      email: email ?? payload['email'] as String?,
      avatarUrl: payload['avatar_url'] as String?,
      accessToken: token,
    );
  }

  /// Whether the app should use the demo account instead of a real provider.
  bool get isDemoMode => AppConfig.useMockData;
}
