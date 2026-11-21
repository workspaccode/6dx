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
    // The token lives under its own key only; the cached profile never
    // carries a second copy of it.
    await _secureStorage
        .writeUser(jsonEncode(user.copyWith(accessToken: null).toJson()));
  }

  /// The last confirmed session, for when GitHub cannot be reached: the cached
  /// profile plus the stored grant. `null` unless both exist.
  Future<UserModel?> readOfflineSession() async {
    final token = await _secureStorage.readAccessToken();
    if (token == null || token.isEmpty) return null;
    final cached = await readCachedUser();
    if (cached == null) return null;
    return cached.copyWith(accessToken: token);
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
