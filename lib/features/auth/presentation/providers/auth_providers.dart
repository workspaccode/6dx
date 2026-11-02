import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_endpoints.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_factory.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/result.dart';
import '../../data/backends/auth_backend.dart';
import '../../data/backends/device_flow_auth_backend.dart';
import '../../data/backends/supabase_auth_backend.dart';
import '../../data/datasources/auth_local_data_source.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/datasources/github_auth_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/github_device_code.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

/// Infrastructure providers (composition root).
final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final dioProvider = Provider<Dio>(
  (ref) => DioFactory.create(secureStorage: ref.watch(secureStorageProvider)),
);

final githubDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      baseUrl: AppEndpoints.githubBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  ),
);

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
);

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>(
  (ref) => AuthLocalDataSource(ref.watch(secureStorageProvider)),
);

final githubAuthDataSourceProvider = Provider<GithubAuthDataSource>(
  (ref) => GithubAuthDataSource(ref.watch(githubDioProvider)),
);

/// Supabase is preferred when it is configured, otherwise the app falls back
/// to the GitHub OAuth device flow.
final authBackendProvider = Provider<AuthBackend>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  if (AppConfig.useSupabaseAuth) {
    return SupabaseAuthBackend(secureStorage: secureStorage);
  }
  return DeviceFlowAuthBackend(
    github: ref.watch(githubAuthDataSourceProvider),
    secureStorage: secureStorage,
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    local: ref.watch(authLocalDataSourceProvider),
    github: ref.watch(githubAuthDataSourceProvider),
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

final signInWithEmailProvider = Provider<SignInWithEmail>(
  (ref) => SignInWithEmail(ref.watch(authRepositoryProvider)),
);

final registerWithEmailProvider = Provider<RegisterWithEmail>(
  (ref) => RegisterWithEmail(ref.watch(authRepositoryProvider)),
);

final verifyOtpProvider = Provider<VerifyOtp>(
  (ref) => VerifyOtp(ref.watch(authRepositoryProvider)),
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
    return result.dataOrNull;
  }

  /// Step 1: ask GitHub for a device code the user confirms on the web.
  Future<Result<GithubDeviceCode>> startGithubDeviceFlow() async {
    state = const AsyncLoading();
    return ref.read(startGithubDeviceFlowProvider).call();
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
    return _apply(result);
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(signInWithEmailProvider).call(
          email: email,
          password: password,
        );
    return _apply(result);
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(registerWithEmailProvider).call(
          email: email,
          password: password,
          displayName: displayName,
        );
    return _apply(result);
  }

  Future<bool> verifyOtp({required String email, required String otp}) async {
    state = const AsyncLoading();
    final result =
        await ref.read(verifyOtpProvider).call(email: email, otp: otp);
    return _apply(result);
  }

  Future<void> signOut() async {
    await ref.read(signOutProvider).call();
    state = const AsyncData(null);
  }

  bool _apply(Result<AuthUser> result) {
    final data = result.dataOrNull;
    state = AsyncData(data);
    return data != null;
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthUser?>(AuthNotifier.new);

/// Convenience selector: `true` when a user session exists.
final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authNotifierProvider).value != null,
);
