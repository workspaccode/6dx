import '../constants/app_endpoints.dart';

class AppConfig {
  AppConfig._();

  /// When enabled the data layer serves seeded in-memory data instead of
  /// hitting the production API. Toggle with:
  /// `flutter run --dart-define=USE_MOCK=false`
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  static bool get isProductionApiConfigured =>
      !AppEndpoints.baseUrl.contains('api.6dx.app');
}
