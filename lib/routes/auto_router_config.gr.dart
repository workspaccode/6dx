// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:auto_route/auto_route.dart' as _i31;
import 'package:flutter/material.dart' as _i32;
import 'package:sixdx/features/account/presentation/pages/account_pages.dart'
    as _i3;
import 'package:sixdx/features/auth/presentation/pages/login_page.dart' as _i16;
import 'package:sixdx/features/auth/presentation/pages/onboarding_page.dart'
    as _i20;
import 'package:sixdx/features/auth/presentation/pages/sign_up_page.dart'
    as _i25;
import 'package:sixdx/features/auth/presentation/pages/verify_otp_page.dart'
    as _i30;
import 'package:sixdx/features/clients/presentation/pages/client_pages.dart'
    as _i9;
import 'package:sixdx/features/github/presentation/pages/connect_repository_page.dart'
    as _i11;
import 'package:sixdx/features/home/presentation/pages/my_tasks_page.dart'
    as _i17;
import 'package:sixdx/features/home/presentation/pages/reviews_page.dart'
    as _i23;
import 'package:sixdx/features/members/presentation/pages/member_pages.dart'
    as _i15;
import 'package:sixdx/features/notifications/presentation/pages/notifications_page.dart'
    as _i19;
import 'package:sixdx/features/profile/presentation/pages/profile_page.dart'
    as _i21;
import 'package:sixdx/features/projects/presentation/pages/create_project_page.dart'
    as _i12;
import 'package:sixdx/features/projects/presentation/pages/project_settings_pages.dart'
    as _i4;
import 'package:sixdx/features/projects/presentation/pages/projects_page.dart'
    as _i22;
import 'package:sixdx/features/reviews/presentation/pages/review_pages.dart'
    as _i8;
import 'package:sixdx/features/setup/presentation/pages/setup_checklist_page.dart'
    as _i24;
import 'package:sixdx/features/sprints/presentation/pages/sprint_pages.dart'
    as _i6;
import 'package:sixdx/features/tasks/domain/entities/task.dart' as _i34;
import 'package:sixdx/features/tasks/presentation/pages/new_task_page.dart'
    as _i18;
import 'package:sixdx/features/tasks/presentation/pages/task_board_page.dart'
    as _i27;
import 'package:sixdx/features/tasks/presentation/pages/task_detail_page.dart'
    as _i29;
import 'package:sixdx/features/tasks/presentation/pages/task_extras_page.dart'
    as _i10;
import 'package:sixdx/features/tasks/presentation/pages/task_flow_pages.dart'
    as _i7;
import 'package:sixdx/features/tasks/presentation/pages/task_views_page.dart'
    as _i28;
import 'package:sixdx/features/team/presentation/pages/team_pages.dart' as _i13;
import 'package:sixdx/features/workspace/domain/entities/workspace_snapshot.dart'
    as _i33;
import 'package:sixdx/features/workspace/presentation/pages/github_flow_pages.dart'
    as _i14;
import 'package:sixdx/features/workspace/presentation/pages/insight_pages.dart'
    as _i5;
import 'package:sixdx/features/workspace/presentation/pages/state_pages.dart'
    as _i2;
import 'package:sixdx/features/workspace/presentation/pages/workspace_flow_pages.dart'
    as _i1;
import 'package:sixdx/routes/app_router.dart' as _i26;

/// generated route for
/// [_i1.AcceptInvitePage]
class AcceptInviteRoute extends _i31.PageRouteInfo<AcceptInviteRouteArgs> {
  AcceptInviteRoute({
    _i32.Key? key,
    _i33.WorkspaceInvite? invite,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         AcceptInviteRoute.name,
         args: AcceptInviteRouteArgs(key: key, invite: invite),
         initialChildren: children,
       );

  static const String name = 'AcceptInviteRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AcceptInviteRouteArgs>(
        orElse: () => const AcceptInviteRouteArgs(),
      );
      return _i1.AcceptInvitePage(key: args.key, invite: args.invite);
    },
  );
}

class AcceptInviteRouteArgs {
  const AcceptInviteRouteArgs({this.key, this.invite});

  final _i32.Key? key;

  final _i33.WorkspaceInvite? invite;

  @override
  String toString() {
    return 'AcceptInviteRouteArgs{key: $key, invite: $invite}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AcceptInviteRouteArgs) return false;
    return key == other.key && invite == other.invite;
  }

  @override
  int get hashCode => key.hashCode ^ invite.hashCode;
}

/// generated route for
/// [_i2.AccessRevokedPage]
class AccessRevokedRoute extends _i31.PageRouteInfo<AccessRevokedRouteArgs> {
  AccessRevokedRoute({
    _i32.Key? key,
    String? repositoryName,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         AccessRevokedRoute.name,
         args: AccessRevokedRouteArgs(key: key, repositoryName: repositoryName),
         initialChildren: children,
       );

  static const String name = 'AccessRevokedRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AccessRevokedRouteArgs>(
        orElse: () => const AccessRevokedRouteArgs(),
      );
      return _i2.AccessRevokedPage(
        key: args.key,
        repositoryName: args.repositoryName,
      );
    },
  );
}

class AccessRevokedRouteArgs {
  const AccessRevokedRouteArgs({this.key, this.repositoryName});

  final _i32.Key? key;

  final String? repositoryName;

  @override
  String toString() {
    return 'AccessRevokedRouteArgs{key: $key, repositoryName: $repositoryName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AccessRevokedRouteArgs) return false;
    return key == other.key && repositoryName == other.repositoryName;
  }

  @override
  int get hashCode => key.hashCode ^ repositoryName.hashCode;
}

/// generated route for
/// [_i3.AccountSettingsPage]
class AccountSettingsRoute extends _i31.PageRouteInfo<void> {
  const AccountSettingsRoute({List<_i31.PageRouteInfo>? children})
    : super(AccountSettingsRoute.name, initialChildren: children);

  static const String name = 'AccountSettingsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i3.AccountSettingsPage();
    },
  );
}

/// generated route for
/// [_i4.ActivityLogPage]
class ActivityLogRoute extends _i31.PageRouteInfo<void> {
  const ActivityLogRoute({List<_i31.PageRouteInfo>? children})
    : super(ActivityLogRoute.name, initialChildren: children);

