import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';

class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const String _tag = 'SecureStorage';

  Future<String?> readAccessToken() => _read(AppConstants.keyAccessToken);

  Future<void> writeAccessToken(String token) =>
      _write(AppConstants.keyAccessToken, token);

  Future<void> deleteAccessToken() => _delete(AppConstants.keyAccessToken);

  Future<String?> readUser() => _read(AppConstants.keyUser);

  Future<void> writeUser(String user) => _write(AppConstants.keyUser, user);

  Future<String?> readGithubToken() => _read(AppConstants.keyGithubToken);

  Future<void> writeGithubToken(String token) =>
      _write(AppConstants.keyGithubToken, token);

  Future<void> deleteGithubToken() => _delete(AppConstants.keyGithubToken);

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      AppLogger.w(_tag, 'Failed to read $key', e);
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      AppLogger.w(_tag, 'Failed to write $key', e);
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      AppLogger.w(_tag, 'Failed to delete $key', e);
    }
  }
}
