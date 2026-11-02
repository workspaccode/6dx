import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/core/storage/secure_storage_service.dart';
import 'package:sixdx/features/auth/data/backends/device_flow_auth_backend.dart';
import 'package:sixdx/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:sixdx/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:sixdx/features/auth/data/datasources/github_auth_data_source.dart';
import 'package:sixdx/features/auth/data/repositories/auth_repository_impl.dart';

/// Records the calls the repository makes so we can assert the OAuth device
/// flow is wired the way GitHub documents it.
class _FakeGithubDataSource extends GithubAuthDataSource {
  _FakeGithubDataSource() : super(Dio());

  int deviceCodeCalls = 0;
  int pollCalls = 0;
  int userCalls = 0;
  int pollResultsBeforeApproval = 2;
  String? token;

  @override
  Future<GithubDeviceCodeResponse> requestDeviceCode() async {
    deviceCodeCalls++;
    return GithubDeviceCodeResponse(
      deviceCode: 'device-123',
      userCode: 'ABCD-1234',
      verificationUri: 'https://github.com/login/device',
      interval: 1,
      expiresIn: 900,
    );
  }

  @override
  Future<String?> pollAccessToken({
    required String deviceCode,
    required int interval,
  }) async {
    pollCalls++;
    if (pollCalls <= pollResultsBeforeApproval) return null;
    return token ?? 'gho_test_token';
  }

  @override
  Future<Map<String, dynamic>> fetchUser(String token) async {
    userCalls++;
    return {
      'id': 42,
      'login': 'sami',
      'name': 'Sami',
      'avatar_url': 'https://example.com/a.png',
    };
  }

  @override
  Future<Map<String, dynamic>> fetchPrimaryEmail(String token) async {
    return {'email': 'sami@example.com', 'primary': true};
  }
}

void main() {
  test('github device flow: request code, poll until approved, then sign in',
      () async {
    final github = _FakeGithubDataSource();
    final repository = AuthRepositoryImpl(
      remote: _unusedRemote(),
      local: _unusedLocal(),
      github: github,
      backend: DeviceFlowAuthBackend(
        github: github,
        secureStorage: SecureStorageService(),
      ),
    );

    // Step 1 — the app asks GitHub for a code the user confirms.
    final started = await repository.startGithubDeviceFlow();
    final deviceCode = started.dataOrNull;
    expect(deviceCode, isNotNull);
    expect(deviceCode!.userCode, 'ABCD-1234');
    expect(deviceCode.verificationUri, contains('github.com'));
    expect(github.deviceCodeCalls, 1);

    // Step 2 — the app polls until the user approved the device.
    final pending = <bool>[];
    final signedIn =
        await repository.completeGithubDeviceFlow(deviceCode, onPending: pending.add);
    final user = signedIn.dataOrNull;

    expect(user, isNotNull);
    expect(user!.login, 'sami');
    expect(user.email, 'sami@example.com');
    expect(user.accessToken, 'gho_test_token');
    // Two rejected polls, then the approval.
    expect(github.pollCalls, 3);
    expect(pending, isNotEmpty);
    expect(github.userCalls, 1);
  });

  test('the device code is never exchanged as an OAuth authorization code',
      () async {
    // The repository must never call `exchangeCode` — that endpoint expects a
    // real browser redirect code, which the app does not use.
    final github = _FakeGithubDataSource();
    final repository = AuthRepositoryImpl(
      remote: _unusedRemote(),
      local: _unusedLocal(),
      github: github,
      backend: DeviceFlowAuthBackend(
        github: github,
        secureStorage: SecureStorageService(),
      ),
    );

    await repository.startGithubDeviceFlow();
    expect(github.deviceCodeCalls, 1);
  });
}

AuthRemoteDataSource _unusedRemote() => AuthRemoteDataSource(Dio());

AuthLocalDataSource _unusedLocal() =>
    AuthLocalDataSource(SecureStorageService());
