/// Immutable domain entities describing the current workspace snapshot.
///
/// The API exposes them under a single payload (`GET /workspaces/{id}/snapshot`)
/// so the app can render every screen without N+1 requests. They are plain
/// Dart classes on purpose: they are read-only projections, not entities
/// with behaviour.
library;

class WorkspaceMember {
  const WorkspaceMember({
    required this.id,
    required this.name,
    required this.role,
    this.email,
    this.avatarUrl,
    this.openTasks = 0,
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String role;
  final String? email;
  final String? avatarUrl;
  final int openTasks;
  final bool isOnline;

  String get initials {
    if (name.isEmpty) return '؟';
    final trimmed = name.trim();
    return trimmed.length <= 2 ? trimmed : trimmed.substring(0, 2);
  }
}

class WorkspaceInvite {
  const WorkspaceInvite({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    this.sentAt,
    this.invitedBy,
  });

  final String id;
  final String email;
  final String role;
  final String status;
  final DateTime? sentAt;
  final String? invitedBy;
}

class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    required this.author,
    required this.body,
    this.attachmentName,
    this.code,
    this.createdAt,
    this.isAuthor = false,
  });

  final String id;
  final String taskId;
  final String author;
  final String body;
  final String? attachmentName;
  final String? code;
  final DateTime? createdAt;
  final bool isAuthor;
}

class TaskSubtask {
  const TaskSubtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.isDone = false,
  });

  final String id;
  final String taskId;
  final String title;
  final bool isDone;
}

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.type,
    required this.text,
    this.actor,
    this.at,
  });

  final String id;

  /// `merged` | `comment` | `sync` | `member_joined` | `deleted` | `role_changed`
  final String type;
  final String text;
  final String? actor;
  final DateTime? at;
}

class SprintItem {
  const SprintItem({
    required this.taskId,
    required this.key,
    required this.title,
    required this.points,
    this.assigneeId,
    this.fromGithub = false,
  });

  final String taskId;
  final String key;
  final String title;
  final int points;
  final String? assigneeId;
  final bool fromGithub;
}

class Sprint {
  const Sprint({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.capacity,
    required this.committed,
    this.goal,
    this.items = const [],
    this.memberIds = const [],
  });

  final String id;
  final String name;
  final DateTime start;
  final DateTime end;
  final int capacity;
  final int committed;
  final String? goal;
  final List<SprintItem> items;
  final List<String> memberIds;

  int get remainingPoints => committed - capacity;
}

class CheckRun {
  const CheckRun({
    required this.name,
    required this.duration,
    required this.passed,
  });

  final String name;
  final String duration;
  final bool passed;
}

class ChangedFile {
  const ChangedFile({
    required this.path,
    required this.additions,
    required this.deletions,
  });

  final String path;
  final int additions;
  final int deletions;
}

class PullRequest {
  const PullRequest({
    required this.id,
    required this.number,
    required this.title,
    required this.author,
    required this.branch,
    required this.baseBranch,
    required this.state,
    this.issueKey,
    this.projectName,
    this.checks = const [],
    this.files = const [],
    this.additions = 0,
    this.deletions = 0,
    this.reviewerName,
    this.lastCommit,
    this.lastCommitAuthor,
    this.failureReason,
    this.expectedStatus,
    this.receivedStatus,
    this.waitingHours = 0,
    this.draft = false,
  });

  final String id;
  final int number;
  final String title;
  final String author;
  final String branch;
  final String baseBranch;
  final String state;
  final String? issueKey;
  final String? projectName;
  final List<CheckRun> checks;
  final List<ChangedFile> files;
  final int additions;
  final int deletions;
  final String? reviewerName;
  final String? lastCommit;
  final String? lastCommitAuthor;
  final String? failureReason;
  final String? expectedStatus;
  final String? receivedStatus;
  final int waitingHours;
  final bool draft;

  bool get allChecksPassed => checks.isNotEmpty && checks.every((c) => c.passed);
}

class ProjectLabel {
  const ProjectLabel({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final int color;
}

class ProjectIntegration {
  const ProjectIntegration({
    required this.id,
    required this.name,
    required this.kind,
    required this.connected,
    this.workspace,
    this.channels = const [],
    this.events = const [],
    this.comingSoon = false,
  });

  final String id;
  final String name;

  /// `slack` | `discord` | `teams`
  final String kind;
  final bool connected;
  final String? workspace;
  final List<String> channels;
  final List<String> events;
  final bool comingSoon;
}

class LinkedRepository {
  const LinkedRepository({
    required this.id,
    required this.fullName,
    required this.branch,
    this.description,
    this.lastSyncedAt,
    this.language,
  });

  final String id;
  final String fullName;
  final String branch;
  final String? description;
  final DateTime? lastSyncedAt;
  final String? language;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.at,
    this.unread = false,
    this.actionLabel,
    this.projectId,
  });

