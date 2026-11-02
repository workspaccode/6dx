import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/onboarding_page.dart';
import '../features/auth/presentation/pages/sign_up_page.dart';
import '../features/auth/presentation/pages/verify_otp_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/clients/presentation/pages/client_pages.dart';
import '../features/github/presentation/pages/connect_repository_page.dart';
import '../features/home/presentation/pages/home_shell.dart';
import '../features/home/presentation/pages/my_tasks_page.dart';
import '../features/home/presentation/pages/reviews_page.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/projects/presentation/pages/create_project_page.dart';
import '../features/projects/presentation/pages/project_settings_pages.dart';
import '../features/projects/presentation/pages/projects_page.dart';
import '../features/setup/presentation/pages/setup_checklist_page.dart';
import '../features/sprints/presentation/pages/sprint_pages.dart';
import '../features/tasks/domain/entities/task.dart';
import '../features/tasks/presentation/pages/task_board_page.dart';
import '../features/tasks/presentation/providers/task_providers.dart';
import '../features/tasks/presentation/pages/task_detail_page.dart';
import '../features/tasks/presentation/pages/task_extras_page.dart';
import '../features/tasks/presentation/pages/task_views_page.dart';
import '../features/tasks/presentation/pages/new_task_page.dart';
import '../features/members/presentation/pages/member_pages.dart';
import '../features/reviews/presentation/pages/review_pages.dart';
import '../features/team/presentation/pages/team_pages.dart';
import '../features/account/presentation/pages/account_pages.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signUp = '/signup';
  static const String verifyOtp = '/verify-otp';
  static const String setup = '/setup';

  static const String home = '/home';
  static const String projects = '/home/projects';
  static const String myTasks = '/home/my-tasks';
  static const String reviews = '/home/reviews';
  static const String account = '/home/account';

  static const String notifications = '/notifications';
  static const String createProject = '/projects/new';
  static const String connectRepository = '/projects/connect-repository';
  static const String projectSettings = '/projects/settings';
  static const String syncSettings = '/projects/sync';
  static const String labels = '/projects/labels';
  static const String integrations = '/projects/integrations';
  static const String activityLog = '/projects/activity';
  static const String archiveProject = '/projects/archive';
  static const String members = '/projects/members';
  static const String invite = '/projects/invite';
  static const String taskBoard = '/tasks/board';
  static const String taskDetail = '/tasks/:id';
  static const String newTask = '/tasks/new';
  static const String taskList = '/tasks/list';
  static const String taskCalendar = '/tasks/calendar';
  static const String taskSearch = '/tasks/search';
  static const String backlog = '/sprints/backlog';
  static const String sprintPlan = '/sprints/plan';
  static const String sprintSummary = '/sprints/summary';
  static const String prDetail = '/reviews/pr/:number';
  static const String ciFailure = '/reviews/ci-failure';
  static const String reviewSla = '/reviews/sla';
  static const String accountSettings = '/settings/account';
  static const String notifSettings = '/settings/notifications';
  static const String focusMode = '/settings/focus';
  static const String help = '/settings/help';
  static const String workspaceCreate = '/workspace/new';
  static const String workload = '/team/workload';
  static const String digest = '/team/digest';
  static const String clientPortal = '/clients/portal';
  static const String invoice = '/clients/invoice';
  static const String timeTracking = '/clients/time';

  /// Concrete location of a task detail screen.
  static String taskDetailPath(String id) => '/tasks/$id';

  /// Concrete location of a task's subtasks screen.
  static String subtasksPath(String id) => '/tasks/$id/subtasks';

  /// Concrete location of a task's comments screen.
  static String commentsPath(String id) => '/tasks/$id/comments';

  /// Concrete location of a pull-request detail screen.
  static String prDetailPath(String number) => '/reviews/pr/$number';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final location = state.matchedLocation;

      // While the session is being restored, keep the splash screen.
      if (auth.isLoading && location == AppRoutes.splash) return null;

      final isSignedIn = auth.value != null;
      final isPublicRoute = const {
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.signUp,
        AppRoutes.verifyOtp,
      }.contains(location);

      if (!isSignedIn && !isPublicRoute) return AppRoutes.login;
      if (isSignedIn &&
          (location == AppRoutes.login || location == AppRoutes.signUp)) {
        return AppRoutes.home;
      }
      // The bottom-navigation shell only exposes its branches, so `/home`
      // resolves to the first branch (projects).
      if (location == AppRoutes.home) return AppRoutes.projects;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (_, __) => const SignUpPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyOtp,
        builder: (_, __) => const VerifyOtpPage(),
      ),
      GoRoute(
        path: AppRoutes.setup,
        builder: (_, __) => const SetupChecklistPage(),
      ),

      // Bottom navigation shell — each branch keeps its own navigation stack.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.projects,
                builder: (_, __) => const ProjectsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myTasks,
                builder: (_, __) => const MyTasksPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reviews,
                builder: (_, __) => const ReviewsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.account,
                builder: (_, __) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, __) => const NotificationsPage(),
      ),
      GoRoute(
        path: AppRoutes.createProject,
        builder: (_, __) => const CreateProjectPage(),
      ),
      GoRoute(
        path: AppRoutes.connectRepository,
        builder: (_, __) => const ConnectRepositoryPage(),
      ),
      GoRoute(
        path: AppRoutes.taskBoard,
        builder: (_, __) => const TaskBoardPage(),
      ),
      // Static task routes must be registered before `/tasks/:id` so they are
      // not swallowed by the `:id` parameter.
      GoRoute(
        path: AppRoutes.newTask,
        builder: (_, __) => const NewTaskPage(),
      ),
      GoRoute(
        path: AppRoutes.taskList,
        builder: (_, __) => const TaskListPage(),
      ),
      GoRoute(
        path: AppRoutes.taskCalendar,
        builder: (_, __) => const TaskCalendarPage(),
      ),
      GoRoute(
        path: AppRoutes.taskSearch,
        builder: (_, __) => const TaskSearchPage(),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        builder: (context, state) => TaskDetailPage(
          taskId: state.pathParameters['id'] ?? '',
        ),
        routes: [
          GoRoute(
            path: 'subtasks',
            builder: (context, state) {
              final tasks =
                  ref.read(tasksNotifierProvider).value ?? const <Task>[];
              final id = state.pathParameters['id'] ?? '';
              final task = tasks
                      .where((t) => t.id == id)
                      .firstOrNull ??
                  Task(id: id, title: 'مهمة');
              return SubtasksPage(task: task);
            },
          ),
          GoRoute(
            path: 'comments',
            builder: (context, state) => CommentsPage(
              taskKey: state.pathParameters['id'] ?? 'MOB-24',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.backlog,
        builder: (_, __) => const BacklogPage(),
      ),
      GoRoute(
        path: AppRoutes.sprintPlan,
        builder: (_, __) => const SprintPlanPage(),
      ),
      GoRoute(
        path: AppRoutes.sprintSummary,
        builder: (_, __) => const SprintSummaryPage(),
      ),
      GoRoute(
        path: AppRoutes.prDetail,
        builder: (context, state) => PrDetailPage(
          prNumber: int.tryParse(state.pathParameters['number'] ?? '') ?? 58,
        ),
      ),
      GoRoute(
        path: AppRoutes.ciFailure,
        builder: (_, __) => const CiFailurePage(),
      ),
      GoRoute(
        path: AppRoutes.reviewSla,
        builder: (_, __) => const ReviewSlaPage(),
      ),
      GoRoute(
        path: AppRoutes.projectSettings,
        builder: (_, __) => const ProjectSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.syncSettings,
        builder: (_, __) => const SyncSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.labels,
        builder: (_, __) => const LabelsPage(),
      ),
      GoRoute(
        path: AppRoutes.integrations,
        builder: (_, __) => const IntegrationsPage(),
      ),
      GoRoute(
        path: AppRoutes.activityLog,
        builder: (_, __) => const ActivityLogPage(),
      ),
      GoRoute(
        path: AppRoutes.archiveProject,
        builder: (_, __) => const ArchivePage(),
      ),
      GoRoute(
        path: AppRoutes.members,
        builder: (_, __) => const MembersPage(),
      ),
      GoRoute(
        path: AppRoutes.invite,
        builder: (_, __) => const InvitePage(),
      ),
      GoRoute(
        path: AppRoutes.accountSettings,
        builder: (_, __) => const AccountSettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.notifSettings,
        builder: (_, __) => const NotifSettingsPage(),
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
        path: AppRoutes.workspaceCreate,
        builder: (_, __) => const WorkspaceCreatePage(),
      ),
      GoRoute(
        path: AppRoutes.workload,
        builder: (_, __) => const WorkloadPage(),
      ),
      GoRoute(
        path: AppRoutes.digest,
        builder: (_, __) => const DigestPage(),
      ),
      GoRoute(
        path: AppRoutes.clientPortal,
        builder: (_, __) => const ClientPortalPage(),
      ),
      GoRoute(
        path: AppRoutes.invoice,
        builder: (_, __) => const InvoicePage(),
      ),
      GoRoute(
        path: AppRoutes.timeTracking,
        builder: (_, __) => const TimeTrackingPage(),
      ),
    ],
  );
});

/// Splash screen: decides where to send the user based on the session.
@RoutePage()
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.isLoading) return;
      final user = next.value;
      context.go(user == null ? AppRoutes.onboarding : AppRoutes.home);
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
