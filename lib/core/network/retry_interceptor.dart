import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Simple exponential-backoff retry interceptor for idempotent requests.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    int retries = AppConstants.maxRetryCount,
    List<Duration> retryDelays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 900),
      Duration(seconds: 2),
    ],
  })  : _dio = dio,
        _retries = retries,
        _retryDelays = retryDelays;

  final Dio _dio;
  final int _retries;
  final List<Duration> _retryDelays;

  static const Set<int> _retryableStatusCodes = {408, 429, 500, 502, 503, 504};

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final shouldRetry = statusCode == null
        ? err.type == DioExceptionType.connectionError ||
            err.type == DioExceptionType.connectionTimeout ||
            err.type == DioExceptionType.receiveTimeout
        : _retryableStatusCodes.contains(statusCode);

    final attempt = (err.requestOptions.extra['retry_attempt'] as int?) ?? 0;

    if (!shouldRetry || attempt >= _retries) {
      handler.next(err);
      return;
    }

    final delay = _retryDelays[attempt.clamp(0, _retryDelays.length - 1)];
    await Future<void>.delayed(delay);

    final options = err.requestOptions;
    options.extra['retry_attempt'] = attempt + 1;

    try {
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
