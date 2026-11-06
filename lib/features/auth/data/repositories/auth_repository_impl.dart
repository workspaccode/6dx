import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/github_device_code.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../backends/auth_backend.dart';
import '../backends/device_flow_auth_backend.dart';
import '../datasources/github_auth_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthLocalDataSource local,
    required GithubAuthDataSource github,
    required AuthBackend backend,
  })  : _local = local,
        _github = github,
        _backend = backend;

  final AuthLocalDataSource _local;
  final GithubAuthDataSource _github;
  final AuthBackend _backend;

  static const String _tag = 'Auth';

  @override
  bool get usesGithubDeviceCode => _backend.usesDeviceCode;

  @override
  Future<Result<AuthUser>> signInWithGithub() => _guard(() async {
        AppLogger.action(_tag, 'sign-in with GitHub: opening the browser');
        final user = await _backend.signInWithGithub();
        await _local.cacheSession(user: UserModel.fromEntity(user));
        AppLogger.action(_tag, 'sign-in with GitHub: success');
        return user;
      });

  @override
  Future<Result<GithubDeviceCode>> startGithubDeviceFlow() => _guard(() async {
        AppLogger.action(_tag, 'sign-in with GitHub: requesting a device code');
        if (!_backend.usesDeviceCode) {
          throw const ServerException(
            'تسجيل الدخول عبر Supabase يستخدم المتصفح، لا كود جهاز.',
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
        final backend = _backend;
        if (backend is! DeviceFlowAuthBackend) {
          throw const ServerException(
            'تسجيل الدخول عبر Supabase يستخدم المتصفح، لا كود جهاز.',
          );
        }

        AppLogger.action(_tag, 'sign-in with GitHub: waiting for the approval');
        final user =
            await backend.completeDeviceFlow(deviceCode, onPending: onPending);
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
        final user = await _backend.signInWithEmail(
          email: email,
          password: password,
        );
        await _local.cacheSession(user: UserModel.fromEntity(user));
        AppLogger.action(_tag, 'sign-in with email: success');
        return user;
      });

  @override
  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _guard(() async {
        AppLogger.action(_tag, 'sign-up: $email');
        final user = await _backend.registerWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        );
        // With e-mail confirmation enabled there is no session yet, so nothing
        // is cached: the OTP step creates it.
        if (user.accessToken != null) {
          await _local.cacheSession(user: UserModel.fromEntity(user));
        }
        AppLogger.action(
          _tag,
          'sign-up: success, the verification code was sent',
        );
        return user;
      });

  @override
  Future<Result<AuthUser>> verifyOtp({
    required String email,
    required String otp,
  }) =>
      _guard(() async {
        AppLogger.action(_tag, 'verify the OTP sent to $email');
        final user = await _backend.verifyOtp(email: email, otp: otp);
        await _local.cacheSession(user: UserModel.fromEntity(user));
        AppLogger.action(_tag, 'verify the OTP: success');
        return user;
      });

  @override
  Future<Result<AuthUser?>> currentUser() => _guard(() async {
        // The backend owns its session: GitHub validates the stored token,
        // Supabase refreshes its own. Both return `null` once it is gone.
        final restored = await _backend.restoreSession();
        if (restored == null) {
          await _local.clearSession();
          return null;
        }
        await _local.cacheSession(user: UserModel.fromEntity(restored));
        return restored;
      });

  @override
  Future<Result<void>> signOut() => _guard(() async {
        // Supabase keeps its own copy of the session (and a refresh token),
        // it has to be ended as well or the user comes back signed in.
        await _backend.signOut();
        await _local.clearSession();
      });

  /// Every failure is logged with its reason so a tester log shows exactly
  /// which step broke.
  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } catch (error) {
      final failure = _describeFailure(error);
      AppLogger.action(_tag, 'FAILED: ${failure.message}', error);
      return Result.failure(failure);
    }
  }

  static Failure _describeFailure(Object error) {
    if (error is UnauthorizedException) return const Failure.unauthorized();
    if (error is NetworkException) return Failure.network(error.message);
    if (error is ServerException) return Failure.server(error.message);
    if (error is CacheException) return Failure.cache(error.message);
    if (error is TimeoutException) {
      return Failure.network(error.message ?? 'انتهت مهلة الاتصال.');
    }
    if (error is StateError) return Failure.unknown(error.message.toString());
    if (error is DioException) {
      return Failure.network(_describeDioError(error));
    }
    return Failure.unknown(error.toString());
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
}
