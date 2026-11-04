import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';
import '../entities/github_device_code.dart';

abstract interface class AuthRepository {
  /// Whether the GitHub sign-in needs a code typed on github.com (device
  /// flow) instead of a browser round trip through a deep link.
  bool get usesGithubDeviceCode;

  /// Opens the GitHub sign-in page in the browser and resolves once the user
  /// is signed in. Used by the browser based backends (Supabase).
  Future<Result<AuthUser>> signInWithGithub();

  /// Step 1 of the GitHub OAuth device flow: asks GitHub for a user code.
  Future<Result<GithubDeviceCode>> startGithubDeviceFlow();

  /// Step 2: polls GitHub until the user approved the device, then signs in.
  Future<Result<AuthUser>> completeGithubDeviceFlow(
    GithubDeviceCode deviceCode, {
    void Function(bool pending)? onPending,
  });

  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Result<AuthUser>> verifyOtp({required String email, required String otp});

  Future<Result<AuthUser?>> currentUser();

  Future<Result<void>> signOut();
}
