import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/core/storage/secure_storage_service.dart';
import 'package:sixdx/features/auth/data/backends/github_auth_backend.dart';
import 'package:sixdx/features/auth/data/datasources/auth_local_data_source.dart';
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
  Future<GithubTokenPoll> pollAccessToken({required String deviceCode}) async {
    pollCalls++;
    if (pollCalls <= pollResultsBeforeApproval) {
      return const GithubTokenPoll.pending();
    }
    return GithubTokenPoll.approved(token ?? 'gho_test_token');
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

/// In-memory keychain so the test never touches a method channel.
class _MemorySecureStorage extends SecureStorageService {
  _MemorySecureStorage() : super(const FlutterSecureStorage());

  String? _token;

  @override
  Future<String?> readAccessToken() async => _token;

  @override
  Future<void> writeAccessToken(String token) async => _token = token;

  @override
  Future<void> deleteAccessToken() async => _token = null;
}

void main() {
  test('github device flow: request code, poll until approved, then sign in',
      () async {
    final github = _FakeGithubDataSource();
    final storage = _MemorySecureStorage();
    final repository = AuthRepositoryImpl(
      local: AuthLocalDataSource(storage),
      backend: GithubAuthBackend(github: github, secureStorage: storage),
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
    final signedIn = await repository.completeGithubDeviceFlow(
      deviceCode,
      onPending: pending.add,
    );
    final user = signedIn.dataOrNull;

    expect(user, isNotNull);
    expect(user!.login, 'sami');
    expect(user.email, 'sami@example.com');
    expect(user.accessToken, 'gho_test_token');
    // Two rejected polls, then the approval.
    expect(github.pollCalls, 3);
    expect(pending, isNotEmpty);
    expect(github.userCalls, 1);
    // The grant is what the API client sends as the bearer token.
    expect(await storage.readAccessToken(), 'gho_test_token');
  });

  test('signing out drops the stored grant', () async {
    final github = _FakeGithubDataSource();
    final storage = _MemorySecureStorage();
    final repository = AuthRepositoryImpl(
      local: AuthLocalDataSource(storage),
      backend: GithubAuthBackend(github: github, secureStorage: storage),
    );

    final started = await repository.startGithubDeviceFlow();
    await repository.completeGithubDeviceFlow(started.dataOrNull!);
    expect(await storage.readAccessToken(), isNotNull);

    await repository.signOut();
    expect(await storage.readAccessToken(), isNull);
  });

  test('a stored grant restores the session without a new sign-in', () async {
    final github = _FakeGithubDataSource();
    final storage = _MemorySecureStorage();
    await storage.writeAccessToken('gho_existing');
    final repository = AuthRepositoryImpl(
      local: AuthLocalDataSource(storage),
      backend: GithubAuthBackend(github: github, secureStorage: storage),
    );

    final restored = await repository.currentUser();
    expect(restored.dataOrNull?.login, 'sami');
    expect(github.userCalls, 1);
  });
}