  final String id;

  /// `review` | `checks` | `comment` | `invite` | `mention`
  final String kind;
  final String title;
  final String body;
  final DateTime? at;
  final bool unread;
  final String? actionLabel;
  final String? projectId;
}

class DigestEntry {
  const DigestEntry({
    required this.id,
    required this.section,
    required this.text,
    this.meta,
    this.actionLabel,
    this.tone,
  });

  final String id;

  /// `done` | `today` | `blocker`
  final String section;
  final String text;
  final String? meta;
  final String? actionLabel;
  final String? tone;
}

class WorkloadEntry {
  const WorkloadEntry({
    required this.memberId,
    required this.name,
    required this.openPoints,
    required this.capacity,
  });

  final String memberId;
  final String name;
  final int openPoints;
  final int capacity;

  bool get overloaded => openPoints > capacity;
}

class WorkloadSuggestion {
  const WorkloadSuggestion({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.points,
    required this.fromMemberId,
    required this.fromMemberName,
    required this.toMemberId,
    required this.toMemberName,
    this.reason,
  });

  final String id;
  final String taskId;
  final String taskTitle;
  final int points;
  final String fromMemberId;
  final String fromMemberName;
  final String toMemberId;
  final String toMemberName;
  final String? reason;
}

class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.kind,
    required this.span,
    this.branch,
    this.clientName,
  });

  final String id;
  final String kind;
  final String span;
  final String? branch;
  final String? clientName;
}

class ClientInvoiceLine {
  const ClientInvoiceLine({required this.label, required this.hours});

  final String label;
  final String hours;
}

class ClientReport {
  const ClientReport({
    required this.clientName,
    required this.projectName,
    this.period,
    this.progress = 0,
    this.nextMilestone,
    this.milestoneDate,
    this.decisionQuestion,
    this.decisionOptions = const [],
    this.weeklyHighlights = const [],
    this.invoiceLines = const [],
    this.totalHours,
    this.hourlyRate,
    this.invoiceNumber,
    this.deliveredItems = const [],
    this.timeEntries = const [],
    this.weekByClient = const [],
  });

  final String clientName;
  final String projectName;
  final String? period;
  final double progress;
  final String? nextMilestone;
  final DateTime? milestoneDate;
  final String? decisionQuestion;
  final List<String> decisionOptions;
  final List<String> weeklyHighlights;
  final List<ClientInvoiceLine> invoiceLines;
  final String? totalHours;
  final String? hourlyRate;
  final String? invoiceNumber;
  final List<String> deliveredItems;
  final List<TimeEntry> timeEntries;
  final List<({String client, String hours})> weekByClient;
}

/// Everything the app needs to render the workspace screens.
class WorkspaceSnapshot {
  const WorkspaceSnapshot({
    this.workspaceId,
    this.workspaceName,
    this.members = const [],
    this.invites = const [],
    this.comments = const [],
    this.subtasks = const [],
    this.activity = const [],
    this.sprints = const [],
    this.pullRequests = const [],
    this.labels = const [],
    this.integrations = const [],
    this.repositories = const [],
    this.notifications = const [],
    this.digest = const [],
    this.workload = const [],
    this.workloadSuggestions = const [],
    this.clientReport,
    this.apiRateLimit,
  });

  final String? workspaceId;
  final String? workspaceName;
  final List<WorkspaceMember> members;
  final List<WorkspaceInvite> invites;
  final List<TaskComment> comments;
  final List<TaskSubtask> subtasks;
  final List<ActivityEvent> activity;
  final List<Sprint> sprints;
  final List<PullRequest> pullRequests;
  final List<ProjectLabel> labels;
  final List<ProjectIntegration> integrations;
  final List<LinkedRepository> repositories;
  final List<AppNotification> notifications;
  final List<DigestEntry> digest;
  final List<WorkloadEntry> workload;
  final List<WorkloadSuggestion> workloadSuggestions;
  final ClientReport? clientReport;
  final ({int used, int limit})? apiRateLimit;

  bool get isEmpty =>
      members.isEmpty &&
      invites.isEmpty &&
      comments.isEmpty &&
      subtasks.isEmpty &&
      activity.isEmpty &&
      sprints.isEmpty &&
      pullRequests.isEmpty &&
      labels.isEmpty &&
      integrations.isEmpty &&
      repositories.isEmpty &&
      notifications.isEmpty &&
      digest.isEmpty &&
      workload.isEmpty &&
      clientReport == null;

  List<TaskComment> commentsFor(String taskId) =>
      comments.where((c) => c.taskId == taskId).toList(growable: false);

  List<TaskSubtask> subtasksFor(String taskId) =>
      subtasks.where((s) => s.taskId == taskId).toList(growable: false);

  PullRequest? pullRequestByNumber(int number) {
    for (final pr in pullRequests) {
      if (pr.number == number) return pr;
    }
    return null;
  }
}
