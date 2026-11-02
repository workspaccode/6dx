import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/onboarding_page.dart';
import '../features/auth/presentation/pages/sign_up_page.dart';
import '../features/auth/presentation/pages/verify_otp_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/github/presentation/pages/connect_repository_page.dart';
import '../features/home/presentation/pages/home_shell.dart';
import '../features/home/presentation/pages/my_tasks_page.dart';
import '../features/home/presentation/pages/reviews_page.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/projects/presentation/pages/create_project_page.dart';
import '../features/projects/presentation/pages/projects_page.dart';
import '../features/setup/presentation/pages/setup_checklist_page.dart';
import '../features/tasks/presentation/pages/task_board_page.dart';
import '../features/tasks/presentation/pages/task_detail_page.dart';

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
  static const String taskBoard = '/tasks/board';
  static const String taskDetail = '/tasks/:id';

  /// Concrete location of a task detail screen.
  static String taskDetailPath(String id) => '/tasks/$id';
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
      GoRoute(
        path: AppRoutes.taskDetail,
        builder: (context, state) => TaskDetailPage(
          taskId: state.pathParameters['id'] ?? '',
        ),
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
