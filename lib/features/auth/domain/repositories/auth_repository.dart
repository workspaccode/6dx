import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';
import '../entities/github_device_code.dart';

/// The GitHub sign-in surface.
///
/// Sign-in is always the OAuth device flow: the app asks GitHub for a code the
/// user types on github.com, then polls until GitHub approves it. The resulting
/// access token is the credential every API request carries.
abstract interface class AuthRepository {
  /// Step 1: asks GitHub for a code the user confirms in the browser.
  Future<Result<GithubDeviceCode>> startGithubDeviceFlow();

  /// Step 2: polls GitHub until the user approved the device, then signs in.
  Future<Result<AuthUser>> completeGithubDeviceFlow(
    GithubDeviceCode deviceCode, {
    void Function(bool pending)? onPending,
  });

  Future<Result<AuthUser?>> currentUser();

  Future<Result<void>> signOut();
}
