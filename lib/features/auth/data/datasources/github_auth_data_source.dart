import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_endpoints.dart';
import '../../../../core/errors/exceptions.dart';

class GithubDeviceCode {
  const GithubDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
    required this.expiresIn,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int interval;
  final int expiresIn;
}

class GithubAuthDataSource {
  GithubAuthDataSource(this._dio);

  final Dio _dio;

  /// Step 1 of the GitHub OAuth *device flow*: ask GitHub for a user code the
  /// user can confirm in the browser. Works on mobile, desktop and web
  /// without needing a redirect URI.
  Future<GithubDeviceCode> requestDeviceCode() async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://github.com/login/device/code',
      queryParameters: {
        'client_id': AppConstants.githubClientId,
        'scope': AppConstants.githubScopes,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    return GithubDeviceCode(
      deviceCode: data['device_code'] as String,
      userCode: data['user_code'] as String,
      verificationUri: data['verification_uri'] as String,
      interval: (data['interval'] as num?)?.toInt() ?? 5,
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 900,
    );
  }

  /// Step 2: poll GitHub until the user approved the device.
  /// Returns `null` while the request is still pending (`authorization_pending`).
  Future<String?> pollAccessToken({
    required String deviceCode,
    required int interval,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://github.com/login/oauth/access_token',
        queryParameters: {
          'client_id': AppConstants.githubClientId,
          'client_secret': AppConstants.githubClientSecret,
          'device_code': deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      final error = data['error'] as String?;
      if (error == null) {
        return data['access_token'] as String?;
      }
      if (error == 'authorization_pending') {
        return null;
      }
      throw ServerException(data['error_description'] as String? ?? error);
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'GitHub authorization failed');
    }
  }

  /// Exchanges an OAuth *authorization code* for an access token.
  Future<String> exchangeCode(String code) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://github.com/login/oauth/access_token',
        queryParameters: {
          'client_id': AppConstants.githubClientId,
          'client_secret': AppConstants.githubClientSecret,
          'code': code,
          'redirect_uri': AppConstants.githubRedirectUri,
        },
      );
      final token = response.data?['access_token'] as String?;
      if (token == null) {
        throw const ServerException('Invalid GitHub authorization code');
      }
      return token;
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'GitHub authorization failed');
    }
  }

  /// Loads the authenticated GitHub user.
  Future<Map<String, dynamic>> fetchUser(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppEndpoints.githubBaseUrl}/user',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchPrimaryEmail(String token) async {
    final response = await _dio.get<List<dynamic>>(
      '${AppEndpoints.githubBaseUrl}/user/emails',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final emails = response.data ?? const <dynamic>[];
    for (final email in emails) {
      if (email is Map<String, dynamic> && email['primary'] == true) {
        return email;
      }
    }
    return const <String, dynamic>{};
  }
}
