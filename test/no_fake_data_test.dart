import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/workspace/presentation/providers/workspace_providers.dart';

/// The app must never invent workspace content: without a session (and without
/// any row in the database) every screen renders an honest empty state.
void main() {
  test('an unauthenticated build serves an empty workspace', () async {
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
