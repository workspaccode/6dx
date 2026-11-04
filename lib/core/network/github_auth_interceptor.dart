import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';
import '../utils/logger.dart';

/// Adds the GitHub access token to every GitHub API request.
///
/// The token is the *provider* token GitHub issued during sign-in (Supabase
/// hands it back as `session.providerToken`), not the 6DX/Supabase session
/// token, so it lives under its own storage key.
class GithubAuthInterceptor extends Interceptor {
  GithubAuthInterceptor(this._secureStorage);

  final SecureStorageService _secureStorage;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _secureStorage.readGithubToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      AppLogger.action('GitHub', 'GET ${options.path} → start');
    } else {
      // Without it GitHub answers 401 and the repository picker looks empty.
      AppLogger.action(
        'GitHub',
        'GET ${options.path} → no GitHub token stored, the request will fail',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final data = response.data;
    final count = data is List ? data.length : null;
    AppLogger.action(
      'GitHub',
      'GET ${response.requestOptions.path} → '
          '${response.statusCode}${count == null ? '' : ' ($count items)'}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.action(
      'GitHub',
      'GET ${err.requestOptions.path} → FAILED '
          '${err.response?.statusCode ?? err.type.name}',
      err.response?.data,
    );
    handler.next(err);
  }
}