  static const String name = 'ActivityLogRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i4.ActivityLogPage();
    },
  );
}

/// generated route for
/// [_i5.AgentsTeamPage]
class AgentsTeamRoute extends _i31.PageRouteInfo<void> {
  const AgentsTeamRoute({List<_i31.PageRouteInfo>? children})
    : super(AgentsTeamRoute.name, initialChildren: children);

  static const String name = 'AgentsTeamRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i5.AgentsTeamPage();
    },
  );
}

/// generated route for
/// [_i4.ArchivePage]
class ArchiveRoute extends _i31.PageRouteInfo<void> {
  const ArchiveRoute({List<_i31.PageRouteInfo>? children})
    : super(ArchiveRoute.name, initialChildren: children);

  static const String name = 'ArchiveRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i4.ArchivePage();
    },
  );
}

/// generated route for
/// [_i5.AskProjectPage]
class AskProjectRoute extends _i31.PageRouteInfo<AskProjectRouteArgs> {
  AskProjectRoute({
    _i32.Key? key,
    String? projectName,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         AskProjectRoute.name,
         args: AskProjectRouteArgs(key: key, projectName: projectName),
         initialChildren: children,
       );

  static const String name = 'AskProjectRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AskProjectRouteArgs>(
        orElse: () => const AskProjectRouteArgs(),
      );
      return _i5.AskProjectPage(key: args.key, projectName: args.projectName);
    },
  );
}

class AskProjectRouteArgs {
  const AskProjectRouteArgs({this.key, this.projectName});

  final _i32.Key? key;

  final String? projectName;

  @override
  String toString() {
    return 'AskProjectRouteArgs{key: $key, projectName: $projectName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AskProjectRouteArgs) return false;
    return key == other.key && projectName == other.projectName;
  }

  @override
  int get hashCode => key.hashCode ^ projectName.hashCode;
}

/// generated route for
/// [_i5.AssignAgentPage]
class AssignAgentRoute extends _i31.PageRouteInfo<AssignAgentRouteArgs> {
  AssignAgentRoute({
    _i32.Key? key,
    String? taskKey,
    String? taskTitle,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         AssignAgentRoute.name,
         args: AssignAgentRouteArgs(
           key: key,
           taskKey: taskKey,
           taskTitle: taskTitle,
         ),
         initialChildren: children,
       );

  static const String name = 'AssignAgentRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AssignAgentRouteArgs>(
        orElse: () => const AssignAgentRouteArgs(),
      );
      return _i5.AssignAgentPage(
        key: args.key,
        taskKey: args.taskKey,
        taskTitle: args.taskTitle,
      );
    },
  );
}

class AssignAgentRouteArgs {
  const AssignAgentRouteArgs({this.key, this.taskKey, this.taskTitle});

  final _i32.Key? key;

  final String? taskKey;

  final String? taskTitle;

  @override
  String toString() {
    return 'AssignAgentRouteArgs{key: $key, taskKey: $taskKey, taskTitle: $taskTitle}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AssignAgentRouteArgs) return false;
    return key == other.key &&
        taskKey == other.taskKey &&
        taskTitle == other.taskTitle;
  }

  @override
  int get hashCode => key.hashCode ^ taskKey.hashCode ^ taskTitle.hashCode;
}

/// generated route for
/// [_i6.BacklogPage]
class BacklogRoute extends _i31.PageRouteInfo<void> {
  const BacklogRoute({List<_i31.PageRouteInfo>? children})
    : super(BacklogRoute.name, initialChildren: children);

  static const String name = 'BacklogRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i6.BacklogPage();
    },
  );
}

/// generated route for
/// [_i5.BigPrWarningPage]
class BigPrWarningRoute extends _i31.PageRouteInfo<BigPrWarningRouteArgs> {
  BigPrWarningRoute({
    _i32.Key? key,
    int? prNumber,
    int? additions,
    int? deletions,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         BigPrWarningRoute.name,
         args: BigPrWarningRouteArgs(
           key: key,
           prNumber: prNumber,
           additions: additions,
           deletions: deletions,
         ),
         initialChildren: children,
       );

  static const String name = 'BigPrWarningRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<BigPrWarningRouteArgs>(
        orElse: () => const BigPrWarningRouteArgs(),
      );
      return _i5.BigPrWarningPage(
        key: args.key,
        prNumber: args.prNumber,
        additions: args.additions,
        deletions: args.deletions,
      );
    },
  );
}

class BigPrWarningRouteArgs {
  const BigPrWarningRouteArgs({
    this.key,
    this.prNumber,
    this.additions,
    this.deletions,
  });

  final _i32.Key? key;

  final int? prNumber;

  final int? additions;

  final int? deletions;

  @override
  String toString() {
    return 'BigPrWarningRouteArgs{key: $key, prNumber: $prNumber, additions: $additions, deletions: $deletions}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BigPrWarningRouteArgs) return false;
    return key == other.key &&
        prNumber == other.prNumber &&
        additions == other.additions &&
        deletions == other.deletions;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      prNumber.hashCode ^
      additions.hashCode ^
      deletions.hashCode;
}

/// generated route for
/// [_i1.BillingPage]
class BillingRoute extends _i31.PageRouteInfo<void> {
  const BillingRoute({List<_i31.PageRouteInfo>? children})
    : super(BillingRoute.name, initialChildren: children);

  static const String name = 'BillingRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i1.BillingPage();
    },
  );
}

/// generated route for
/// [_i7.BugReportPage]
class BugReportRoute extends _i31.PageRouteInfo<void> {
  const BugReportRoute({List<_i31.PageRouteInfo>? children})
    : super(BugReportRoute.name, initialChildren: children);

  static const String name = 'BugReportRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i7.BugReportPage();
    },
  );
}

/// generated route for
/// [_i7.BulkActionsPage]
class BulkActionsRoute extends _i31.PageRouteInfo<void> {
  const BulkActionsRoute({List<_i31.PageRouteInfo>? children})
    : super(BulkActionsRoute.name, initialChildren: children);

  static const String name = 'BulkActionsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i7.BulkActionsPage();
    },
  );
}

/// generated route for
/// [_i1.BulkInvitePage]
class BulkInviteRoute extends _i31.PageRouteInfo<void> {
  const BulkInviteRoute({List<_i31.PageRouteInfo>? children})
    : super(BulkInviteRoute.name, initialChildren: children);

