// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i26;
import 'package:flutter/material.dart' as _i27;
import 'package:sixdx/features/account/presentation/pages/account_pages.dart'
    as _i1;
import 'package:sixdx/features/auth/presentation/pages/login_page.dart' as _i11;
import 'package:sixdx/features/auth/presentation/pages/onboarding_page.dart'
    as _i15;
import 'package:sixdx/features/auth/presentation/pages/sign_up_page.dart'
    as _i20;
import 'package:sixdx/features/auth/presentation/pages/verify_otp_page.dart'
    as _i25;
import 'package:sixdx/features/clients/presentation/pages/client_pages.dart'
    as _i5;
import 'package:sixdx/features/github/presentation/pages/connect_repository_page.dart'
    as _i7;
import 'package:sixdx/features/home/presentation/pages/my_tasks_page.dart'
    as _i12;
import 'package:sixdx/features/home/presentation/pages/reviews_page.dart'
    as _i18;
import 'package:sixdx/features/members/presentation/pages/member_pages.dart'
    as _i10;
import 'package:sixdx/features/notifications/presentation/pages/notifications_page.dart'
    as _i14;
import 'package:sixdx/features/profile/presentation/pages/profile_page.dart'
    as _i16;
import 'package:sixdx/features/projects/presentation/pages/create_project_page.dart'
    as _i8;
import 'package:sixdx/features/projects/presentation/pages/project_settings_pages.dart'
    as _i2;
import 'package:sixdx/features/projects/presentation/pages/projects_page.dart'
    as _i17;
import 'package:sixdx/features/reviews/presentation/pages/review_pages.dart'
    as _i4;
import 'package:sixdx/features/setup/presentation/pages/setup_checklist_page.dart'
    as _i19;
import 'package:sixdx/features/sprints/presentation/pages/sprint_pages.dart'
    as _i3;
import 'package:sixdx/features/tasks/domain/entities/task.dart' as _i28;
import 'package:sixdx/features/tasks/presentation/pages/new_task_page.dart'
    as _i13;
import 'package:sixdx/features/tasks/presentation/pages/task_board_page.dart'
    as _i22;
import 'package:sixdx/features/tasks/presentation/pages/task_detail_page.dart'
    as _i24;
import 'package:sixdx/features/tasks/presentation/pages/task_extras_page.dart'
    as _i6;
import 'package:sixdx/features/tasks/presentation/pages/task_views_page.dart'
    as _i23;
import 'package:sixdx/features/team/presentation/pages/team_pages.dart' as _i9;
import 'package:sixdx/routes/app_router.dart' as _i21;

/// generated route for
/// [_i1.AccountSettingsPage]
class AccountSettingsRoute extends _i26.PageRouteInfo<void> {
  const AccountSettingsRoute({List<_i26.PageRouteInfo>? children})
    : super(AccountSettingsRoute.name, initialChildren: children);

  static const String name = 'AccountSettingsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i1.AccountSettingsPage();
    },
  );
}

/// generated route for
/// [_i2.ActivityLogPage]
class ActivityLogRoute extends _i26.PageRouteInfo<void> {
  const ActivityLogRoute({List<_i26.PageRouteInfo>? children})
    : super(ActivityLogRoute.name, initialChildren: children);

  static const String name = 'ActivityLogRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i2.ActivityLogPage();
    },
  );
}

/// generated route for
/// [_i2.ArchivePage]
class ArchiveRoute extends _i26.PageRouteInfo<void> {
  const ArchiveRoute({List<_i26.PageRouteInfo>? children})
    : super(ArchiveRoute.name, initialChildren: children);

  static const String name = 'ArchiveRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i2.ArchivePage();
    },
  );
}

/// generated route for
/// [_i3.BacklogPage]
class BacklogRoute extends _i26.PageRouteInfo<void> {
  const BacklogRoute({List<_i26.PageRouteInfo>? children})
    : super(BacklogRoute.name, initialChildren: children);

  static const String name = 'BacklogRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i3.BacklogPage();
    },
  );
}

/// generated route for
/// [_i4.CiFailurePage]
class CiFailureRoute extends _i26.PageRouteInfo<void> {
  const CiFailureRoute({List<_i26.PageRouteInfo>? children})
    : super(CiFailureRoute.name, initialChildren: children);

