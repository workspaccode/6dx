/// Groups (teams) — docs/design/groups-and-roles.md.
///
/// Plain immutable classes: the API is the source of truth for roles and
/// capabilities, the app only reads them to build routes and buttons.
library;

enum GroupType {
  software('software', 'Software'),
  hardware('hardware', 'Hardware');

  const GroupType(this.wire, this.label);
  final String wire;
  final String label;

  static GroupType parse(Object? value) =>
      value == 'hardware' ? GroupType.hardware : GroupType.software;
}

enum GroupRole {
  lead('lead', 'قائد المجموعة'),
  admin('admin', 'مساعد'),
  member('member', 'عضو'),
  guest('guest', 'ضيف / عميل');

  const GroupRole(this.wire, this.label);
  final String wire;
  final String label;

  bool get isManager => this == GroupRole.lead || this == GroupRole.admin;

  static GroupRole? parse(Object? value) {
    for (final role in GroupRole.values) {
      if (role.wire == value) return role;
    }
    return null;
  }
}

/// Functional roles per group type, in the order the pickers show them.
const functionalRoles = <GroupType, Map<String, String>>{
  GroupType.software: {
    'tech_lead': 'قائد تقني',
    'developer': 'مبرمج',
    'reviewer': 'مراجع كود',
    'qa': 'اختبار جودة',
    'designer': 'مصمم UI/UX',
    'devops': 'DevOps',
    'pm': 'مدير منتج',
    'client': 'عميل',
  },
  GroupType.hardware: {
    'hw_lead': 'قائد الهاردوير',
    'electrical': 'مهندس كهربا / PCB',
    'mechanical': 'مهندس ميكانيكا',
    'firmware': 'مهندس Firmware',
    'test': 'مهندس اختبار / جودة',
    'technician': 'فني',
    'manufacturing': 'مهندس تصنيع',
    'procurement': 'مشتريات',
    'client': 'عميل',
  },
};

String functionalRoleLabel(GroupType type, String? role) =>
    functionalRoles[type]?[role] ?? role ?? '—';

/// Capability names the API returns (backend/internal/api/caps.go).
abstract final class Caps {
  static const viewGroup = 'group.view';
  static const manageGroup = 'group.manage';
  static const deleteGroup = 'group.delete';
  static const manageMembers = 'members.manage';
  static const manageProjects = 'projects.manage';
  static const editTasks = 'tasks.edit';
  static const editOwnTasks = 'tasks.edit_own';
  static const comment = 'comments.write';
}

class PlanUsage {
  const PlanUsage({
    required this.planId,
    required this.name,
    required this.maxGroups,
    required this.usedGroups,
    required this.priceCentsMonthly,
  });

  final String planId;
  final String name;
  final int maxGroups;
  final int usedGroups;
  final int priceCentsMonthly;

  bool get canAddGroup => usedGroups < maxGroups;
  bool get isPaid => planId != 'free';

  factory PlanUsage.fromJson(Map<String, dynamic> json) => PlanUsage(
        planId: '${json['plan'] ?? 'free'}',
        name: '${json['name'] ?? ''}',
        maxGroups: _int(json['max_groups']),
        usedGroups: _int(json['used_groups']),
        priceCentsMonthly: _int(json['price_cents_monthly']),
      );
}

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.isDefault,
    required this.isArchived,
    required this.isMember,
    required this.groupRole,
    required this.functionalRole,
    required this.memberCount,
    required this.projectCount,
  });

  final String id;
  final String name;
  final GroupType type;
  final bool isDefault;
  final bool isArchived;
  final bool isMember;
  final GroupRole? groupRole;
  final String? functionalRole;
  final int memberCount;
  final int projectCount;

  String get roleLabel {
    final role = groupRole;
    if (role == null) return 'مدير مساحة العمل';
    if (role == GroupRole.guest) return role.label;
    return '${role.label} · ${functionalRoleLabel(type, functionalRole)}';
  }

  factory GroupSummary.fromJson(Map<String, dynamic> json) => GroupSummary(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        type: GroupType.parse(json['type']),
        isDefault: json['is_default'] == true,
        isArchived: json['is_archived'] == true,
        isMember: json['is_member'] == true,
        groupRole: GroupRole.parse(json['group_role']),
        functionalRole: json['functional_role'] as String?,
        memberCount: _int(json['member_count']),
        projectCount: _int(json['project_count']),
      );
}

class GroupsOverview {
  const GroupsOverview({required this.groups, required this.plan});
  final List<GroupSummary> groups;
  final PlanUsage plan;

  List<GroupSummary> get active =>
      groups.where((g) => !g.isArchived).toList(growable: false);
  List<GroupSummary> get archived =>
      groups.where((g) => g.isArchived).toList(growable: false);
}