  static const String name = 'BulkInviteRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i1.BulkInvitePage();
    },
  );
}

/// generated route for
/// [_i8.CiFailurePage]
class CiFailureRoute extends _i31.PageRouteInfo<void> {
  const CiFailureRoute({List<_i31.PageRouteInfo>? children})
    : super(CiFailureRoute.name, initialChildren: children);

  static const String name = 'CiFailureRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i8.CiFailurePage();
    },
  );
}

/// generated route for
/// [_i9.ClientPortalPage]
class ClientPortalRoute extends _i31.PageRouteInfo<void> {
  const ClientPortalRoute({List<_i31.PageRouteInfo>? children})
    : super(ClientPortalRoute.name, initialChildren: children);

  static const String name = 'ClientPortalRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i9.ClientPortalPage();
    },
  );
}

/// generated route for
/// [_i10.CommentsPage]
class CommentsRoute extends _i31.PageRouteInfo<CommentsRouteArgs> {
  CommentsRoute({
    _i32.Key? key,
    String taskKey = '',
    List<_i31.PageRouteInfo>? children,
  }) : super(
         CommentsRoute.name,
         args: CommentsRouteArgs(key: key, taskKey: taskKey),
         initialChildren: children,
       );

  static const String name = 'CommentsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CommentsRouteArgs>(
        orElse: () => const CommentsRouteArgs(),
      );
      return _i10.CommentsPage(key: args.key, taskKey: args.taskKey);
    },
  );
}

class CommentsRouteArgs {
  const CommentsRouteArgs({this.key, this.taskKey = ''});

  final _i32.Key? key;

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
/// [_i5.CommitsPage]
class CommitsRoute extends _i31.PageRouteInfo<void> {
  const CommitsRoute({List<_i31.PageRouteInfo>? children})
    : super(CommitsRoute.name, initialChildren: children);

  static const String name = 'CommitsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i5.CommitsPage();
    },
  );
}

/// generated route for
/// [_i11.ConnectRepositoryPage]
class ConnectRepositoryRoute extends _i31.PageRouteInfo<void> {
  const ConnectRepositoryRoute({List<_i31.PageRouteInfo>? children})
    : super(ConnectRepositoryRoute.name, initialChildren: children);

  static const String name = 'ConnectRepositoryRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i11.ConnectRepositoryPage();
    },
  );
}

/// generated route for
/// [_i12.CreateProjectPage]
class CreateProjectRoute extends _i31.PageRouteInfo<void> {
  const CreateProjectRoute({List<_i31.PageRouteInfo>? children})
    : super(CreateProjectRoute.name, initialChildren: children);

  static const String name = 'CreateProjectRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i12.CreateProjectPage();
    },
  );
}

/// generated route for
/// [_i7.DependenciesPage]
class DependenciesRoute extends _i31.PageRouteInfo<DependenciesRouteArgs> {
  DependenciesRoute({
    _i32.Key? key,
    String? taskKey,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         DependenciesRoute.name,
         args: DependenciesRouteArgs(key: key, taskKey: taskKey),
         initialChildren: children,
       );

  static const String name = 'DependenciesRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DependenciesRouteArgs>(
        orElse: () => const DependenciesRouteArgs(),
      );
      return _i7.DependenciesPage(key: args.key, taskKey: args.taskKey);
    },
  );
}

class DependenciesRouteArgs {
  const DependenciesRouteArgs({this.key, this.taskKey});

  final _i32.Key? key;

  final String? taskKey;

  @override
  String toString() {
    return 'DependenciesRouteArgs{key: $key, taskKey: $taskKey}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DependenciesRouteArgs) return false;
    return key == other.key && taskKey == other.taskKey;
  }

  @override
  int get hashCode => key.hashCode ^ taskKey.hashCode;
}

/// generated route for
/// [_i13.DigestPage]
class DigestRoute extends _i31.PageRouteInfo<void> {
  const DigestRoute({List<_i31.PageRouteInfo>? children})
    : super(DigestRoute.name, initialChildren: children);

  static const String name = 'DigestRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i13.DigestPage();
    },
  );
}

/// generated route for
/// [_i7.EditTaskPage]
class EditTaskRoute extends _i31.PageRouteInfo<EditTaskRouteArgs> {
  EditTaskRoute({
    _i32.Key? key,
    String? taskKey,
    String? title,
    String? description,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         EditTaskRoute.name,
         args: EditTaskRouteArgs(
           key: key,
           taskKey: taskKey,
           title: title,
           description: description,
         ),
         initialChildren: children,
       );

  static const String name = 'EditTaskRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<EditTaskRouteArgs>(
        orElse: () => const EditTaskRouteArgs(),
      );
      return _i7.EditTaskPage(
        key: args.key,
        taskKey: args.taskKey,
        title: args.title,
        description: args.description,
      );
    },
  );
}

class EditTaskRouteArgs {
  const EditTaskRouteArgs({
    this.key,
    this.taskKey,
    this.title,
    this.description,
  });

  final _i32.Key? key;

  final String? taskKey;

  final String? title;

  final String? description;

  @override
  String toString() {
    return 'EditTaskRouteArgs{key: $key, taskKey: $taskKey, title: $title, description: $description}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EditTaskRouteArgs) return false;
    return key == other.key &&
        taskKey == other.taskKey &&
        title == other.title &&
        description == other.description;
  }

  @override
  int get hashCode =>
      key.hashCode ^ taskKey.hashCode ^ title.hashCode ^ description.hashCode;
}

/// generated route for
/// [_i2.EmptyProjectsPage]
class EmptyProjectsRoute extends _i31.PageRouteInfo<void> {
  const EmptyProjectsRoute({List<_i31.PageRouteInfo>? children})
    : super(EmptyProjectsRoute.name, initialChildren: children);

  static const String name = 'EmptyProjectsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i2.EmptyProjectsPage();
    },
  );
}

/// generated route for
/// [_i5.EstimateLearningPage]
class EstimateLearningRoute extends _i31.PageRouteInfo<void> {
  const EstimateLearningRoute({List<_i31.PageRouteInfo>? children})
    : super(EstimateLearningRoute.name, initialChildren: children);

  static const String name = 'EstimateLearningRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i5.EstimateLearningPage();
    },
  );
}

