import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixdx/app/app.dart';
import 'package:sixdx/app/app_providers.dart';
import 'package:sixdx/core/storage/local_storage_service.dart';
import 'package:sixdx/core/storage/secure_storage_service.dart';
import 'package:sixdx/features/auth/presentation/providers/auth_providers.dart';

/// In-memory replacement for the platform keychain so the test never touches
/// a method channel.
class _FakeSecureStorage extends SecureStorageService {
  _FakeSecureStorage() : super(const FlutterSecureStorage());

  final Map<String, String> _values = {};

  @override
  Future<String?> readAccessToken() async => _values['token'];

  @override
  Future<void> writeAccessToken(String token) async => _values['token'] = token;

  @override
  Future<void> deleteAccessToken() async => _values.remove('token');

  @override
  Future<String?> readUser() async => _values['user'];

  @override
  Future<void> writeUser(String user) async => _values['user'] = user;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app boots and lands on the onboarding flow', (tester) async {
    final storage = await LocalStorageService.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          secureStorageProvider.overrideWithValue(_FakeSecureStorage()),
        ],
        child: const SixDxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('اربط مشروعك بمستودع GitHub'), findsOneWidget);
    expect(find.text('تخطٍّ'), findsOneWidget);
  });
}
