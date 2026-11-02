import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../constants/app_endpoints.dart';
import '../storage/secure_storage_service.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';

class DioFactory {
  DioFactory._();

  static Dio create({
    required SecureStorageService secureStorage,
    String baseUrl = AppEndpoints.baseUrl,
    bool withAuth = true,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConstants.requestTimeout,
        receiveTimeout: AppConstants.requestTimeout,
        sendTimeout: AppConstants.requestTimeout,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (withAuth) {
      dio.interceptors.add(AuthInterceptor(secureStorage));
    }

    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        retries: AppConstants.maxRetryCount,
      ),
    );

    return dio;
  }
}