/// generated route for
/// [_i1.ExportDataPage]
class ExportDataRoute extends _i31.PageRouteInfo<void> {
  const ExportDataRoute({List<_i31.PageRouteInfo>? children})
    : super(ExportDataRoute.name, initialChildren: children);

  static const String name = 'ExportDataRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i1.ExportDataPage();
    },
  );
}

/// generated route for
/// [_i3.FocusModePage]
class FocusModeRoute extends _i31.PageRouteInfo<void> {
  const FocusModeRoute({List<_i31.PageRouteInfo>? children})
    : super(FocusModeRoute.name, initialChildren: children);

  static const String name = 'FocusModeRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i3.FocusModePage();
    },
  );
}

/// generated route for
/// [_i14.GhAppInstallPage]
class GhAppInstallRoute extends _i31.PageRouteInfo<void> {
  const GhAppInstallRoute({List<_i31.PageRouteInfo>? children})
    : super(GhAppInstallRoute.name, initialChildren: children);

  static const String name = 'GhAppInstallRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i14.GhAppInstallPage();
    },
  );
}

/// generated route for
/// [_i14.GhInstallingPage]
class GhInstallingRoute extends _i31.PageRouteInfo<void> {
  const GhInstallingRoute({List<_i31.PageRouteInfo>? children})
    : super(GhInstallingRoute.name, initialChildren: children);

  static const String name = 'GhInstallingRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i14.GhInstallingPage();
    },
  );
}

/// generated route for
/// [_i3.HelpPage]
class HelpRoute extends _i31.PageRouteInfo<void> {
  const HelpRoute({List<_i31.PageRouteInfo>? children})
    : super(HelpRoute.name, initialChildren: children);

  static const String name = 'HelpRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i3.HelpPage();
    },
  );
}

/// generated route for
/// [_i14.ImportIssuesPage]
class ImportIssuesRoute extends _i31.PageRouteInfo<ImportIssuesRouteArgs> {
  ImportIssuesRoute({
    _i32.Key? key,
    String? repositoryName,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         ImportIssuesRoute.name,
         args: ImportIssuesRouteArgs(key: key, repositoryName: repositoryName),
         initialChildren: children,
       );

  static const String name = 'ImportIssuesRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ImportIssuesRouteArgs>(
        orElse: () => const ImportIssuesRouteArgs(),
      );
      return _i14.ImportIssuesPage(
        key: args.key,
        repositoryName: args.repositoryName,
      );
    },
  );
}

class ImportIssuesRouteArgs {
  const ImportIssuesRouteArgs({this.key, this.repositoryName});

  final _i32.Key? key;

  final String? repositoryName;

  @override
  String toString() {
    return 'ImportIssuesRouteArgs{key: $key, repositoryName: $repositoryName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ImportIssuesRouteArgs) return false;
    return key == other.key && repositoryName == other.repositoryName;
  }

  @override
  int get hashCode => key.hashCode ^ repositoryName.hashCode;
}

/// generated route for
/// [_i4.IntegrationsPage]
class IntegrationsRoute extends _i31.PageRouteInfo<void> {
  const IntegrationsRoute({List<_i31.PageRouteInfo>? children})
    : super(IntegrationsRoute.name, initialChildren: children);

  static const String name = 'IntegrationsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i4.IntegrationsPage();
    },
  );
}

/// generated route for
/// [_i1.InviteExpiredPage]
class InviteExpiredRoute extends _i31.PageRouteInfo<InviteExpiredRouteArgs> {
  InviteExpiredRoute({
    _i32.Key? key,
    String? workspaceName,
    String? inviterName,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         InviteExpiredRoute.name,
         args: InviteExpiredRouteArgs(
           key: key,
           workspaceName: workspaceName,
           inviterName: inviterName,
         ),
         initialChildren: children,
       );

  static const String name = 'InviteExpiredRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<InviteExpiredRouteArgs>(
        orElse: () => const InviteExpiredRouteArgs(),
      );
      return _i1.InviteExpiredPage(
        key: args.key,
        workspaceName: args.workspaceName,
        inviterName: args.inviterName,
      );
    },
  );
}

class InviteExpiredRouteArgs {
  const InviteExpiredRouteArgs({
    this.key,
    this.workspaceName,
    this.inviterName,
  });

  final _i32.Key? key;

  final String? workspaceName;

  final String? inviterName;

  @override
  String toString() {
    return 'InviteExpiredRouteArgs{key: $key, workspaceName: $workspaceName, inviterName: $inviterName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! InviteExpiredRouteArgs) return false;
    return key == other.key &&
        workspaceName == other.workspaceName &&
        inviterName == other.inviterName;
  }

  @override
  int get hashCode =>
      key.hashCode ^ workspaceName.hashCode ^ inviterName.hashCode;
}

/// generated route for
/// [_i15.InvitePage]
class InviteRoute extends _i31.PageRouteInfo<void> {
  const InviteRoute({List<_i31.PageRouteInfo>? children})
    : super(InviteRoute.name, initialChildren: children);

  static const String name = 'InviteRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i15.InvitePage();
    },
  );
}

/// generated route for
/// [_i9.InvoicePage]
class InvoiceRoute extends _i31.PageRouteInfo<void> {
  const InvoiceRoute({List<_i31.PageRouteInfo>? children})
    : super(InvoiceRoute.name, initialChildren: children);

  static const String name = 'InvoiceRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i9.InvoicePage();
    },
  );
}

/// generated route for
/// [_i1.JoinRequestsPage]
class JoinRequestsRoute extends _i31.PageRouteInfo<void> {
  const JoinRequestsRoute({List<_i31.PageRouteInfo>? children})
    : super(JoinRequestsRoute.name, initialChildren: children);

  static const String name = 'JoinRequestsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i1.JoinRequestsPage();
    },
  );
}

/// generated route for
/// [_i5.KnowledgeMapPage]
class KnowledgeMapRoute extends _i31.PageRouteInfo<void> {
  const KnowledgeMapRoute({List<_i31.PageRouteInfo>? children})
    : super(KnowledgeMapRoute.name, initialChildren: children);

  static const String name = 'KnowledgeMapRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i5.KnowledgeMapPage();
    },
  );
}

/// generated route for
/// [_i4.LabelsPage]
class LabelsRoute extends _i31.PageRouteInfo<void> {
  const LabelsRoute({List<_i31.PageRouteInfo>? children})
    : super(LabelsRoute.name, initialChildren: children);

