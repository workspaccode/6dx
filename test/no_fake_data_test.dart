import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/workspace/presentation/providers/workspace_providers.dart';

/// The app must never invent workspace content: without a session (and without
/// any row in the database) every screen renders an honest empty state.
void main() {
  test('an unauthenticated build is an error state, never invented content', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // A failed load is reported as an error (the screens show it with a
    // retry), not disguised as an empty workspace…
    await expectLater(container.read(workspaceSnapshotProvider.future), throwsA(anything));
    // …and the selectors still give empty lists, so nothing renders fake data.
    expect(container.read(workspaceMembersProvider), isEmpty);
    expect(container.read(workspacePullRequestsProvider), isEmpty);
    expect(container.read(clientReportProvider), isNull);
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