  static const String name = 'CiFailureRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i4.CiFailurePage();
    },
  );
}

/// generated route for
/// [_i5.ClientPortalPage]
class ClientPortalRoute extends _i26.PageRouteInfo<void> {
  const ClientPortalRoute({List<_i26.PageRouteInfo>? children})
    : super(ClientPortalRoute.name, initialChildren: children);

  static const String name = 'ClientPortalRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i5.ClientPortalPage();
    },
  );
}

/// generated route for
/// [_i6.CommentsPage]
class CommentsRoute extends _i26.PageRouteInfo<CommentsRouteArgs> {
  CommentsRoute({
    _i27.Key? key,
    String taskKey = 'MOB-24',
    List<_i26.PageRouteInfo>? children,
  }) : super(
         CommentsRoute.name,
         args: CommentsRouteArgs(key: key, taskKey: taskKey),
         initialChildren: children,
       );

  static const String name = 'CommentsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CommentsRouteArgs>(
        orElse: () => const CommentsRouteArgs(),
      );
      return _i6.CommentsPage(key: args.key, taskKey: args.taskKey);
    },
  );
}

class CommentsRouteArgs {
  const CommentsRouteArgs({this.key, this.taskKey = 'MOB-24'});

  final _i27.Key? key;

  final String taskKey;

  @override
  String toString() {
    return 'CommentsRouteArgs{key: $key, taskKey: $taskKey}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CommentsRouteArgs) return false;
    return key == other.key && taskKey == other.taskKey;
  }

  @override
  int get hashCode => key.hashCode ^ taskKey.hashCode;
}

/// generated route for
/// [_i7.ConnectRepositoryPage]
class ConnectRepositoryRoute extends _i26.PageRouteInfo<void> {
  const ConnectRepositoryRoute({List<_i26.PageRouteInfo>? children})
    : super(ConnectRepositoryRoute.name, initialChildren: children);

  static const String name = 'ConnectRepositoryRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i7.ConnectRepositoryPage();
    },
  );
}

/// generated route for
/// [_i8.CreateProjectPage]
class CreateProjectRoute extends _i26.PageRouteInfo<void> {
  const CreateProjectRoute({List<_i26.PageRouteInfo>? children})
    : super(CreateProjectRoute.name, initialChildren: children);

  static const String name = 'CreateProjectRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i8.CreateProjectPage();
    },
  );
}

/// generated route for
/// [_i9.DigestPage]
class DigestRoute extends _i26.PageRouteInfo<void> {
  const DigestRoute({List<_i26.PageRouteInfo>? children})
    : super(DigestRoute.name, initialChildren: children);

  static const String name = 'DigestRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i9.DigestPage();
    },
  );
}

/// generated route for
/// [_i1.FocusModePage]
class FocusModeRoute extends _i26.PageRouteInfo<void> {
  const FocusModeRoute({List<_i26.PageRouteInfo>? children})
    : super(FocusModeRoute.name, initialChildren: children);

  static const String name = 'FocusModeRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i1.FocusModePage();
    },
  );
}

/// generated route for
/// [_i1.HelpPage]
class HelpRoute extends _i26.PageRouteInfo<void> {
  const HelpRoute({List<_i26.PageRouteInfo>? children})
    : super(HelpRoute.name, initialChildren: children);

  static const String name = 'HelpRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i1.HelpPage();
    },
  );
}

/// generated route for
/// [_i2.IntegrationsPage]
class IntegrationsRoute extends _i26.PageRouteInfo<void> {
  const IntegrationsRoute({List<_i26.PageRouteInfo>? children})
    : super(IntegrationsRoute.name, initialChildren: children);

  static const String name = 'IntegrationsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i2.IntegrationsPage();
    },
  );
}

/// generated route for
/// [_i10.InvitePage]
class InviteRoute extends _i26.PageRouteInfo<void> {
  const InviteRoute({List<_i26.PageRouteInfo>? children})
    : super(InviteRoute.name, initialChildren: children);

  static const String name = 'InviteRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i10.InvitePage();
    },
  );
}

/// generated route for
/// [_i5.InvoicePage]
class InvoiceRoute extends _i26.PageRouteInfo<void> {
  const InvoiceRoute({List<_i26.PageRouteInfo>? children})
    : super(InvoiceRoute.name, initialChildren: children);

