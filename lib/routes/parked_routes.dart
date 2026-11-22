// Parked screens: built, but switched off for the stable release.
//
// Every route here is a screen with no backend yet (mock or always-empty
// data), a design-state demo, or a duplicate of a working screen. They are
// NOT registered in the router; the reasons, the purpose, the scope and
// what each needs to come back are in docs/parked-screens.md.
//
// To bring one back: build what docs/parked-screens.md lists for it, move
// its GoRoute into `routes:` in app_router.dart, and restore its links.
// ignore_for_file: unused_import
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/pages/account_pages.dart';
import '../features/groups/domain/group_models.dart';
import '../features/groups/presentation/widgets/group_widgets.dart';
import '../features/reviews/presentation/pages/review_pages.dart';
import '../features/setup/presentation/pages/setup_checklist_page.dart';
import '../features/sprints/presentation/pages/sprint_pages.dart';
import '../features/tasks/presentation/pages/task_flow_pages.dart';
import '../features/team/presentation/pages/team_pages.dart';
import '../features/web/presentation/pages/web_shell_page.dart';
import '../features/workspace/presentation/pages/github_flow_pages.dart';
import '../features/workspace/presentation/pages/insight_pages.dart';
import '../features/workspace/presentation/pages/state_pages.dart';
import '../features/workspace/presentation/pages/workspace_flow_pages.dart';
import 'app_router.dart';
import '../features/web/presentation/pages/web_routes.dart';

