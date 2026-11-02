import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/github_device_code.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/github_auth_data_source.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    required GithubAuthDataSource github,
  })  : _remote = remote,
        _local = local,
        _github = github;

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final GithubAuthDataSource _github;

  @override
  Future<Result<GithubDeviceCode>> startGithubDeviceFlow() => _guard(() async {
        if (AppConfig.useMockData) {
          return const GithubDeviceCode(
            deviceCode: 'mock',
            userCode: 'MOCK-0000',
            verificationUri: 'https://github.com/login/device',
          );
        }
        final code = await _github.requestDeviceCode();
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

        final deadline =
            DateTime.now().add(Duration(seconds: deviceCode.expiresIn));
        var token = await _github.pollAccessToken(
          deviceCode: deviceCode.deviceCode,
          interval: deviceCode.interval,
        );
        while (token == null) {
          if (DateTime.now().isAfter(deadline)) {
            throw const ServerException('انتهت صلاحية رمز الدخول');
          }
          onPending?.call(true);
          await Future<void>.delayed(Duration(seconds: deviceCode.interval));
          token = await _github.pollAccessToken(
            deviceCode: deviceCode.deviceCode,
            interval: deviceCode.interval,
          );
        }

        final user = await _github.fetchUser(token);
        final email = await _github.fetchPrimaryEmail(token);
        final model = UserModel(
          id: '${user['id']}',
          login: user['login'] as String? ?? 'github-user',
          name: user['name'] as String?,
          email: email['email'] as String?,
          avatarUrl: user['avatar_url'] as String?,
          accessToken: token,
        );
        await _local.cacheSession(user: model);
        return model.toEntity();
      });

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final model = AppConfig.useMockData
            ? _mockEmailUser(email)
            : await _remote.loginWithEmail(email: email, password: password);
        await _local.cacheSession(user: model);
        return model.toEntity();
      });

  @override
  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _guard(() async {
        final model = AppConfig.useMockData
            ? _mockEmailUser(email, displayName: displayName)
            : await _remote.register(
                email: email,
                password: password,
                displayName: displayName,
              );
        await _local.cacheSession(user: model);
        return model.toEntity();
      });

  @override
  Future<Result<AuthUser>> verifyOtp({required String email, required String otp}) =>
      _guard(() async {
        final model = AppConfig.useMockData
            ? _mockEmailUser(email)
            : await _remote.verifyOtp(email: email, otp: otp);
        await _local.cacheSession(user: model);
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
    } catch (e) {
      return Result.failure(Failure.unknown(e.toString()));
    }
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
