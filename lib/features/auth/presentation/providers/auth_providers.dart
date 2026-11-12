import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/result.dart';
import '../../data/backends/auth_backend.dart';
import '../../data/backends/github_auth_backend.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/datasources/github_auth_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/github_device_code.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

/// The OAuth host is reached through the 6DX API: github.com sends no CORS
/// headers, so a browser build cannot call the device-flow endpoints directly.
/// The API proxies them and answers with GitHub's payload unchanged.
final githubOAuthDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    ),
  ),
);

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>(
  (ref) => AuthLocalDataSource(ref.watch(secureStorageProvider)),
);

final githubAuthDataSourceProvider = Provider<GithubAuthDataSource>(
  (ref) => GithubAuthDataSource(ref.watch(githubOAuthDioProvider)),
);

/// GitHub is the only identity provider, through the OAuth device flow, which
/// behaves the same on every platform the app ships.
final authBackendProvider = Provider<AuthBackend>(
  (ref) => GithubAuthBackend(
    github: ref.watch(githubAuthDataSourceProvider),
    secureStorage: ref.watch(secureStorageProvider),
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    local: ref.watch(authLocalDataSourceProvider),
    backend: ref.watch(authBackendProvider),
  ),
);

// Use cases
final startGithubDeviceFlowProvider = Provider<StartGithubDeviceFlow>(
  (ref) => StartGithubDeviceFlow(ref.watch(authRepositoryProvider)),
);

final completeGithubDeviceFlowProvider = Provider<CompleteGithubDeviceFlow>(
  (ref) => CompleteGithubDeviceFlow(ref.watch(authRepositoryProvider)),
);

final getCurrentUserProvider = Provider<GetCurrentUser>(
  (ref) => GetCurrentUser(ref.watch(authRepositoryProvider)),
);

final signOutProvider = Provider<SignOut>(
  (ref) => SignOut(ref.watch(authRepositoryProvider)),
);

/// Session state — `null` means "signed out".
class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() async {
    final result = await ref.watch(getCurrentUserProvider).call();
    final user = result.dataOrNull;
    AppLogger.action(
      'AuthSession',
      user == null
          ? 'no stored session, the user has to sign in'
          : 'session restored for ${user.login}',
    );
    return user;
  }

  /// Step 1: ask GitHub for a device code the user confirms on the web.
  ///
  /// The state is restored afterwards so the sign-in button never stays
  /// disabled after a failed attempt.
  Future<Result<GithubDeviceCode>> startGithubDeviceFlow() async {
    final previous = state;
    state = const AsyncLoading();
    final result = await ref.read(startGithubDeviceFlowProvider).call();
    state = previous.hasValue ? previous : const AsyncData(null);
    return result;
  }

  /// Step 2: poll GitHub until the user approved, then create the session.
  Future<bool> completeGithubDeviceFlow(
    GithubDeviceCode deviceCode, {
    void Function(bool pending)? onPending,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(completeGithubDeviceFlowProvider).call(
          deviceCode,
          onPending: onPending,
        );
    final user = result.dataOrNull;
    state = AsyncData(user);
    return user != null;
  }

  Future<void> signOut() async {
    AppLogger.action('AuthSession', 'sign-out requested');
    await ref.read(signOutProvider).call();
    state = const AsyncData(null);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthUser?>(AuthNotifier.new);

/// Convenience selector: `true` when a user session exists.
final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authNotifierProvider).value != null,
);