  static const String name = 'LabelsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i4.LabelsPage();
    },
  );
}

/// generated route for
/// [_i1.LinkGitHubPage]
class LinkGitHubRoute extends _i31.PageRouteInfo<LinkGitHubRouteArgs> {
  LinkGitHubRoute({
    _i32.Key? key,
    String? repository,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         LinkGitHubRoute.name,
         args: LinkGitHubRouteArgs(key: key, repository: repository),
         initialChildren: children,
       );

  static const String name = 'LinkGitHubRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LinkGitHubRouteArgs>(
        orElse: () => const LinkGitHubRouteArgs(),
      );
      return _i1.LinkGitHubPage(key: args.key, repository: args.repository);
    },
  );
}

class LinkGitHubRouteArgs {
  const LinkGitHubRouteArgs({this.key, this.repository});

  final _i32.Key? key;

  final String? repository;

  @override
  String toString() {
    return 'LinkGitHubRouteArgs{key: $key, repository: $repository}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LinkGitHubRouteArgs) return false;
    return key == other.key && repository == other.repository;
  }

  @override
  int get hashCode => key.hashCode ^ repository.hashCode;
}

/// generated route for
/// [_i16.LoginPage]
class LoginRoute extends _i31.PageRouteInfo<void> {
  const LoginRoute({List<_i31.PageRouteInfo>? children})
    : super(LoginRoute.name, initialChildren: children);

  static const String name = 'LoginRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i16.LoginPage();
    },
  );
}

/// generated route for
/// [_i14.MapContributorsPage]
class MapContributorsRoute
    extends _i31.PageRouteInfo<MapContributorsRouteArgs> {
  MapContributorsRoute({
    _i32.Key? key,
    String? repositoryName,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         MapContributorsRoute.name,
         args: MapContributorsRouteArgs(
           key: key,
           repositoryName: repositoryName,
         ),
         initialChildren: children,
       );

  static const String name = 'MapContributorsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MapContributorsRouteArgs>(
        orElse: () => const MapContributorsRouteArgs(),
      );
      return _i14.MapContributorsPage(
        key: args.key,
        repositoryName: args.repositoryName,
      );
    },
  );
}

class MapContributorsRouteArgs {
  const MapContributorsRouteArgs({this.key, this.repositoryName});

  final _i32.Key? key;

  final String? repositoryName;

  @override
  String toString() {
    return 'MapContributorsRouteArgs{key: $key, repositoryName: $repositoryName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MapContributorsRouteArgs) return false;
    return key == other.key && repositoryName == other.repositoryName;
  }

  @override
  int get hashCode => key.hashCode ^ repositoryName.hashCode;
}

/// generated route for
/// [_i15.MembersPage]
class MembersRoute extends _i31.PageRouteInfo<void> {
  const MembersRoute({List<_i31.PageRouteInfo>? children})
    : super(MembersRoute.name, initialChildren: children);

  static const String name = 'MembersRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i15.MembersPage();
    },
  );
}

/// generated route for
/// [_i5.MergeFromAppPage]
class MergeFromAppRoute extends _i31.PageRouteInfo<MergeFromAppRouteArgs> {
  MergeFromAppRoute({
    _i32.Key? key,
    int? prNumber,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         MergeFromAppRoute.name,
         args: MergeFromAppRouteArgs(key: key, prNumber: prNumber),
         initialChildren: children,
       );

  static const String name = 'MergeFromAppRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MergeFromAppRouteArgs>(
        orElse: () => const MergeFromAppRouteArgs(),
      );
      return _i5.MergeFromAppPage(key: args.key, prNumber: args.prNumber);
    },
  );
}

class MergeFromAppRouteArgs {
  const MergeFromAppRouteArgs({this.key, this.prNumber});

  final _i32.Key? key;

  final int? prNumber;

  @override
  String toString() {
    return 'MergeFromAppRouteArgs{key: $key, prNumber: $prNumber}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MergeFromAppRouteArgs) return false;
    return key == other.key && prNumber == other.prNumber;
  }

  @override
  int get hashCode => key.hashCode ^ prNumber.hashCode;
}

/// generated route for
/// [_i14.MultiProviderPage]
class MultiProviderRoute extends _i31.PageRouteInfo<void> {
  const MultiProviderRoute({List<_i31.PageRouteInfo>? children})
    : super(MultiProviderRoute.name, initialChildren: children);

  static const String name = 'MultiProviderRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i14.MultiProviderPage();
    },
  );
}

/// generated route for
/// [_i17.MyTasksPage]
class MyTasksRoute extends _i31.PageRouteInfo<void> {
  const MyTasksRoute({List<_i31.PageRouteInfo>? children})
    : super(MyTasksRoute.name, initialChildren: children);

  static const String name = 'MyTasksRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i17.MyTasksPage();
    },
  );
}

/// generated route for
/// [_i18.NewTaskPage]
class NewTaskRoute extends _i31.PageRouteInfo<void> {
  const NewTaskRoute({List<_i31.PageRouteInfo>? children})
    : super(NewTaskRoute.name, initialChildren: children);

  static const String name = 'NewTaskRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i18.NewTaskPage();
    },
  );
}

/// generated route for
/// [_i2.NoPermissionPage]
class NoPermissionRoute extends _i31.PageRouteInfo<NoPermissionRouteArgs> {
  NoPermissionRoute({
    _i32.Key? key,
    String? role,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         NoPermissionRoute.name,
         args: NoPermissionRouteArgs(key: key, role: role),
         initialChildren: children,
       );

  static const String name = 'NoPermissionRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<NoPermissionRouteArgs>(
        orElse: () => const NoPermissionRouteArgs(),
      );
      return _i2.NoPermissionPage(key: args.key, role: args.role);
    },
  );
}

class NoPermissionRouteArgs {
  const NoPermissionRouteArgs({this.key, this.role});

  final _i32.Key? key;

  final String? role;

  @override
  String toString() {
    return 'NoPermissionRouteArgs{key: $key, role: $role}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NoPermissionRouteArgs) return false;
    return key == other.key && role == other.role;
  }

  @override
  int get hashCode => key.hashCode ^ role.hashCode;
}

