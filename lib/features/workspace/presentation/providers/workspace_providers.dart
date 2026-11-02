import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/demo/demo_data.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/workspace_remote_data_source.dart';
import '../../data/repositories/workspace_repository_impl.dart';
import '../../domain/entities/workspace_snapshot.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../../domain/usecases/workspace_usecases.dart';

final workspaceRemoteDataSourceProvider = Provider<WorkspaceRemoteDataSource>(
  (ref) => WorkspaceRemoteDataSource(ref.watch(dioProvider)),
);

/// The workspace the app is currently scoped to. Taken from the API in a
/// normal build; the demo workspace id is only used in demo mode.
final workspaceIdProvider = Provider<String>((ref) {
  if (AppConfig.useMockData) return 'w-1';
  return ref.watch(authNotifierProvider).value?.id ?? '';
});

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  return WorkspaceRepositoryImpl(
    remote: ref.watch(workspaceRemoteDataSourceProvider),
    workspaceId: ref.watch(workspaceIdProvider),
  );
});

final getWorkspaceSnapshotProvider = Provider<GetWorkspaceSnapshot>(
  (ref) => GetWorkspaceSnapshot(ref.watch(workspaceRepositoryProvider)),
);

final sendInvitesProvider = Provider<SendInvites>(
  (ref) => SendInvites(ref.watch(workspaceRepositoryProvider)),
);

/// The whole workspace projection.
///
/// It never throws: when the API is unreachable the provider resolves to an
/// empty snapshot and [workspaceErrorProvider] carries the reason, so every
/// screen can render an honest empty/error state instead of crashing.
final workspaceSnapshotProvider = FutureProvider<WorkspaceSnapshot>((ref) async {
  if (AppConfig.useMockData) {
    return DemoData.snapshot;
  }
  try {
    return await ref.watch(getWorkspaceSnapshotProvider).call();
  } catch (error) {
    ref.read(workspaceErrorProvider.notifier).setError(error.toString());
    return const WorkspaceSnapshot();
  }
});

/// Last error raised while loading the workspace snapshot.
class WorkspaceErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String message) => state = message;
}

final workspaceErrorProvider =
    NotifierProvider<WorkspaceErrorNotifier, String?>(
  WorkspaceErrorNotifier.new,
);

/// Convenience selectors — they never throw, they expose empty lists.
final workspaceMembersProvider = Provider<List<WorkspaceMember>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.members ?? const [];
});

final workspaceInvitesProvider = Provider<List<WorkspaceInvite>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.invites ?? const [];
});

final workspaceActivityProvider = Provider<List<ActivityEvent>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.activity ?? const [];
});

final workspaceSprintsProvider = Provider<List<Sprint>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.sprints ?? const [];
});

final workspacePullRequestsProvider = Provider<List<PullRequest>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.pullRequests ?? const [];
});

final workspaceLabelsProvider = Provider<List<ProjectLabel>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.labels ?? const [];
});

final workspaceIntegrationsProvider = Provider<List<ProjectIntegration>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.integrations ?? const [];
});

final workspaceRepositoriesProvider = Provider<List<LinkedRepository>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.repositories ?? const [];
});

final workspaceNotificationsProvider = Provider<List<AppNotification>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.notifications ?? const [];
});

final workspaceDigestProvider = Provider<List<DigestEntry>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.digest ?? const [];
});

final workspaceWorkloadProvider = Provider<List<WorkloadEntry>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.workload ?? const [];
});

final workspaceSuggestionsProvider = Provider<List<WorkloadSuggestion>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.workloadSuggestions ?? const [];
});

final clientReportProvider = Provider<ClientReport?>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.clientReport;
});

final commentsForTaskProvider = Provider.family<List<TaskComment>, String>(
  (ref, taskId) {
    return ref.watch(workspaceSnapshotProvider).value?.commentsFor(taskId) ??
        const [];
  },
);

final subtasksForTaskProvider = Provider.family<List<TaskSubtask>, String>(
  (ref, taskId) {
    return ref.watch(workspaceSnapshotProvider).value?.subtasksFor(taskId) ??
        const [];
  },
);

final pullRequestProvider = Provider.family<PullRequest?, int>((ref, number) {
  return ref.watch(workspaceSnapshotProvider).value?.pullRequestByNumber(number);
});


// --- selectors for the remaining screens -----------------------------------

final workspaceAgentsProvider = Provider<List<WorkspaceAgent>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.agents ?? const [];
});

final agentRulesProvider = Provider<List<AgentRule>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.agentRules ?? const [];
});

final knowledgeAreasProvider = Provider<List<KnowledgeArea>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.knowledgeAreas ?? const [];
});

final workspaceCommitsProvider = Provider<List<CommitEntry>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.commits ?? const [];
});

final workspaceReleasesProvider = Provider<List<ReleaseNote>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.releases ?? const [];
});

final workspaceDependenciesProvider = Provider<List<TaskDependency>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.dependencies ?? const [];
});

final workspaceJoinRequestsProvider = Provider<List<InviteRequest>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.joinRequests ?? const [];
});

final unlinkedContributorsProvider = Provider<List<UnlinkedContributor>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.unlinkedContributors ??
      const [];
});

final codePlatformsProvider = Provider<List<CodePlatform>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.codePlatforms ?? const [];
});

final estimateRecordsProvider = Provider<List<EstimateRecord>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.estimateRecords ?? const [];
});

final sprintRetrosProvider = Provider<List<SprintRetro>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.sprintRetros ?? const [];
});

final weeklyClientSummariesProvider = Provider<List<WeeklyClientSummary>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.weeklyClientSummaries ??
      const [];
});

final projectReportsProvider = Provider<List<ProjectReport>>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.projectReports ?? const [];
});

final regionalCalendarProvider = Provider<RegionalCalendar?>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.regionalCalendar;
});

final billingProvider = Provider<BillingSummary?>((ref) {
  return ref.watch(workspaceSnapshotProvider).value?.billing;
});
