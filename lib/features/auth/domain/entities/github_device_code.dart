/// A GitHub OAuth *device flow* grant: the user code the person types on
/// github.com plus the polling parameters.
class GithubDeviceCode {
  const GithubDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    this.interval = 5,
    this.expiresIn = 900,
  });

  final String deviceCode;

  /// The short code shown to the user (e.g. `ABCD-1234`).
  final String userCode;

  /// Where the user has to confirm the code.
  final String verificationUri;

  /// Seconds between two polls.
  final int interval;

  /// Seconds until the grant expires.
  final int expiresIn;
}