  static const String name = 'InvoiceRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i5.InvoicePage();
    },
  );
}

/// generated route for
/// [_i2.LabelsPage]
class LabelsRoute extends _i26.PageRouteInfo<void> {
  const LabelsRoute({List<_i26.PageRouteInfo>? children})
    : super(LabelsRoute.name, initialChildren: children);

  static const String name = 'LabelsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i2.LabelsPage();
    },
  );
}

/// generated route for
/// [_i11.LoginPage]
class LoginRoute extends _i26.PageRouteInfo<void> {
  const LoginRoute({List<_i26.PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i11.LoginPage();
    },
  );
}

/// generated route for
/// [_i10.MembersPage]
class MembersRoute extends _i26.PageRouteInfo<void> {
  const MembersRoute({List<_i26.PageRouteInfo>? children})
    : super(MembersRoute.name, initialChildren: children);

  static const String name = 'MembersRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i10.MembersPage();
    },
  );
}

/// generated route for
/// [_i12.MyTasksPage]
class MyTasksRoute extends _i26.PageRouteInfo<void> {
  const MyTasksRoute({List<_i26.PageRouteInfo>? children})
    : super(MyTasksRoute.name, initialChildren: children);

  static const String name = 'MyTasksRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i12.MyTasksPage();
    },
  );
}

/// generated route for
/// [_i13.NewTaskPage]
class NewTaskRoute extends _i26.PageRouteInfo<void> {
  const NewTaskRoute({List<_i26.PageRouteInfo>? children})
    : super(NewTaskRoute.name, initialChildren: children);

  static const String name = 'NewTaskRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i13.NewTaskPage();
    },
  );
}

/// generated route for
/// [_i1.NotifSettingsPage]
class NotifSettingsRoute extends _i26.PageRouteInfo<void> {
  const NotifSettingsRoute({List<_i26.PageRouteInfo>? children})
    : super(NotifSettingsRoute.name, initialChildren: children);

  static const String name = 'NotifSettingsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i1.NotifSettingsPage();
    },
  );
}

/// generated route for
/// [_i14.NotificationsPage]
class NotificationsRoute extends _i26.PageRouteInfo<void> {
  const NotificationsRoute({List<_i26.PageRouteInfo>? children})
    : super(NotificationsRoute.name, initialChildren: children);

  static const String name = 'NotificationsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i14.NotificationsPage();
    },
  );
}

/// generated route for
/// [_i15.OnboardingPage]
class OnboardingRoute extends _i26.PageRouteInfo<void> {
  const OnboardingRoute({List<_i26.PageRouteInfo>? children})
    : super(OnboardingRoute.name, initialChildren: children);

  static const String name = 'OnboardingRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i15.OnboardingPage();
    },
  );
}

/// generated route for
/// [_i4.PrDetailPage]
class PrDetailRoute extends _i26.PageRouteInfo<PrDetailRouteArgs> {
  PrDetailRoute({
    _i27.Key? key,
    String prNumber = '58',
    List<_i26.PageRouteInfo>? children,
  }) : super(
         PrDetailRoute.name,
         args: PrDetailRouteArgs(key: key, prNumber: prNumber),
         initialChildren: children,
       );

  static const String name = 'PrDetailRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrDetailRouteArgs>(
        orElse: () => const PrDetailRouteArgs(),
      );
      return _i4.PrDetailPage(key: args.key, prNumber: args.prNumber);
    },
  );
}

class PrDetailRouteArgs {
  const PrDetailRouteArgs({this.key, this.prNumber = '58'});

  final _i27.Key? key;

  final String prNumber;

  @override
  String toString() {
    return 'PrDetailRouteArgs{key: $key, prNumber: $prNumber}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PrDetailRouteArgs) return false;
    return key == other.key && prNumber == other.prNumber;
  }

  @override
  int get hashCode => key.hashCode ^ prNumber.hashCode;
}

/// generated route for
/// [_i16.ProfilePage]
class ProfileRoute extends _i26.PageRouteInfo<void> {
  const ProfileRoute({List<_i26.PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i16.ProfilePage();
    },
  );
}

/// generated route for
/// [_i2.ProjectSettingsPage]
class ProjectSettingsRoute extends _i26.PageRouteInfo<void> {
  const ProjectSettingsRoute({List<_i26.PageRouteInfo>? children})
    : super(ProjectSettingsRoute.name, initialChildren: children);

