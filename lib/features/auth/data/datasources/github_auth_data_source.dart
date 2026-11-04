import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
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

  final Dio _dio;

  /// Step 1 of the GitHub OAuth *device flow*: ask GitHub for a user code the
  /// user can confirm in the browser. Works on mobile, desktop and web
  /// without needing a redirect URI.
  Future<GithubDeviceCodeResponse> requestDeviceCode() async {
    final data = await _post(
      '/login/device/code',
      {
        'client_id': AppConstants.githubClientId,
        'scope': AppConstants.githubScopes,
      },
    );
    return GithubDeviceCodeResponse(
      deviceCode: data['device_code'] as String,
      userCode: data['user_code'] as String,
      verificationUri: data['verification_uri'] as String,
      interval: (data['interval'] as num?)?.toInt() ?? 5,
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 900,
    );
  }

  /// Step 2: poll GitHub until the user approved the device.
  Future<GithubTokenPoll> pollAccessToken({required String deviceCode}) async {
    final data = await _post(
      '/login/oauth/access_token',
      {
        'client_id': AppConstants.githubClientId,
        'device_code': deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      },
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

  /// POSTs a form-encoded body to an endpoint of the OAuth host and returns
  /// the decoded JSON body.
  ///
  /// GitHub expects the OAuth parameters in the request body; a query string
  /// makes `/login/device/code` answer `404`.
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> fields, {
    bool tolerateOAuthError = false,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        path,
        data: fields,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
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
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'انتهت مهلة الاتصال بـ GitHub.',
      DioExceptionType.connectionError => 'تعذّر الاتصال بالإنترنت.',
      _ => 'تعذّر الاتصال بـ GitHub.',
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
      'معرّف تطبيق GitHub غير صحيح — اضبط GITHUB_CLIENT_ID عبر --dart-define.';
}
