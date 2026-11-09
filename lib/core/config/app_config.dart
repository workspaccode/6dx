class AppConfig {
  AppConfig._();

  /// Base URL of the 6DX Go backend.
  ///
  /// Override per environment:
  /// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
  ///
  /// 10.0.2.2 is the Android emulator's alias for the host machine, so the
  /// local backend (`go run ./cmd/api`) works out of the box on an emulator.
  /// A physical phone needs the machine's LAN address.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Firebase handles authentication only; the data lives in the Go backend.
  static bool get useFirebaseAuth => true;

  /// Set to `true` to skip Firebase and fall back to the GitHub OAuth device
  /// flow — useful for tester builds without a Firebase project:
  /// `flutter run --dart-define=USE_DEVICE_FLOW=true`.
  static const bool useDeviceFlowFallback =
      String.fromEnvironment('USE_DEVICE_FLOW', defaultValue: 'false') == 'true';

  /// GitHub scopes requested for identity only.
  ///
  /// Repository access is granted separately through a GitHub App (see
  /// `backend/internal/api/github.go`), so the app never asks for `repo` and
  /// the user is never forced to hand over every private repository.
  static const String githubScopes = 'read:user user:email';
}
