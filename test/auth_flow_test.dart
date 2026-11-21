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

  /// When set, `fetchUser` fails with a response of this status (or with no
  /// response at all when it is 0, i.e. offline).
  int? failUserWith;

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
    final status = failUserWith;
    if (status != null) {
      final options = RequestOptions(path: '/user');
      throw DioException(
        requestOptions: options,
        type: status == 0
            ? DioExceptionType.connectionError
            : DioExceptionType.badResponse,
        response:
            status == 0 ? null : Response(requestOptions: options, statusCode: status),
      );
    }
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
  String? _user;

  @override
  Future<String?> readUser() async => _user;

  @override
  Future<void> writeUser(String json) async => _user = json;

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

  Future<AuthRepositoryImpl> signedIn(
    _FakeGithubDataSource github,
    _MemorySecureStorage storage,
  ) async {
    final repository = AuthRepositoryImpl(
      local: AuthLocalDataSource(storage),
      backend: GithubAuthBackend(github: github, secureStorage: storage),
    );
    final started = await repository.startGithubDeviceFlow();
    await repository.completeGithubDeviceFlow(started.dataOrNull!);
    return repository;
  }

  test('offline at start-up keeps the session and the grant', () async {
    final github = _FakeGithubDataSource()..pollResultsBeforeApproval = 0;
    final storage = _MemorySecureStorage();
    final repository = await signedIn(github, storage);

    github.failUserWith = 0; // no network
    final restored = await repository.currentUser();

    expect(restored.dataOrNull?.login, 'sami');
    expect(restored.dataOrNull?.accessToken, 'gho_test_token');
    expect(await storage.readAccessToken(), 'gho_test_token');
  });

  test('a GitHub outage (5xx) does not sign the user out', () async {
    final github = _FakeGithubDataSource()..pollResultsBeforeApproval = 0;
    final storage = _MemorySecureStorage();
    final repository = await signedIn(github, storage);

    github.failUserWith = 503;
    final restored = await repository.currentUser();

    expect(restored.dataOrNull?.login, 'sami');
    expect(await storage.readAccessToken(), isNotNull);
  });

  test('a revoked grant (401) signs the user out', () async {
    final github = _FakeGithubDataSource()..pollResultsBeforeApproval = 0;
    final storage = _MemorySecureStorage();
    final repository = await signedIn(github, storage);

    github.failUserWith = 401;
    final restored = await repository.currentUser();

    expect(restored.dataOrNull, isNull);
    expect(await storage.readAccessToken(), isNull);
  });

  test('the cached profile never holds a copy of the token', () async {
    final github = _FakeGithubDataSource()..pollResultsBeforeApproval = 0;
    final storage = _MemorySecureStorage();
    await signedIn(github, storage);

    final cached = await storage.readUser();
    expect(cached, isNotNull);
    expect(cached, isNot(contains('gho_test_token')));
  });
}