/// The caller's standing in one group (`GET /v1/groups/{gid}/me`).
class GroupAccess {
  const GroupAccess({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.template,
    required this.isDefault,
    required this.isArchived,
    required this.isMember,
    required this.uid,
    required this.groupRole,
    required this.functionalRole,
    required this.capabilities,
  });

  /// The caller's uid as the API stores it (may differ from the session id
  /// for accounts created before the GitHub sign-in).
  final String uid;
  final String id;
  final String name;
  final String? description;
  final GroupType type;
  final String template;
  final bool isDefault;
  final bool isArchived;
  final bool isMember;
  final GroupRole? groupRole;
  final String? functionalRole;
  final Set<String> capabilities;

  bool can(String capability) => capabilities.contains(capability);

  bool get canEditTasks => can(Caps.editTasks) || can(Caps.editOwnTasks);

  String get roleLabel {
    final role = groupRole;
    if (role == null) return 'مدير مساحة العمل';
    if (role == GroupRole.guest) return role.label;
    return '${role.label} · ${functionalRoleLabel(type, functionalRole)}';
  }

  factory GroupAccess.fromJson(Map<String, dynamic> json) => GroupAccess(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        description: json['description'] as String?,
        type: GroupType.parse(json['type']),
        template: '${json['template'] ?? ''}',
        isDefault: json['is_default'] == true,
        isArchived: json['is_archived'] == true,
        isMember: json['is_member'] == true,
        uid: '${json['uid'] ?? ''}',
        groupRole: GroupRole.parse(json['group_role']),
        functionalRole: json['functional_role'] as String?,
        capabilities: {
          for (final c in (json['capabilities'] as List? ?? const [])) '$c',
        },
      );
}

class GroupMember {
  const GroupMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.groupRole,
    required this.functionalRole,
  });

  final String uid;
  final String name;
  final String? email;
  final String? avatarUrl;
  final GroupRole groupRole;
  final String functionalRole;

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        uid: '${json['uid']}',
        name: '${json['name'] ?? json['uid']}',
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        groupRole: GroupRole.parse(json['group_role']) ?? GroupRole.member,
        functionalRole: '${json['functional_role'] ?? ''}',
      );
}

class GroupProject {
  const GroupProject({
    required this.id,
    required this.name,
    required this.description,
    required this.openTasks,
    required this.doneTasks,
    required this.isArchived,
  });

  final String id;
  final String name;
  final String? description;
  final int openTasks;
  final int doneTasks;
  final bool isArchived;

  factory GroupProject.fromJson(Map<String, dynamic> json) => GroupProject(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        description: json['description'] as String?,
        openTasks: _int(json['open_tasks']),
        doneTasks: _int(json['done_tasks']),
        isArchived: json['is_archived'] == true,
      );
}

class GroupTask {
  const GroupTask({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.projectId,
  });

  final String id;
  final String title;
  final String status;
  final String priority;
  final String? projectId;

  factory GroupTask.fromJson(Map<String, dynamic> json) => GroupTask(
        id: '${json['id']}',
        title: '${json['title'] ?? ''}',
        status: '${json['status'] ?? 'todo'}',
        priority: '${json['priority'] ?? 'medium'}',
        projectId: json['project_id'] as String?,
      );
}

/// The invite screen (`GET /v1/invites/{id}`).
class InviteDetails {
  const InviteDetails({
    required this.id,
    required this.status,
    required this.workspaceId,
    required this.workspaceName,
    required this.groupId,
    required this.groupName,
    required this.groupType,
    required this.groupRole,
    required this.functionalRole,
    required this.invitedBy,
    required this.alreadyMember,
  });

  final String id;
  final String status;
  final String workspaceId;
  final String workspaceName;
  final String? groupId;
  final String? groupName;
  final GroupType groupType;
  final GroupRole? groupRole;
  final String? functionalRole;
  final String? invitedBy;
  final bool alreadyMember;

  bool get isPending => status == 'pending';

  String get roleLabel => groupRole == GroupRole.guest
      ? GroupRole.guest.label
      : functionalRoleLabel(groupType, functionalRole);

  factory InviteDetails.fromJson(Map<String, dynamic> json) => InviteDetails(
        id: '${json['id']}',
        status: '${json['status'] ?? ''}',
        workspaceId: '${json['workspace_id'] ?? ''}',
        workspaceName: '${json['workspace_name'] ?? ''}',
        groupId: json['group_id'] as String?,
        groupName: json['group_name'] as String?,
        groupType: GroupType.parse(json['group_type']),
        groupRole: GroupRole.parse(json['group_role']),
        functionalRole: json['functional_role'] as String?,
        invitedBy: json['invited_by'] as String?,
        alreadyMember: json['already_member'] == true,
      );
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