/// generated route for
/// [_i2.NotFoundPage]
class NotFoundRoute extends _i31.PageRouteInfo<NotFoundRouteArgs> {
  NotFoundRoute({
    _i32.Key? key,
    String? itemKey,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         NotFoundRoute.name,
         args: NotFoundRouteArgs(key: key, itemKey: itemKey),
         initialChildren: children,
       );

  static const String name = 'NotFoundRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<NotFoundRouteArgs>(
        orElse: () => const NotFoundRouteArgs(),
      );
      return _i2.NotFoundPage(key: args.key, itemKey: args.itemKey);
    },
  );
}

class NotFoundRouteArgs {
  const NotFoundRouteArgs({this.key, this.itemKey});

  final _i32.Key? key;

  final String? itemKey;

  @override
  String toString() {
    return 'NotFoundRouteArgs{key: $key, itemKey: $itemKey}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NotFoundRouteArgs) return false;
    return key == other.key && itemKey == other.itemKey;
  }

  @override
  int get hashCode => key.hashCode ^ itemKey.hashCode;
}

/// generated route for
/// [_i3.NotifSettingsPage]
class NotifSettingsRoute extends _i31.PageRouteInfo<void> {
  const NotifSettingsRoute({List<_i31.PageRouteInfo>? children})
    : super(NotifSettingsRoute.name, initialChildren: children);

  static const String name = 'NotifSettingsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i3.NotifSettingsPage();
    },
  );
}

/// generated route for
/// [_i19.NotificationsPage]
class NotificationsRoute extends _i31.PageRouteInfo<void> {
  const NotificationsRoute({List<_i31.PageRouteInfo>? children})
    : super(NotificationsRoute.name, initialChildren: children);

  static const String name = 'NotificationsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i19.NotificationsPage();
    },
  );
}

/// generated route for
/// [_i2.OfflinePage]
class OfflineRoute extends _i31.PageRouteInfo<void> {
  const OfflineRoute({List<_i31.PageRouteInfo>? children})
    : super(OfflineRoute.name, initialChildren: children);

  static const String name = 'OfflineRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i2.OfflinePage();
    },
  );
}

/// generated route for
/// [_i20.OnboardingPage]
class OnboardingRoute extends _i31.PageRouteInfo<void> {
  const OnboardingRoute({List<_i31.PageRouteInfo>? children})
    : super(OnboardingRoute.name, initialChildren: children);

  static const String name = 'OnboardingRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i20.OnboardingPage();
    },
  );
}

/// generated route for
/// [_i8.PrDetailPage]
class PrDetailRoute extends _i31.PageRouteInfo<PrDetailRouteArgs> {
  PrDetailRoute({
    _i32.Key? key,
    int prNumber = 58,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         PrDetailRoute.name,
         args: PrDetailRouteArgs(key: key, prNumber: prNumber),
         initialChildren: children,
       );

  static const String name = 'PrDetailRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PrDetailRouteArgs>(
        orElse: () => const PrDetailRouteArgs(),
      );
      return _i8.PrDetailPage(key: args.key, prNumber: args.prNumber);
    },
  );
}

class PrDetailRouteArgs {
  const PrDetailRouteArgs({this.key, this.prNumber = 58});

  final _i32.Key? key;

  final int prNumber;

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
/// [_i21.ProfilePage]
class ProfileRoute extends _i31.PageRouteInfo<void> {
  const ProfileRoute({List<_i31.PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i21.ProfilePage();
    },
  );
}

/// generated route for
/// [_i5.ProjectReportPage]
class ProjectReportRoute extends _i31.PageRouteInfo<void> {
  const ProjectReportRoute({List<_i31.PageRouteInfo>? children})
    : super(ProjectReportRoute.name, initialChildren: children);

  static const String name = 'ProjectReportRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i5.ProjectReportPage();
    },
  );
}

/// generated route for
/// [_i4.ProjectSettingsPage]
class ProjectSettingsRoute extends _i31.PageRouteInfo<void> {
  const ProjectSettingsRoute({List<_i31.PageRouteInfo>? children})
    : super(ProjectSettingsRoute.name, initialChildren: children);

  static const String name = 'ProjectSettingsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i4.ProjectSettingsPage();
    },
  );
}

/// generated route for
/// [_i22.ProjectsPage]
class ProjectsRoute extends _i31.PageRouteInfo<void> {
  const ProjectsRoute({List<_i31.PageRouteInfo>? children})
    : super(ProjectsRoute.name, initialChildren: children);

  static const String name = 'ProjectsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i22.ProjectsPage();
    },
  );
}

/// generated route for
/// [_i2.PushPermissionPage]
class PushPermissionRoute extends _i31.PageRouteInfo<void> {
  const PushPermissionRoute({List<_i31.PageRouteInfo>? children})
    : super(PushPermissionRoute.name, initialChildren: children);

  static const String name = 'PushPermissionRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i2.PushPermissionPage();
    },
  );
}

/// generated route for
/// [_i1.RegionalCalendarPage]
class RegionalCalendarRoute extends _i31.PageRouteInfo<void> {
  const RegionalCalendarRoute({List<_i31.PageRouteInfo>? children})
    : super(RegionalCalendarRoute.name, initialChildren: children);

  static const String name = 'RegionalCalendarRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i1.RegionalCalendarPage();
    },
  );
}

/// generated route for
/// [_i5.ReleaseTrackerPage]
class ReleaseTrackerRoute extends _i31.PageRouteInfo<void> {
  const ReleaseTrackerRoute({List<_i31.PageRouteInfo>? children})
    : super(ReleaseTrackerRoute.name, initialChildren: children);

  static const String name = 'ReleaseTrackerRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i5.ReleaseTrackerPage();
    },
  );
}

/// generated route for
/// [_i8.ReviewSlaPage]
class ReviewSlaRoute extends _i31.PageRouteInfo<void> {
  const ReviewSlaRoute({List<_i31.PageRouteInfo>? children})
    : super(ReviewSlaRoute.name, initialChildren: children);

  static const String name = 'ReviewSlaRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i8.ReviewSlaPage();
    },
  );
}

