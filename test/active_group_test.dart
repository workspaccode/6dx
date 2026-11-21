import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixdx/app/app_providers.dart';
import 'package:sixdx/core/network/api_client.dart';
import 'package:sixdx/core/storage/local_storage_service.dart';
import 'package:sixdx/features/auth/domain/entities/auth_user.dart';
import 'package:sixdx/features/auth/presentation/providers/auth_providers.dart';
import 'package:sixdx/features/groups/presentation/providers/active_group.dart';

class _SignedIn extends AuthNotifier {
  @override
  Future<AuthUser?> build() async => const AuthUser(id: '1', login: 'sami');
}

Future<(ProviderContainer, ApiClient)> _container({String? remembered}) async {
  SharedPreferences.setMockInitialValues({
    if (remembered != null) 'last_group_id': remembered,
  });
  final storage = await LocalStorageService.create();
  final api = ApiClient();
  final container = ProviderContainer(overrides: [
    localStorageServiceProvider.overrideWithValue(storage),
    apiClientProvider.overrideWithValue(api),
    authNotifierProvider.overrideWith(_SignedIn.new),
  ]);
  addTearDown(container.dispose);
  return (container, api);
}

void main() {
  test('starts from the remembered group and sends it as X-Group-Id', () async {
    final (container, api) = await _container(remembered: 'g-hw');
    expect(container.read(activeGroupProvider), 'g-hw');
    expect(api.activeGroupId, 'g-hw');
  });

  test('selecting a group updates the header and is remembered', () async {
    final (container, api) = await _container();
    expect(container.read(activeGroupProvider), isNull);

    container.read(activeGroupProvider.notifier).select('g-app');
    expect(container.read(activeGroupProvider), 'g-app');
    expect(api.activeGroupId, 'g-app');
    expect(container.read(localStorageServiceProvider).lastGroupId, 'g-app');
  });

  test('being removed from the group falls back to the default group', () async {
    final (container, api) = await _container(remembered: 'g-old');
    container.read(activeGroupProvider);

    // What the API client does on 403 not_group_member.
    api.onGroupRevoked!.call();
    expect(container.read(activeGroupProvider), isNull);
    expect(api.activeGroupId, isNull);
    expect(container.read(localStorageServiceProvider).lastGroupId, isNull);
  });
}
