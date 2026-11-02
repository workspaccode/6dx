import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/core/config/app_config.dart';
import 'package:sixdx/features/workspace/presentation/providers/workspace_providers.dart';

/// The shipped build must never invent workspace content: with the default
/// `USE_MOCK=false` the workspace screens read from the API, so the local
/// projection starts empty instead of falling back to sample records.
void main() {
  test('default build does not serve demo workspace data', () async {
    expect(AppConfig.useMockData, isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final snapshot = await container.read(workspaceSnapshotProvider.future);
    expect(snapshot.members, isEmpty);
    expect(snapshot.isEmpty, isTrue);
    expect(snapshot.pullRequests, isEmpty);
    expect(snapshot.notifications, isEmpty);
    expect(snapshot.clientReport, isNull);
  });

  test('workspace selectors return empty lists instead of throwing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(workspaceMembersProvider), isEmpty);
    expect(container.read(workspaceNotificationsProvider), isEmpty);
    expect(container.read(workspaceLabelsProvider), isEmpty);
    expect(container.read(clientReportProvider), isNull);
  });
}
