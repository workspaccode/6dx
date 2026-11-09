import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../errors/exceptions.dart';
import '../utils/logger.dart';

/// Talks to the 6DX Go backend.
///
/// Firebase is the identity provider only: every request carries the Firebase
/// ID token and the API verifies it before touching the database. The active
/// workspace travels in `X-Workspace-Id` so an account that belongs to several
/// workspaces acts on the one the UI is showing.
class ApiClient {
  ApiClient({Dio? dio, FirebaseAuth? auth})
      : _dio = dio ?? Dio(),
        _authOverride = auth {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['Content-Type'] = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final auth = _auth;
          final user = auth?.currentUser;
          if (user == null) {
            // Without a session there is nothing to authorise, so the request
            // is rejected locally: the API would answer 401 anyway, and the
            // screens must render their signed-out state, not a network error.
            handler.reject(
              DioException(
                requestOptions: options,
                error: const UnauthorizedException(),
                type: DioExceptionType.cancel,
              ),
            );
            return;
          }
          final token = await user.getIdToken();
          if (token == null) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: const UnauthorizedException(),
                type: DioExceptionType.cancel,
              ),
            );
            return;
          }
          options.headers['Authorization'] = 'Bearer $token';

          final workspace = activeWorkspaceId;
          if (workspace != null && workspace.isNotEmpty) {
            options.headers['X-Workspace-Id'] = workspace;
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final FirebaseAuth? _authOverride;

  /// Resolved per use so a unit test can build the client without Firebase.
  FirebaseAuth? get _auth {
    if (_authOverride != null) return _authOverride;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// The workspace the UI is showing; sent as `X-Workspace-Id`.
  String? activeWorkspaceId;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  /// Runs a request and maps failures to the exceptions the repositories know.
  ///
  /// [label] names the operation so the log shows exactly which step failed:
  /// `[ACTION] Api: projects.list → ok (42ms)` or
  /// `[ACTION] Api: projects.list → FAILED 403 viewer_read_only`.
  Future<T> run<T>(String label, Future<T> Function() action) async {
    final started = DateTime.now();
    AppLogger.action('Api', '$label → start');
    try {
      final result = await action();
      AppLogger.action('Api', '$label → ok (${_elapsed(started)}ms)');
      return result;
    } catch (error) {
      AppLogger.action('Api', '$label → FAILED ${_describe(error)}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is Map) return _stringKeys(data);
      return <String, dynamic>{};
    } on DioException catch (error) {
      throw _toException(error);
    }
  }

  Exception _toException(DioException error) {
    // A rejected request carries the exception directly (the no-session case).
    final inner = error.error;
    if (inner is UnauthorizedException) return inner;
    if (inner is ServerException) return inner;

    final response = error.response;
    if (response == null) {
      if (error.type == DioExceptionType.cancel) {
        return const UnauthorizedException();
      }
      return const ServerException('تعذّر الاتصال بالخادم — تحقق من الشبكة.');
    }

    final body = response.data;
    final map = body is Map ? _stringKeys(body) : <String, dynamic>{};
    final code = map['error'] as String?;
    final message = map['message'] as String?;

    switch (response.statusCode) {
      case 401:
        return const UnauthorizedException();
      case 413:
        return const ServerException('حجم الطلب أكبر من المسموح.');
    }

    if (message != null && message.isNotEmpty) {
      return ServerException(message);
    }
    return ServerException('تعذّر إتمام العملية${code == null ? '' : ' ($code)'}.');
  }

  String _describe(Object error) {
    if (error is ServerException) return error.message;
    if (error is UnauthorizedException) return 'unauthorized';
    return error.toString();
  }

  static Map<String, dynamic> _stringKeys(Map<dynamic, dynamic> source) => {
        for (final entry in source.entries) '${entry.key}': entry.value,
      };

  static String _elapsed(DateTime started) =>
      '${DateTime.now().difference(started).inMilliseconds}';
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