/// Not registered anywhere — kept so a parked screen returns in one move.
List<RouteBase> parkedRoutes() => [
      GoRoute(
        path: AppRoutes.setup,
        builder: (_, __) => const SetupChecklistPage(),
      ),
      GoRoute(
        path: AppRoutes.focusMode,
        builder: (_, __) => const FocusModePage(),
      ),
      GoRoute(
        path: AppRoutes.help,
        builder: (_, __) => const HelpPage(),
      ),
      GoRoute(
        path: AppRoutes.notifSettings,
        builder: (_, __) => const NotifSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.workspaceCreate,
        builder: (_, __) => const WorkspaceCreatePage(),
      ),
      GoRoute(
        path: AppRoutes.workspaceSwitch,
        builder: (_, __) => const WorkspaceSwitchPage(),
      ),
      GoRoute(
        path: AppRoutes.linkGitHub,
        builder: (_, __) => const LinkGitHubPage(),
      ),
      GoRoute(
        path: AppRoutes.inviteExpired,
        builder: (_, __) => const InviteExpiredPage(),
      ),
      GoRoute(
        path: AppRoutes.exportData,
        builder: (_, __) => const ActiveGroupGuard(
          requires: Caps.manageGroup,
          child: ExportDataPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.regionalCalendar,
        builder: (_, __) => const RegionalCalendarPage(),
      ),
      GoRoute(
        path: AppRoutes.billing,
        builder: (_, __) => const ActiveGroupGuard(
          requires: Caps.manageGroup,
          child: BillingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.askProject,
        builder: (_, __) => const AskProjectPage(),
      ),
      GoRoute(
        path: AppRoutes.bugReport,
        builder: (_, __) => const BugReportPage(),
      ),
      // The whole website + web app: one route per design screen.
      GoRoute(
        path: AppRoutes.web,
        builder: (context, state) {
          final path = state.uri.path
              .replaceFirst(AppRoutes.web, '')
              .replaceFirst(RegExp(r'^/'), '');
          final route = webRouteFor(path);
          return WebShellPage(
            route: route ??
                const WebRoute(
                  path: '',
                  title: 'الصفحة غير موجودة',
                  section: 'الحالات والنسخ',
                ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.agentsTeam,
        builder: (_, __) => const AgentsTeamPage(),
      ),
      GoRoute(
        path: AppRoutes.assignAgent,
        builder: (_, __) => const AssignAgentPage(),
      ),
      GoRoute(
        path: AppRoutes.knowledgeMap,
        builder: (_, __) => const KnowledgeMapPage(),
      ),
      GoRoute(
        path: AppRoutes.projectReport,
        builder: (_, __) => const ProjectReportPage(),
      ),
      GoRoute(
        path: AppRoutes.estimateLearning,
        builder: (_, __) => const EstimateLearningPage(),
      ),
      GoRoute(
        path: AppRoutes.sprintHistory,
        builder: (_, __) => const SprintHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.commits,
        builder: (_, __) => const CommitsPage(),
      ),
      GoRoute(
        path: AppRoutes.releaseTracker,
        builder: (_, __) => const ReleaseTrackerPage(),
      ),
      GoRoute(
        path: AppRoutes.weeklySummary,
        builder: (_, __) => const WeeklyClientSummaryPage(),
      ),
      GoRoute(
        path: AppRoutes.ghInstalling,
        builder: (_, __) => const GhInstallingPage(),
      ),
      GoRoute(
        path: AppRoutes.mapContributors,
        builder: (_, __) => const MapContributorsPage(),
      ),
      GoRoute(
        path: AppRoutes.multiProvider,
        builder: (_, __) => const MultiProviderPage(),
      ),
      GoRoute(
        path: AppRoutes.workload,
        builder: (_, __) => const WorkloadPage(),
      ),
      GoRoute(
        path: AppRoutes.ghAppInstall,
        builder: (_, __) => const GhAppInstallPage(),
      ),
      GoRoute(
        path: AppRoutes.importIssues,
        builder: (_, __) => const ImportIssuesPage(),
      ),
      GoRoute(
        path: AppRoutes.joinRequests,
        builder: (_, __) => const JoinRequestsPage(),
      ),
      GoRoute(
        path: AppRoutes.reviewerPick,
        builder: (_, __) => const ReviewerPickPage(),
      ),
      GoRoute(
        path: AppRoutes.bigPrWarning,
        builder: (_, __) => const BigPrWarningPage(),
      ),
      GoRoute(
        path: AppRoutes.mergeFromApp,
        builder: (_, __) => const MergeFromAppPage(),
      ),
      GoRoute(
        path: AppRoutes.reviewSla,
        builder: (_, __) => const ReviewSlaPage(),
      ),
      GoRoute(
        path: AppRoutes.ciFailure,
        builder: (_, __) => const CiFailurePage(),
      ),
      GoRoute(
        path: AppRoutes.sprintSummary,
        builder: (_, __) => const SprintSummaryPage(),
      ),
      GoRoute(
        path: AppRoutes.editTask,
        builder: (_, __) => const EditTaskPage(),
      ),
      GoRoute(
        path: AppRoutes.taskStatus,
        builder: (_, __) => const StatusSheetPage(),
      ),
      GoRoute(
        path: AppRoutes.taskDependencies,
        builder: (_, __) => const DependenciesPage(),
      ),
      GoRoute(
        path: AppRoutes.taskContext,
        builder: (_, __) => const TaskContextPage(),
      ),
      GoRoute(
        path: AppRoutes.bulkActions,
        builder: (_, __) => const BulkActionsPage(),
      ),
      GoRoute(
        path: AppRoutes.bulkInvite,
        builder: (_, __) => const ActiveGroupGuard(
          requires: Caps.manageMembers,
          child: BulkInvitePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.offline,
        builder: (_, __) => const OfflinePage(),
      ),
      GoRoute(
        path: AppRoutes.syncFailed,
        builder: (_, __) => const SyncFailedPage(),
      ),
      GoRoute(
        path: AppRoutes.accessRevoked,
        builder: (_, __) => const AccessRevokedPage(),
      ),
      GoRoute(
        path: AppRoutes.noPermission,
        builder: (_, __) => const NoPermissionPage(),
      ),
      GoRoute(
        path: AppRoutes.notFound,
        builder: (_, __) => const NotFoundPage(),
      ),
      GoRoute(
        path: AppRoutes.emptyProjects,
        builder: (_, __) => const EmptyProjectsPage(),
      ),
      GoRoute(
        path: AppRoutes.skeleton,
        builder: (_, __) => const SkeletonPage(),
      ),
      GoRoute(
        path: AppRoutes.pushPermission,
        builder: (_, __) => const PushPermissionPage(),
      ),
      GoRoute(
        path: AppRoutes.richNotification,
        builder: (_, __) => const RichNotificationPage(),
      ),
    ];