/// generated route for
/// [_i5.ReviewerPickPage]
class ReviewerPickRoute extends _i31.PageRouteInfo<ReviewerPickRouteArgs> {
  ReviewerPickRoute({
    _i32.Key? key,
    int? prNumber,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         ReviewerPickRoute.name,
         args: ReviewerPickRouteArgs(key: key, prNumber: prNumber),
         initialChildren: children,
       );

  static const String name = 'ReviewerPickRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ReviewerPickRouteArgs>(
        orElse: () => const ReviewerPickRouteArgs(),
      );
      return _i5.ReviewerPickPage(key: args.key, prNumber: args.prNumber);
    },
  );
}

class ReviewerPickRouteArgs {
  const ReviewerPickRouteArgs({this.key, this.prNumber});

  final _i32.Key? key;

  final int? prNumber;

  @override
  String toString() {
    return 'ReviewerPickRouteArgs{key: $key, prNumber: $prNumber}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ReviewerPickRouteArgs) return false;
    return key == other.key && prNumber == other.prNumber;
  }

  @override
  int get hashCode => key.hashCode ^ prNumber.hashCode;
}

/// generated route for
/// [_i23.ReviewsPage]
class ReviewsRoute extends _i31.PageRouteInfo<void> {
  const ReviewsRoute({List<_i31.PageRouteInfo>? children})
    : super(ReviewsRoute.name, initialChildren: children);

  static const String name = 'ReviewsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i23.ReviewsPage();
    },
  );
}

/// generated route for
/// [_i2.RichNotificationPage]
class RichNotificationRoute extends _i31.PageRouteInfo<void> {
  const RichNotificationRoute({List<_i31.PageRouteInfo>? children})
    : super(RichNotificationRoute.name, initialChildren: children);

  static const String name = 'RichNotificationRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i2.RichNotificationPage();
    },
  );
}

/// generated route for
/// [_i24.SetupChecklistPage]
class SetupChecklistRoute extends _i31.PageRouteInfo<void> {
  const SetupChecklistRoute({List<_i31.PageRouteInfo>? children})
    : super(SetupChecklistRoute.name, initialChildren: children);

  static const String name = 'SetupChecklistRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i24.SetupChecklistPage();
    },
  );
}

/// generated route for
/// [_i25.SignUpPage]
class SignUpRoute extends _i31.PageRouteInfo<void> {
  const SignUpRoute({List<_i31.PageRouteInfo>? children})
    : super(SignUpRoute.name, initialChildren: children);

  static const String name = 'SignUpRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i25.SignUpPage();
    },
  );
}

/// generated route for
/// [_i2.SkeletonPage]
class SkeletonRoute extends _i31.PageRouteInfo<void> {
  const SkeletonRoute({List<_i31.PageRouteInfo>? children})
    : super(SkeletonRoute.name, initialChildren: children);

  static const String name = 'SkeletonRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i2.SkeletonPage();
    },
  );
}

/// generated route for
/// [_i26.SplashPage]
class SplashRoute extends _i31.PageRouteInfo<void> {
  const SplashRoute({List<_i31.PageRouteInfo>? children})
    : super(SplashRoute.name, initialChildren: children);

  static const String name = 'SplashRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i26.SplashPage();
    },
  );
}

/// generated route for
/// [_i5.SprintHistoryPage]
class SprintHistoryRoute extends _i31.PageRouteInfo<void> {
  const SprintHistoryRoute({List<_i31.PageRouteInfo>? children})
    : super(SprintHistoryRoute.name, initialChildren: children);

  static const String name = 'SprintHistoryRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i5.SprintHistoryPage();
    },
  );
}

/// generated route for
/// [_i6.SprintPlanPage]
class SprintPlanRoute extends _i31.PageRouteInfo<void> {
  const SprintPlanRoute({List<_i31.PageRouteInfo>? children})
    : super(SprintPlanRoute.name, initialChildren: children);

  static const String name = 'SprintPlanRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i6.SprintPlanPage();
    },
  );
}

/// generated route for
/// [_i6.SprintSummaryPage]
class SprintSummaryRoute extends _i31.PageRouteInfo<void> {
  const SprintSummaryRoute({List<_i31.PageRouteInfo>? children})
    : super(SprintSummaryRoute.name, initialChildren: children);

  static const String name = 'SprintSummaryRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i6.SprintSummaryPage();
    },
  );
}

/// generated route for
/// [_i7.StatusSheetPage]
class StatusSheetRoute extends _i31.PageRouteInfo<StatusSheetRouteArgs> {
  StatusSheetRoute({
    _i32.Key? key,
    String? taskKey,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         StatusSheetRoute.name,
         args: StatusSheetRouteArgs(key: key, taskKey: taskKey),
         initialChildren: children,
       );

  static const String name = 'StatusSheetRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<StatusSheetRouteArgs>(
        orElse: () => const StatusSheetRouteArgs(),
      );
      return _i7.StatusSheetPage(key: args.key, taskKey: args.taskKey);
    },
  );
}

class StatusSheetRouteArgs {
  const StatusSheetRouteArgs({this.key, this.taskKey});

  final _i32.Key? key;

  final String? taskKey;

  @override
  String toString() {
    return 'StatusSheetRouteArgs{key: $key, taskKey: $taskKey}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StatusSheetRouteArgs) return false;
    return key == other.key && taskKey == other.taskKey;
  }

  @override
  int get hashCode => key.hashCode ^ taskKey.hashCode;
}

/// generated route for
/// [_i10.SubtasksPage]
class SubtasksRoute extends _i31.PageRouteInfo<SubtasksRouteArgs> {
  SubtasksRoute({
    _i32.Key? key,
    required _i34.Task task,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         SubtasksRoute.name,
         args: SubtasksRouteArgs(key: key, task: task),
         initialChildren: children,
       );

  static const String name = 'SubtasksRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SubtasksRouteArgs>();
      return _i10.SubtasksPage(key: args.key, task: args.task);
    },
  );
}

class SubtasksRouteArgs {
  const SubtasksRouteArgs({this.key, required this.task});

  final _i32.Key? key;

  final _i34.Task task;

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
/// [_i2.SyncFailedPage]
class SyncFailedRoute extends _i31.PageRouteInfo<void> {
  const SyncFailedRoute({List<_i31.PageRouteInfo>? children})
    : super(SyncFailedRoute.name, initialChildren: children);

  static const String name = 'SyncFailedRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i2.SyncFailedPage();
    },
  );
}

