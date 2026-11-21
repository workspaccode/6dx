import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../errors/exceptions.dart';
import '../storage/secure_storage_provider.dart';
import '../storage/secure_storage_service.dart';
import '../utils/logger.dart';

/// Talks to the 6DX Go backend.
///
/// Every request carries the GitHub grant the device flow stored; the API
/// verifies it with GitHub before touching the database. The active workspace
/// travels in `X-Workspace-Id` so an account that belongs to several
/// workspaces acts on the one the UI is showing.
class ApiClient {
  ApiClient({Dio? dio, SecureStorageService? secureStorage})
      : _dio = dio ?? Dio(),
        _secureStorage = secureStorage {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 20);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['Content-Type'] = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // The bearer token belongs to this API only. A request to any other
          // host (an absolute URL that came from server data, say) goes out
          // without it.
          if (options.uri.host != Uri.parse(_dio.options.baseUrl).host) {
            handler.next(options);
            return;
          }
          final token = await _secureStorage?.readAccessToken();
          if (token == null || token.isEmpty) {
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
  final SecureStorageService? _secureStorage;


  /// The workspace the UI is showing; sent as `X-Workspace-Id`.
  String? activeWorkspaceId;

  /// Called when the server answers 401 for a request that carried a token.
  /// The session layer re-validates the grant with GitHub then: a revoked
  /// grant signs the user out, a GitHub outage keeps the cached session.
  void Function()? onUnauthorized;
  DateTime? _lastUnauthorized;

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
        _notifyUnauthorized();
        return const UnauthorizedException();
      case 413:
        return const ServerException('حجم الطلب أكبر من المسموح.');
      case 429:
        return const ServerException('طلبات كتير في وقت قصير. حاول تاني بعد دقيقة.');
    }

    if (message != null && message.isNotEmpty) {
      return ServerException(message);
    }
    return ServerException('تعذّر إتمام العملية${code == null ? '' : ' ($code)'}.');
  }

  /// At most once every 30 s, so a burst of failing requests triggers a
  /// single re-validation.
  void _notifyUnauthorized() {
    final now = DateTime.now();
    final last = _lastUnauthorized;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastUnauthorized = now;
    onUnauthorized?.call();
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

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(secureStorage: ref.watch(secureStorageProvider)),
);