  static const String name = 'ProjectSettingsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i2.ProjectSettingsPage();
    },
  );
}

/// generated route for
/// [_i17.ProjectsPage]
class ProjectsRoute extends _i26.PageRouteInfo<void> {
  const ProjectsRoute({List<_i26.PageRouteInfo>? children})
    : super(ProjectsRoute.name, initialChildren: children);

  static const String name = 'ProjectsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i17.ProjectsPage();
    },
  );
}

/// generated route for
/// [_i4.ReviewSlaPage]
class ReviewSlaRoute extends _i26.PageRouteInfo<void> {
  const ReviewSlaRoute({List<_i26.PageRouteInfo>? children})
    : super(ReviewSlaRoute.name, initialChildren: children);

  static const String name = 'ReviewSlaRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i4.ReviewSlaPage();
    },
  );
}

/// generated route for
/// [_i18.ReviewsPage]
class ReviewsRoute extends _i26.PageRouteInfo<void> {
  const ReviewsRoute({List<_i26.PageRouteInfo>? children})
    : super(ReviewsRoute.name, initialChildren: children);

  static const String name = 'ReviewsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i18.ReviewsPage();
    },
  );
}

/// generated route for
/// [_i19.SetupChecklistPage]
class SetupChecklistRoute extends _i26.PageRouteInfo<void> {
  const SetupChecklistRoute({List<_i26.PageRouteInfo>? children})
    : super(SetupChecklistRoute.name, initialChildren: children);

  static const String name = 'SetupChecklistRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i19.SetupChecklistPage();
    },
  );
}

/// generated route for
/// [_i20.SignUpPage]
class SignUpRoute extends _i26.PageRouteInfo<void> {
  const SignUpRoute({List<_i26.PageRouteInfo>? children})
    : super(SignUpRoute.name, initialChildren: children);

  static const String name = 'SignUpRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i20.SignUpPage();
    },
  );
}

/// generated route for
/// [_i21.SplashPage]
class SplashRoute extends _i26.PageRouteInfo<void> {
  const SplashRoute({List<_i26.PageRouteInfo>? children})
    : super(SplashRoute.name, initialChildren: children);

  static const String name = 'SplashRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i21.SplashPage();
    },
  );
}

/// generated route for
/// [_i3.SprintPlanPage]
class SprintPlanRoute extends _i26.PageRouteInfo<void> {
  const SprintPlanRoute({List<_i26.PageRouteInfo>? children})
    : super(SprintPlanRoute.name, initialChildren: children);

  static const String name = 'SprintPlanRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i3.SprintPlanPage();
    },
  );
}

/// generated route for
/// [_i3.SprintSummaryPage]
class SprintSummaryRoute extends _i26.PageRouteInfo<void> {
  const SprintSummaryRoute({List<_i26.PageRouteInfo>? children})
    : super(SprintSummaryRoute.name, initialChildren: children);

  static const String name = 'SprintSummaryRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i3.SprintSummaryPage();
    },
  );
}

/// generated route for
/// [_i6.SubtasksPage]
class SubtasksRoute extends _i26.PageRouteInfo<SubtasksRouteArgs> {
  SubtasksRoute({
    _i27.Key? key,
    required _i28.Task task,
    List<_i26.PageRouteInfo>? children,
  }) : super(
         SubtasksRoute.name,
         args: SubtasksRouteArgs(key: key, task: task),
         initialChildren: children,
       );

  static const String name = 'SubtasksRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SubtasksRouteArgs>();
      return _i6.SubtasksPage(key: args.key, task: args.task);
    },
  );
}

class SubtasksRouteArgs {
  const SubtasksRouteArgs({this.key, required this.task});

  final _i27.Key? key;

  final _i28.Task task;

  @override
  String toString() {
    return 'SubtasksRouteArgs{key: $key, task: $task}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SubtasksRouteArgs) return false;
    return key == other.key && task == other.task;
  }

  @override
  int get hashCode => key.hashCode ^ task.hashCode;
}

/// generated route for
/// [_i2.SyncSettingsPage]
class SyncSettingsRoute extends _i26.PageRouteInfo<void> {
  const SyncSettingsRoute({List<_i26.PageRouteInfo>? children})
    : super(SyncSettingsRoute.name, initialChildren: children);

