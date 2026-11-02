import 'package:dio/dio.dart';

import '../../../../core/constants/app_endpoints.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppEndpoints.login,
      data: {'email': email, 'password': password},
    );
    return UserModel.fromJson(_unwrap(response.data));
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppEndpoints.register,
      data: {
        'email': email,
        'password': password,
        'name': displayName,
      },
    );
    return UserModel.fromJson(_unwrap(response.data));
  }

  Future<UserModel> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppEndpoints.verifyOtp,
      data: {'email': email, 'otp': otp},
    );
    return UserModel.fromJson(_unwrap(response.data));
  }

  Future<void> logout() async {
    await _dio.post<void>(AppEndpoints.logout);
  }

  /// The API wraps every payload inside a `data` envelope.
  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) return const <String, dynamic>{};
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }
}
