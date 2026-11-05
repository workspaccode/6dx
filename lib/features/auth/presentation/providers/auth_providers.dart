import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_endpoints.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_factory.dart';
import '../../../../core/utils/logger.dart';
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

/// The OAuth endpoints live on github.com, not on api.github.com. They need
/// their own client: Dio prepends `baseUrl` to every path, so an absolute
/// URL would end up as `https://api.github.com/https://github.com/...`.
final githubOAuthDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      baseUrl: AppEndpoints.githubOAuthBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
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
  (ref) => GithubAuthDataSource(ref.watch(githubOAuthDioProvider)),
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
final signInWithGithubProvider = Provider<SignInWithGithub>(
  (ref) => SignInWithGithub(ref.watch(authRepositoryProvider)),
);

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
    final user = result.dataOrNull;
    AppLogger.action(
      'AuthSession',
      user == null
          ? 'no stored session, the user has to sign in'
          : 'session restored for ${user.login}',
    );
    return user;
  }

  /// `true` when GitHub sign-in needs a code typed on github.com, `false` when
  /// it completes in the browser and comes back through a deep link.
  bool get usesDeviceCode =>
      ref.read(authRepositoryProvider).usesGithubDeviceCode;

  /// Browser based sign-in (Supabase): opens GitHub in the browser and waits
  /// for the deep link that carries the session.
  Future<Result<AuthUser>> signInWithGithub() async {
    final previous = state;
    state = const AsyncLoading();
    final result = await ref.read(signInWithGithubProvider).call();
    final user = result.dataOrNull;
    state = user != null
        ? AsyncData(user)
        : (previous.hasValue ? previous : const AsyncData(null));
    return result;
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
    AppLogger.action('AuthSession', 'sign-out requested');
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
