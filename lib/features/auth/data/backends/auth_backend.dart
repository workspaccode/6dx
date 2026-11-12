import '../../domain/entities/auth_user.dart';
import '../../domain/entities/github_device_code.dart';

/// The single authentication backend: the GitHub OAuth device flow.
///
/// It is the same plain HTTPS round trip on every platform (Android, iOS,
/// macOS, Windows, Linux and web): no deep links, no embedded browser and no
/// per-platform OAuth client configuration to keep in sync.
abstract interface class AuthBackend {
  /// Human readable name, shown in the logs.
  String get name;

  /// Restores a previously stored session, if any.
  Future<AuthUser?> restoreSession();

  /// Step 1: asks GitHub for a code the user types on github.com.
  Future<GithubDeviceCode> requestDeviceCode();

  /// Step 2: polls GitHub until the device is approved, then stores the grant.
  Future<AuthUser> completeDeviceFlow(
    GithubDeviceCode deviceCode, {
    void Function(bool pending)? onPending,
  });

  /// Ends the session.
  Future<void> signOut();
}
