import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/github_device_code.dart';
import '../datasources/github_auth_data_source.dart';
import 'auth_backend.dart';

/// GitHub OAuth **device flow** backend.
///
/// The user confirms a short code on github.com and the app polls GitHub until
/// the grant is approved. The GitHub access token it stores is the credential
/// every API request carries, which the Go backend verifies against GitHub.
class GithubAuthBackend implements AuthBackend {
  GithubAuthBackend({
    required GithubAuthDataSource github,
    required SecureStorageService secureStorage,
  })  : _github = github,
        _secureStorage = secureStorage;

  final GithubAuthDataSource _github;
  final SecureStorageService _secureStorage;

  static const String _tag = 'GitHubAuth';

  @override
  String get name => 'GitHub Device Flow';

  @override
  Future<AuthUser?> restoreSession() async {
    final token = await _secureStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      AppLogger.action(_tag, 'restore session: no stored token');
      return null;
    }
    try {
      final payload = await _github.fetchUser(token);
      AppLogger.action(_tag, 'restore session: ok');
      return _toUser(payload, token);
    } on DioException catch (error) {
      // Only GitHub saying "this grant is invalid" ends the session. No
      // network, a timeout, a GitHub outage or a rate limit must not sign the
      // user out — the caller falls back to the cached session.
      if (error.response?.statusCode == 401) {
        AppLogger.action(_tag, 'restore session: grant revoked');
        return null;
      }
      AppLogger.action(_tag, 'restore session: GitHub unreachable', error.type);
      throw SessionUnverifiedException(error);
    }
  }

  @override
  Future<GithubDeviceCode> requestDeviceCode() async {
    AppLogger.action(_tag, 'sign-in: requesting a device code');
    final code = await _github.requestDeviceCode();
    AppLogger.action(_tag, 'sign-in: device code received');
    return GithubDeviceCode(
      deviceCode: code.deviceCode,
      userCode: code.userCode,
      verificationUri: code.verificationUri,
      interval: code.interval,
      expiresIn: code.expiresIn,
    );
  }

  @override
  Future<AuthUser> completeDeviceFlow(
    GithubDeviceCode deviceCode, {
    void Function(bool pending)? onPending,
  }) async {
    final deadline =
        DateTime.now().add(Duration(seconds: deviceCode.expiresIn));
    var interval = deviceCode.interval;
    var polls = 0;
    AppLogger.action(_tag, 'waiting for the approval (every ${interval}s)');
    var poll = await _github.pollAccessToken(deviceCode: deviceCode.deviceCode);
    while (poll.accessToken == null) {
      polls++;
      if (DateTime.now().isAfter(deadline)) {
        AppLogger.action(_tag, 'the device code expired after $polls polls');
        throw StateError('انتهت صلاحية رمز الدخول');
      }
      // GitHub answers `slow_down` when the app polls too often.
      if (poll.interval != null && poll.interval != interval) {
        interval = poll.interval!;
        AppLogger.action(
          _tag,
          'GitHub asked to slow down: polling every ${interval}s',
        );
      }
      onPending?.call(true);
      await Future<void>.delayed(Duration(seconds: interval));
      poll = await _github.pollAccessToken(deviceCode: deviceCode.deviceCode);
    }
    final token = poll.accessToken!;
    AppLogger.action(_tag, 'the user approved the device after $polls polls');

    await _secureStorage.writeAccessToken(token);
    AppLogger.action(_tag, 'loading the GitHub profile');
    final payload = await _github.fetchUser(token);
    final email = await _github.fetchPrimaryEmail(token);
    AppLogger.action(_tag, 'sign-in: ok');
    return _toUser(payload, token, email: email['email'] as String?);
  }

  @override
  Future<void> signOut() async {
    AppLogger.action(_tag, 'sign-out');
    // The grant is deleted locally only: revoking it on GitHub needs the OAuth
    // app **client secret**, which by design never ships inside the app.
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
}
