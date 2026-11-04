import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/github_device_code.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../backends/auth_backend.dart';
import '../backends/device_flow_auth_backend.dart';
import '../backends/supabase_auth_backend.dart';
import '../datasources/github_auth_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    required GithubAuthDataSource github,
    required AuthBackend backend,
  })  : _remote = remote,
        _local = local,
        _github = github,
        _backend = backend;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final GithubAuthDataSource _github;
  final AuthBackend _backend;

  static const String _tag = 'Auth';

  @override
  Future<Result<GithubDeviceCode>> startGithubDeviceFlow() => _guard(() async {
        AppLogger.action(_tag, 'sign-in with GitHub: requesting a device code');
        if (AppConfig.useMockData) {
          return const GithubDeviceCode(
            deviceCode: 'mock',
            userCode: 'MOCK-0000',
            verificationUri: 'https://github.com/login/device',
          );
        }
        if (_backend is SupabaseAuthBackend) {
          // Supabase runs the whole OAuth round trip itself.
          final user = await _backend.signInWithGithub();
          await _local.cacheSession(user: UserModel.fromEntity(user));
          return const GithubDeviceCode(
            deviceCode: 'supabase',
            userCode: 'SUPABASE',
            verificationUri: 'https://github.com/login/oauth/authorize',
          );
        }
        final code = await _github.requestDeviceCode();
        AppLogger.action(
          _tag,
          'sign-in with GitHub: device code received, the user must confirm it',
        );
        return GithubDeviceCode(
          deviceCode: code.deviceCode,
          userCode: code.userCode,
          verificationUri: code.verificationUri,
          interval: code.interval,
          expiresIn: code.expiresIn,
        );
      });

  @override
  Future<Result<AuthUser>> completeGithubDeviceFlow(
    GithubDeviceCode deviceCode, {
    void Function(bool pending)? onPending,
  }) =>
      _guard(() async {
        if (AppConfig.useMockData) {
          final user = _mockGithubUser();
          await _local.cacheSession(user: user);
          return user.toEntity();
        }

        if (_backend is DeviceFlowAuthBackend) {
          AppLogger.action(_tag, 'sign-in with GitHub: waiting for the approval');
          final user = await _backend
              .completeDeviceFlow(deviceCode, onPending: onPending);
          await _local.cacheSession(user: UserModel.fromEntity(user));
          AppLogger.action(_tag, 'sign-in with GitHub: success');
          return user;
        }

        AppLogger.action(_tag, 'sign-in with GitHub: completing through Supabase');
        final user = await _backend.signInWithGithub();
        await _local.cacheSession(user: UserModel.fromEntity(user));
        AppLogger.action(_tag, 'sign-in with GitHub: success');
        return user;
      });

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() async {
        AppLogger.action(_tag, 'sign-in with email: $email');
        final model = AppConfig.useMockData
            ? _mockEmailUser(email)
            : await _remote.loginWithEmail(email: email, password: password);
        await _local.cacheSession(user: model);
        AppLogger.action(_tag, 'sign-in with email: success');
        return model.toEntity();
      });

  @override
  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _guard(() async {
        AppLogger.action(_tag, 'sign-up: $email');
        final model = AppConfig.useMockData
            ? _mockEmailUser(email, displayName: displayName)
            : await _remote.register(
                email: email,
                password: password,
                displayName: displayName,
              );
        await _local.cacheSession(user: model);
        AppLogger.action(_tag, 'sign-up: success, the verification code was sent');
        return model.toEntity();
      });

  @override
  Future<Result<AuthUser>> verifyOtp({required String email, required String otp}) =>
      _guard(() async {
        AppLogger.action(_tag, 'verify the OTP sent to $email');
        final model = AppConfig.useMockData
            ? _mockEmailUser(email)
            : await _remote.verifyOtp(email: email, otp: otp);
        await _local.cacheSession(user: model);
        AppLogger.action(_tag, 'verify the OTP: success');
        return model.toEntity();
      });

  @override
  Future<Result<AuthUser?>> currentUser() => _guard(() async {
        final cached = await _local.readCachedUser();
        if (cached == null) return null;
        if (!AppConfig.useMockData) {
          final token = cached.accessToken;
          if (token != null) {
            try {
              final fresh = await _github.fetchUser(token);
              final updated = cached.copyWith(
                login: fresh['login'] as String? ?? cached.login,
                name: fresh['name'] as String? ?? cached.name,
                avatarUrl: fresh['avatar_url'] as String? ?? cached.avatarUrl,
              );
              await _local.cacheSession(user: updated);
              return updated.toEntity();
            } on DioException {
              await _local.clearSession();
              return null;
            }
          }
        }
        return cached.toEntity();
      });

  @override
  Future<Result<void>> signOut() => _guard(() async {
        if (!AppConfig.useMockData) {
          try {
            await _remote.logout();
          } on DioException {
            // The local session is cleared regardless of the server answer.
          }
        }
        await _local.clearSession();
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on UnauthorizedException {
      return const Result.failure(Failure.unauthorized());
    } on NetworkException catch (e) {
      return Result.failure(Failure.network(e.message));
    } on ServerException catch (e) {
      return Result.failure(Failure.server(e.message));
    } on CacheException catch (e) {
      return Result.failure(Failure.cache(e.message));
    } on DioException catch (e) {
      return Result.failure(Failure.network(_describeDioError(e)));
    } catch (e) {
      return Result.failure(Failure.unknown(e.toString()));
    }
  }

  /// Turns a transport error into a short, actionable message.
  static String _describeDioError(DioException error) {
    final status = error.response?.statusCode;
    return switch (status) {
      400 || 401 || 403 =>
        'رفض GitHub الطلب — تأكد من ضبط GITHUB_CLIENT_ID في إعدادات المشروع.',
      404 => 'المسار غير موجود على GitHub.',
      429 => 'تم تجاوز حد الطلبات على GitHub، حاول بعد قليل.',
      _ when error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout =>
        'انتهت مهلة الاتصال بـ GitHub.',
      _ when error.type == DioExceptionType.connectionError =>
        'تعذّر الاتصال بالإنترنت.',
      _ => 'تعذّر الاتصال بـ GitHub.',
    };
  }

  UserModel _mockGithubUser() => UserModel(
        id: '10001',
        login: 'sixdx-dev',
        name: 'Sami Developer',
        email: 'sami@example.com',
        avatarUrl: 'https://avatars.githubusercontent.com/u/10001?v=4',
        accessToken: 'mock-github-token',
      );

  UserModel _mockEmailUser(String email, {String? displayName}) => UserModel(
        id: '20002',
        login: email.split('@').first,
        name: displayName ?? email.split('@').first,
        email: email,
        accessToken: 'mock-email-token',
      );
}
