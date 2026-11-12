import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage_service.dart';

/// The encrypted storage that keeps the GitHub grant and the cached user.
///
/// Shared by the auth layer and the HTTP client so both read the same token.
final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);
