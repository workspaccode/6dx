/// Workflow states, the role home and project overrides —
/// docs/design/groups-and-roles.md (phase 3).
library;

import 'group_models.dart';

/// State categories: what reports and the home count, whatever a group
/// names its states.
enum StateCategory {
  backlog('backlog', 'قائمة الانتظار'),
  active('active', 'شغّال'),
  blocked('blocked', 'متوقف'),
  done('done', 'تم'),
  cancelled('cancelled', 'ملغي');

  const StateCategory(this.wire, this.label);
  final String wire;
  final String label;

  bool get isClosed => this == StateCategory.done || this == StateCategory.cancelled;

  static StateCategory parse(Object? value) {
    for (final c in StateCategory.values) {
      if (c.wire == value) return c;
    }
    return StateCategory.active;
  }
}

/// '#RRGGBB' as an ARGB int; a malformed value falls back to slate (the
/// labels lesson: never crash on a stored colour).
int parseHexColor(String? color) {
  final raw = color ?? '';
  final hex = raw.startsWith('#') ? raw.substring(1) : raw;
  final value = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
  return 0xFF000000 | (value ?? 0x64748B);
}

/// A task state of one group (`GET /v1/groups/{gid}/workflow`).
class WorkflowState {
  const WorkflowState({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    required this.legacyStatus,
    required this.order,
    required this.isLocked,
    required this.archived,
    required this.taskCount,
  });

  final String id;
  final String name;
  final StateCategory category;

  /// '#RRGGBB'.
  final String color;

  /// How the classic board shows it: todo / in_progress / review / done.
  final String legacyStatus;
  final int order;
  final bool isLocked;
  final bool archived;
  final int taskCount;

  int get argb => parseHexColor(color);

  factory WorkflowState.fromJson(Map<String, dynamic> json) => WorkflowState(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        category: StateCategory.parse(json['category']),
        color: '${json['color'] ?? '#64748B'}',
        legacyStatus: '${json['legacy_status'] ?? 'todo'}',
        order: _int(json['order']),
        isLocked: json['is_locked'] == true,
        archived: json['archived'] == true,
        taskCount: _int(json['task_count']),
      );
}

class GroupWorkflow {
  const GroupWorkflow({required this.states, required this.canManage});
  final List<WorkflowState> states;
  final bool canManage;

  List<WorkflowState> get live =>
      states.where((s) => !s.archived).toList(growable: false);
  List<WorkflowState> get archived =>
      states.where((s) => s.archived).toList(growable: false);

  WorkflowState? byId(String? id) {
    for (final s in states) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The state a task shows in: its own, else the first live one with its
  /// legacy status (a task the API has not mapped).
  WorkflowState? forTask(GroupTask task) {
    final own = byId(task.stateId);
    if (own != null) return own;
    for (final s in live) {
      if (s.legacyStatus == task.status) return s;
    }
    return null;
  }

  /// The only checks the API also makes, so the screen can explain them
  /// before a request fails.
  int liveIn(StateCategory category) =>
      live.where((s) => s.category == category).length;
}

/// One of the caller's open tasks on the group home.
class HomeTask {
  const HomeTask({
    required this.id,
    required this.title,
    required this.priority,
    required this.dueAt,
    required this.projectId,
    required this.projectName,
    required this.stateName,
    required this.stateColor,
    required this.category,
  });

  final String id;
  final String title;
  final String priority;
  final DateTime? dueAt;
  final String? projectId;
  final String? projectName;
  final String? stateName;
  final String? stateColor;
  final StateCategory category;

  bool isOverdue(DateTime now) {
    final due = dueAt;
    if (due == null) return false;
    return DateTime(due.year, due.month, due.day)
        .isBefore(DateTime(now.year, now.month, now.day));
  }

  factory HomeTask.fromJson(Map<String, dynamic> json) => HomeTask(
        id: '${json['id']}',
        title: '${json['title'] ?? ''}',
        priority: '${json['priority'] ?? 'medium'}',
        dueAt: DateTime.tryParse('${json['due_at'] ?? ''}'),
        projectId: json['project_id'] as String?,
        projectName: json['project_name'] as String?,
        stateName: json['state_name'] as String?,
        stateColor: json['state_color'] as String?,
        category: StateCategory.parse(json['category']),
      );
}

class HomeProject {
  const HomeProject({
    required this.id,
    required this.name,
    required this.isPrivate,
    required this.openTasks,
    required this.doneTasks,
  });

