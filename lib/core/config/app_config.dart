import '../constants/app_endpoints.dart';

class AppConfig {
  AppConfig._();

  /// When enabled the data layer serves the demo catalogue from
  /// `lib/core/demo/demo_data.dart` instead of hitting the production API.
  ///
  /// The default is `false`: a normal build never shows invented data — it
  /// renders whatever the API returns, an empty state, or an error state.
  /// Demo builds are opt-in:
  /// `flutter run --dart-define=USE_MOCK=true`
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: false,
  );

  static bool get isProductionApiConfigured =>
      !AppEndpoints.baseUrl.contains('api.6dx.app');
}
