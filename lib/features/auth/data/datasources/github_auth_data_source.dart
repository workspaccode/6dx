import 'package:dio/dio.dart';

import '../../../../core/constants/app_endpoints.dart';
import '../../../../core/errors/exceptions.dart';

/// Wire format of the device-flow response.
class GithubDeviceCodeResponse {
  const GithubDeviceCodeResponse({
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

/// Outcome of one poll of the device-flow token endpoint.
class GithubTokenPoll {
  const GithubTokenPoll._(this.accessToken, this.interval);

  /// No token yet — GitHub is still waiting for the user
  /// (`authorization_pending`).
  const GithubTokenPoll.pending() : this._(null, null);

  /// The user approved the device: [accessToken] is the grant.
  const GithubTokenPoll.approved(String accessToken) : this._(accessToken, null);

  /// GitHub asked the app to poll less often (`slow_down`).
  const GithubTokenPoll.slowDown(int interval) : this._(null, interval);

  final String? accessToken;

  /// The new polling interval, in seconds, when GitHub asked to slow down.
  final int? interval;
}

class GithubAuthDataSource {
  GithubAuthDataSource(this._dio);

  /// Points at the 6DX API: the device-flow calls are proxied there because
  /// github.com sends no CORS headers, which would break the web build.
  final Dio _dio;

  /// Step 1 of the GitHub OAuth *device flow*: ask GitHub for a user code the
  /// user can confirm in the browser.
  Future<GithubDeviceCodeResponse> requestDeviceCode() async {
    final data = await _postDeviceFlow('/auth/github/device-code', const {});
    return GithubDeviceCodeResponse(
      deviceCode: data['device_code'] as String,
      userCode: data['user_code'] as String,
      verificationUri: data['verification_uri'] as String,
      interval: (data['interval'] as num?)?.toInt() ?? 5,
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 900,
    );
  }

  /// Step 2: poll until the user approved the device.
  Future<GithubTokenPoll> pollAccessToken({required String deviceCode}) async {
    final data = await _postDeviceFlow(
      '/auth/github/device-token',
      {'device_code': deviceCode},
      // `authorization_pending` and `slow_down` are normal answers of the
      // device flow, not failures: GitHub reports them in the body.
      tolerateOAuthError: true,
    );

    switch (data['error'] as String?) {
      case null:
        final token = data['access_token'] as String?;
        if (token == null || token.isEmpty) {
          throw const ServerException('GitHub لم يُرجع رمز وصول.');
        }
        return GithubTokenPoll.approved(token);
      case 'authorization_pending':
        return const GithubTokenPoll.pending();
      case 'slow_down':
        return GithubTokenPoll.slowDown(
          (data['interval'] as num?)?.toInt() ?? 10,
        );
      case final error:
        throw ServerException(_describe(error, data['error_description']));
    }
  }

  /// Loads the authenticated GitHub user.
  ///
  /// api.github.com allows cross-origin reads, so this call goes straight to
  /// GitHub from every platform, the browser included.
  Future<Map<String, dynamic>> fetchUser(String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppEndpoints.githubBaseUrl}/user',
      options: Options(headers: _githubHeaders(token)),
    );
    return response.data ?? const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchPrimaryEmail(String token) async {
    final response = await _dio.get<dynamic>(
      '${AppEndpoints.githubBaseUrl}/user/emails',
      options: Options(headers: _githubHeaders(token)),
    );
    final emails = response.data;
    if (emails is! List) return const <String, dynamic>{};
    for (final email in emails) {
      if (email is Map && email['primary'] == true) {
        return <String, dynamic>{
          for (final entry in email.entries) '${entry.key}': entry.value,
        };
      }
    }
    return const <String, dynamic>{};
  }

  Map<String, String> _githubHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
      };

  /// POSTs a JSON body to one of the API's device-flow endpoints and returns
  /// the decoded answer.
  Future<Map<String, dynamic>> _postDeviceFlow(
    String path,
    Map<String, String> fields, {
    bool tolerateOAuthError = false,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(path, data: fields);
    } on DioException catch (e) {
      throw ServerException(_describeDioError(e));
    }

    final body = response.data;
    if (body is! Map) {
      throw const ServerException('ردّ غير متوقع من GitHub.');
    }
    final data = <String, dynamic>{
      for (final entry in body.entries) '${entry.key}': entry.value,
    };
    final error = data['error'] as String?;
    if (error != null && !tolerateOAuthError) {
      throw ServerException(_describe(error, data['error_description']));
    }
    return data;
  }

  static String _describeDioError(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['error'] != null) {
      return _describe(
        data['error'] as String?,
        data['error_description'] as String?,
        status: error.response?.statusCode,
      );
    }
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'انتهت مهلة الاتصال بالخادم.',
      DioExceptionType.connectionError => 'تعذّر الاتصال بالإنترنت.',
      _ => 'تعذّر الاتصال بالخادم.',
    };
  }

  /// Turns a GitHub OAuth error into a short, actionable message.
  static String _describe(String? code, String? description, {int? status}) {
    switch (code) {
      case 'device_flow_disabled':
        return 'خيار Device Flow غير مُفعّل في تطبيق GitHub OAuth — فعّله من '
            'github.com/settings/developers.';
      case 'incorrect_client_credentials':
      case 'unauthorized_client':
        return _badClientId;
      case 'access_denied':
        return 'تم إلغاء تسجيل الدخول من GitHub.';
      case 'expired_token':
        return 'انتهت صلاحية كود الدخول، أعد المحاولة.';
      case 'unsupported_grant_type':
        return 'تطبيق GitHub OAuth لا يدعم Device Flow.';
    }
    // GitHub answers `{"error":"Not Found"}` (HTTP 404) for an unknown client.
    if (status == 404) return _badClientId;
    if (description != null && description.isNotEmpty) return description;
    return code == null ? 'رفض GitHub الطلب.' : 'رفض GitHub الطلب ($code).';
  }

  static const String _badClientId =
      'معرّف تطبيق GitHub غير صحيح — اضبط GITHUB_CLIENT_ID في إعدادات الـ backend.';
}