/// generated route for
/// [_i4.SyncSettingsPage]
class SyncSettingsRoute extends _i31.PageRouteInfo<void> {
  const SyncSettingsRoute({List<_i31.PageRouteInfo>? children})
    : super(SyncSettingsRoute.name, initialChildren: children);

  static const String name = 'SyncSettingsRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i4.SyncSettingsPage();
    },
  );
}

/// generated route for
/// [_i27.TaskBoardPage]
class TaskBoardRoute extends _i31.PageRouteInfo<void> {
  const TaskBoardRoute({List<_i31.PageRouteInfo>? children})
    : super(TaskBoardRoute.name, initialChildren: children);

  static const String name = 'TaskBoardRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i27.TaskBoardPage();
    },
  );
}

/// generated route for
/// [_i28.TaskCalendarPage]
class TaskCalendarRoute extends _i31.PageRouteInfo<void> {
  const TaskCalendarRoute({List<_i31.PageRouteInfo>? children})
    : super(TaskCalendarRoute.name, initialChildren: children);

  static const String name = 'TaskCalendarRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i28.TaskCalendarPage();
    },
  );
}

/// generated route for
/// [_i7.TaskContextPage]
class TaskContextRoute extends _i31.PageRouteInfo<TaskContextRouteArgs> {
  TaskContextRoute({
    _i32.Key? key,
    String? taskKey,
    String? taskTitle,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         TaskContextRoute.name,
         args: TaskContextRouteArgs(
           key: key,
           taskKey: taskKey,
           taskTitle: taskTitle,
         ),
         initialChildren: children,
       );

  static const String name = 'TaskContextRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TaskContextRouteArgs>(
        orElse: () => const TaskContextRouteArgs(),
      );
      return _i7.TaskContextPage(
        key: args.key,
        taskKey: args.taskKey,
        taskTitle: args.taskTitle,
      );
    },
  );
}

class TaskContextRouteArgs {
  const TaskContextRouteArgs({this.key, this.taskKey, this.taskTitle});

  final _i32.Key? key;

  final String? taskKey;

  final String? taskTitle;

  @override
  String toString() {
    return 'TaskContextRouteArgs{key: $key, taskKey: $taskKey, taskTitle: $taskTitle}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TaskContextRouteArgs) return false;
    return key == other.key &&
        taskKey == other.taskKey &&
        taskTitle == other.taskTitle;
  }

  @override
  int get hashCode => key.hashCode ^ taskKey.hashCode ^ taskTitle.hashCode;
}

/// generated route for
/// [_i29.TaskDetailPage]
class TaskDetailRoute extends _i31.PageRouteInfo<TaskDetailRouteArgs> {
  TaskDetailRoute({
    _i32.Key? key,
    required String taskId,
    List<_i31.PageRouteInfo>? children,
  }) : super(
         TaskDetailRoute.name,
         args: TaskDetailRouteArgs(key: key, taskId: taskId),
         initialChildren: children,
       );

  static const String name = 'TaskDetailRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<TaskDetailRouteArgs>();
      return _i29.TaskDetailPage(key: args.key, taskId: args.taskId);
    },
  );
}

class TaskDetailRouteArgs {
  const TaskDetailRouteArgs({this.key, required this.taskId});

  final _i32.Key? key;

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
/// [_i28.TaskListPage]
class TaskListRoute extends _i31.PageRouteInfo<void> {
  const TaskListRoute({List<_i31.PageRouteInfo>? children})
    : super(TaskListRoute.name, initialChildren: children);

  static const String name = 'TaskListRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i28.TaskListPage();
    },
  );
}

/// generated route for
/// [_i28.TaskSearchPage]
class TaskSearchRoute extends _i31.PageRouteInfo<void> {
  const TaskSearchRoute({List<_i31.PageRouteInfo>? children})
    : super(TaskSearchRoute.name, initialChildren: children);

  static const String name = 'TaskSearchRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i28.TaskSearchPage();
    },
  );
}

/// generated route for
/// [_i9.TimeTrackingPage]
class TimeTrackingRoute extends _i31.PageRouteInfo<void> {
  const TimeTrackingRoute({List<_i31.PageRouteInfo>? children})
    : super(TimeTrackingRoute.name, initialChildren: children);

  static const String name = 'TimeTrackingRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i9.TimeTrackingPage();
    },
  );
}

/// generated route for
/// [_i30.VerifyOtpPage]
class VerifyOtpRoute extends _i31.PageRouteInfo<void> {
  const VerifyOtpRoute({List<_i31.PageRouteInfo>? children})
    : super(VerifyOtpRoute.name, initialChildren: children);

  static const String name = 'VerifyOtpRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i30.VerifyOtpPage();
    },
  );
}

/// generated route for
/// [_i5.WeeklyClientSummaryPage]
class WeeklyClientSummaryRoute extends _i31.PageRouteInfo<void> {
  const WeeklyClientSummaryRoute({List<_i31.PageRouteInfo>? children})
    : super(WeeklyClientSummaryRoute.name, initialChildren: children);

  static const String name = 'WeeklyClientSummaryRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i5.WeeklyClientSummaryPage();
    },
  );
}

/// generated route for
/// [_i13.WorkloadPage]
class WorkloadRoute extends _i31.PageRouteInfo<void> {
  const WorkloadRoute({List<_i31.PageRouteInfo>? children})
    : super(WorkloadRoute.name, initialChildren: children);

  static const String name = 'WorkloadRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i13.WorkloadPage();
    },
  );
}

/// generated route for
/// [_i3.WorkspaceCreatePage]
class WorkspaceCreateRoute extends _i31.PageRouteInfo<void> {
  const WorkspaceCreateRoute({List<_i31.PageRouteInfo>? children})
    : super(WorkspaceCreateRoute.name, initialChildren: children);

  static const String name = 'WorkspaceCreateRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i3.WorkspaceCreatePage();
    },
  );
}

/// generated route for
/// [_i1.WorkspaceSwitchPage]
class WorkspaceSwitchRoute extends _i31.PageRouteInfo<void> {
  const WorkspaceSwitchRoute({List<_i31.PageRouteInfo>? children})
    : super(WorkspaceSwitchRoute.name, initialChildren: children);

  static const String name = 'WorkspaceSwitchRoute';

  static _i31.PageInfo page = _i31.PageInfo(
    name,
    builder: (data) {
      return const _i1.WorkspaceSwitchPage();
    },
  );
}