  static const String name = 'SyncSettingsRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i2.SyncSettingsPage();
    },
  );
}

/// generated route for
/// [_i22.TaskBoardPage]
class TaskBoardRoute extends _i26.PageRouteInfo<void> {
  const TaskBoardRoute({List<_i26.PageRouteInfo>? children})
    : super(TaskBoardRoute.name, initialChildren: children);

  static const String name = 'TaskBoardRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i22.TaskBoardPage();
    },
  );
}

/// generated route for
/// [_i23.TaskCalendarPage]
class TaskCalendarRoute extends _i26.PageRouteInfo<void> {
  const TaskCalendarRoute({List<_i26.PageRouteInfo>? children})
    : super(TaskCalendarRoute.name, initialChildren: children);

  static const String name = 'TaskCalendarRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i23.TaskCalendarPage();
    },
  );
}

/// generated route for
/// [_i24.TaskDetailPage]
class TaskDetailRoute extends _i26.PageRouteInfo<TaskDetailRouteArgs> {
  TaskDetailRoute({
    _i27.Key? key,
    required String taskId,
    List<_i26.PageRouteInfo>? children,
  }) : super(
         TaskDetailRoute.name,
         args: TaskDetailRouteArgs(key: key, taskId: taskId),
         initialChildren: children,
       );

  static const String name = 'TaskDetailRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TaskDetailRouteArgs>();
      return _i24.TaskDetailPage(key: args.key, taskId: args.taskId);
    },
  );
}

class TaskDetailRouteArgs {
  const TaskDetailRouteArgs({this.key, required this.taskId});

  final _i27.Key? key;

  final String taskId;

  @override
  String toString() {
    return 'TaskDetailRouteArgs{key: $key, taskId: $taskId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TaskDetailRouteArgs) return false;
    return key == other.key && taskId == other.taskId;
  }

  @override
  int get hashCode => key.hashCode ^ taskId.hashCode;
}

/// generated route for
/// [_i23.TaskListPage]
class TaskListRoute extends _i26.PageRouteInfo<void> {
  const TaskListRoute({List<_i26.PageRouteInfo>? children})
    : super(TaskListRoute.name, initialChildren: children);

  static const String name = 'TaskListRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i23.TaskListPage();
    },
  );
}

/// generated route for
/// [_i23.TaskSearchPage]
class TaskSearchRoute extends _i26.PageRouteInfo<void> {
  const TaskSearchRoute({List<_i26.PageRouteInfo>? children})
    : super(TaskSearchRoute.name, initialChildren: children);

  static const String name = 'TaskSearchRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i23.TaskSearchPage();
    },
  );
}

/// generated route for
/// [_i5.TimeTrackingPage]
class TimeTrackingRoute extends _i26.PageRouteInfo<void> {
  const TimeTrackingRoute({List<_i26.PageRouteInfo>? children})
    : super(TimeTrackingRoute.name, initialChildren: children);

  static const String name = 'TimeTrackingRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i5.TimeTrackingPage();
    },
  );
}

/// generated route for
/// [_i25.VerifyOtpPage]
class VerifyOtpRoute extends _i26.PageRouteInfo<void> {
  const VerifyOtpRoute({List<_i26.PageRouteInfo>? children})
    : super(VerifyOtpRoute.name, initialChildren: children);

  static const String name = 'VerifyOtpRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i25.VerifyOtpPage();
    },
  );
}

/// generated route for
/// [_i9.WorkloadPage]
class WorkloadRoute extends _i26.PageRouteInfo<void> {
  const WorkloadRoute({List<_i26.PageRouteInfo>? children})
    : super(WorkloadRoute.name, initialChildren: children);

  static const String name = 'WorkloadRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i9.WorkloadPage();
    },
  );
}

/// generated route for
/// [_i1.WorkspaceCreatePage]
class WorkspaceCreateRoute extends _i26.PageRouteInfo<void> {
  const WorkspaceCreateRoute({List<_i26.PageRouteInfo>? children})
    : super(WorkspaceCreateRoute.name, initialChildren: children);

  static const String name = 'WorkspaceCreateRoute';

  static _i26.PageInfo page = _i26.PageInfo(
    name,
    builder: (data) {
      return const _i1.WorkspaceCreatePage();
    },
  );
}
