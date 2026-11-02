import 'dart:convert';

import '../../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

class AuthLocalDataSource {
  AuthLocalDataSource(this._secureStorage);

  final SecureStorageService _secureStorage;

  Future<void> cacheSession({required UserModel user}) async {
    if (user.accessToken != null) {
      await _secureStorage.writeAccessToken(user.accessToken!);
    }
    await _secureStorage.writeUser(jsonEncode(user.toJson()));
  }

  Future<UserModel?> readCachedUser() async {
    final raw = await _secureStorage.readUser();
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    await _secureStorage.deleteAccessToken();
    await _secureStorage.writeUser('');
  }
}