  final String id;
  final String name;
  final bool isPrivate;
  final int openTasks;
  final int doneTasks;

  double get progress {
    final total = openTasks + doneTasks;
    return total == 0 ? 0 : doneTasks / total;
  }

  factory HomeProject.fromJson(Map<String, dynamic> json) => HomeProject(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        isPrivate: json['visibility'] == 'private',
        openTasks: _int(json['open_tasks']),
        doneTasks: _int(json['done_tasks']),
      );
}

/// The team block, for the lead and admins only.
class HomeTeam {
  const HomeTeam({
    required this.members,
    required this.pendingInvites,
    required this.blocked,
    required this.unassigned,
    required this.overdue,
  });

  final int members;
  final int pendingInvites;
  final int blocked;
  final int unassigned;
  final int overdue;

  factory HomeTeam.fromJson(Map<String, dynamic> json) => HomeTeam(
        members: _int(json['members']),
        pendingInvites: _int(json['pending_invites']),
        blocked: _int(json['blocked']),
        unassigned: _int(json['unassigned']),
        overdue: _int(json['overdue']),
      );
}

/// `GET /v1/groups/{gid}/home`: the API decides what a role may see.
/// [myTasks] is null for guests and [team] is null for non-managers.
class GroupHome {
  const GroupHome({
    required this.access,
    required this.counts,
    required this.projects,
    required this.myTasks,
    required this.myOverdue,
    required this.team,
  });

  final GroupAccess access;
  final Map<StateCategory, int> counts;
  final List<HomeProject> projects;
  final List<HomeTask>? myTasks;
  final int myOverdue;
  final HomeTeam? team;

  int count(StateCategory c) => counts[c] ?? 0;

  int get openTasks =>
      count(StateCategory.backlog) + count(StateCategory.active) + count(StateCategory.blocked);

  factory GroupHome.fromJson(Map<String, dynamic> json) {
    final rawCounts = _map(json['counts']);
    final team = json['team'];
    return GroupHome(
      access: GroupAccess.fromJson(_map(json['group'])),
      counts: {for (final c in StateCategory.values) c: _int(rawCounts[c.wire])},
      projects: _list(json['projects']).map(HomeProject.fromJson).toList(),
      myTasks: json['my_tasks'] is List
          ? _list(json['my_tasks']).map(HomeTask.fromJson).toList()
          : null,
      myOverdue: _int(json['my_overdue']),
      team: team is Map ? HomeTeam.fromJson(_map(team)) : null,
    );
  }
}

/// The caller's standing in one project (`.../projects/{pid}/me`).
class ProjectAccess {
  const ProjectAccess({
    required this.id,
    required this.isPrivate,
    required this.override,
    required this.capabilities,
  });

  final String id;
  final bool isPrivate;

  /// 'edit', 'read' or null (the group roles apply).
  final String? override;
  final Set<String> capabilities;

  bool can(String capability) => capabilities.contains(capability);
  bool get canEditTasks => can(Caps.editTasks) || can(Caps.editOwnTasks);

  factory ProjectAccess.fromJson(Map<String, dynamic> json) => ProjectAccess(
        id: '${json['id']}',
        isPrivate: json['visibility'] == 'private',
        override: json['override'] as String?,
        capabilities: {
          for (final c in (json['capabilities'] as List? ?? const [])) '$c',
        },
      );
}

/// A project override (`.../projects/{pid}/members`).
class ProjectMemberOverride {
  const ProjectMemberOverride({
    required this.uid,
    required this.name,
    required this.access,
    required this.functionalRole,
    required this.groupRole,
  });

  final String uid;
  final String name;
  final String access;
  final String? functionalRole;
  final GroupRole groupRole;

  bool get readOnly => access == 'read';

  factory ProjectMemberOverride.fromJson(Map<String, dynamic> json) =>
      ProjectMemberOverride(
        uid: '${json['uid']}',
        name: '${json['name'] ?? json['uid']}',
        access: '${json['access'] ?? 'edit'}',
        functionalRole: json['functional_role'] as String?,
        groupRole: GroupRole.parse(json['group_role']) ?? GroupRole.member,
      );
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};

List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value.whereType<Map>().map(_map).toList(growable: false)
    : const [];
