import 'package:auto_route/auto_route.dart';

import 'auto_router_config.gr.dart';

/// Typed route table (AutoRoute).
///
/// The application shell runs on `go_router` (see [AppRoutes]) because it
/// gives us deep links, redirect guards and a stateful bottom-navigation
/// shell. AutoRoute is used as the *typed* source of truth for every screen:
/// it validates the argument types of each route and generates the
/// `auto_router_config.gr.dart` file that can be consumed by any other
/// package (web deep links, notification payloads, tests).
@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouterConfig extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: SplashRoute.page, path: '/', initial: true),
        AutoRoute(page: OnboardingRoute.page, path: '/onboarding'),
        AutoRoute(page: LoginRoute.page, path: '/login'),
        AutoRoute(page: SignUpRoute.page, path: '/signup'),
        AutoRoute(page: VerifyOtpRoute.page, path: '/verify-otp'),
        AutoRoute(page: SetupChecklistRoute.page, path: '/setup'),
        AutoRoute(page: ProjectsRoute.page, path: '/home/projects'),
        AutoRoute(page: MyTasksRoute.page, path: '/home/my-tasks'),
        AutoRoute(page: ReviewsRoute.page, path: '/home/reviews'),
        AutoRoute(page: ProfileRoute.page, path: '/home/account'),
        AutoRoute(page: NotificationsRoute.page, path: '/notifications'),
        AutoRoute(page: CreateProjectRoute.page, path: '/projects/new'),
        AutoRoute(
          page: ConnectRepositoryRoute.page,
          path: '/projects/connect-repository',
        ),
        AutoRoute(page: TaskBoardRoute.page, path: '/tasks/board'),
        AutoRoute(page: TaskDetailRoute.page, path: '/tasks/:id'),
      ];
}
