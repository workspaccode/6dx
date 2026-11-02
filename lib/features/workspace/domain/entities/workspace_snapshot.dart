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
    this.agents = const [],
    this.agentRules = const [],
    this.knowledgeAreas = const [],
    this.commits = const [],
    this.releases = const [],
    this.dependencies = const [],
    this.joinRequests = const [],
    this.unlinkedContributors = const [],
    this.codePlatforms = const [],
    this.estimateRecords = const [],
    this.sprintRetros = const [],
    this.weeklyClientSummaries = const [],
    this.projectReports = const [],
    this.regionalCalendar,
    this.billing,
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
  final List<WorkspaceAgent> agents;
  final List<AgentRule> agentRules;
  final List<KnowledgeArea> knowledgeAreas;
  final List<CommitEntry> commits;
  final List<ReleaseNote> releases;
  final List<TaskDependency> dependencies;
  final List<InviteRequest> joinRequests;
  final List<UnlinkedContributor> unlinkedContributors;
  final List<CodePlatform> codePlatforms;
  final List<EstimateRecord> estimateRecords;
  final List<SprintRetro> sprintRetros;
  final List<WeeklyClientSummary> weeklyClientSummaries;
  final List<ProjectReport> projectReports;
  final RegionalCalendar? regionalCalendar;
  final BillingSummary? billing;

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
      clientReport == null &&
      agents.isEmpty &&
      commits.isEmpty &&
      releases.isEmpty &&
      dependencies.isEmpty &&
      codePlatforms.isEmpty &&
      projectReports.isEmpty;

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

// ---------------------------------------------------------------------------
// Entities for the remaining workspace screens. They follow the same rule as
// the rest of the model: read-only projections coming from the API.
// ---------------------------------------------------------------------------

class WorkspaceAgent {
  const WorkspaceAgent({
    required this.id,
    required this.name,
    required this.kind,
    this.description,
    this.avatarUrl,
    this.pullRequests = const [],
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String kind;
  final String? description;
  final String? avatarUrl;
  final List<String> pullRequests;
  final bool isOnline;
}

class AgentRule {
  const AgentRule({
    required this.id,
    required this.title,
    required this.description,
    this.enabled = true,
    this.alwaysOn = false,
  });

  final String id;
  final String title;
  final String description;
  final bool enabled;
  final bool alwaysOn;
}

class KnowledgeArea {
  const KnowledgeArea({
    required this.id,
    required this.path,
    required this.contributors,
    this.singleOwnerPercent,
    this.note,
  });

  final String id;
  final String path;

  /// `name` → share of the commits (0..1).
  final Map<String, double> contributors;
  final double? singleOwnerPercent;
  final String? note;
}

class CommitEntry {
  const CommitEntry({
    required this.sha,
    required this.message,
    required this.author,
    required this.branch,
    this.date,
  });

  final String sha;
  final String message;
  final String author;
  final String branch;
  final DateTime? date;
}

class ReleaseNote {
  const ReleaseNote({
    required this.id,
    required this.version,
    required this.projectName,
    this.releaseDate,
    this.items = const [],
    this.blockedReason,
    this.blockedTaskKey,
  });

  final String id;
  final String version;
  final String projectName;
  final DateTime? releaseDate;
  final List<String> items;
  final String? blockedReason;
  final String? blockedTaskKey;
}

class TaskDependency {
  const TaskDependency({
    required this.id,
    required this.taskKey,
    required this.title,
    required this.state,
    this.reason,
    this.assigneeName,
  });

  final String id;
  final String taskKey;
  final String title;

  /// `blocked` | `blocking` | `review`
  final String state;
  final String? reason;
  final String? assigneeName;
}

class InviteRequest {
  const InviteRequest({
    required this.id,
    required this.email,
    required this.role,
    this.requestedAt,
    this.source = 'invite_link',
  });

  final String id;
  final String email;
  final String role;
  final DateTime? requestedAt;
  final String source;
}

class UnlinkedContributor {
  const UnlinkedContributor({
    required this.id,
    required this.handle,
    required this.commitsCount,
    this.isBot = false,
  });

  final String id;
  final String handle;
  final int commitsCount;
  final bool isBot;
}

class CodePlatform {
  const CodePlatform({
    required this.id,
    required this.name,
    required this.connected,
    this.workspace,
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final bool connected;
  final String? workspace;
  final int memberCount;
}

class BillingSummary {
  const BillingSummary({
    required this.planName,
    required this.seatsUsed,
    required this.seatsTotal,
    this.billingCycle,
    this.paymentMethod,
    this.invoices = const [],
  });

  final String planName;
  final int seatsUsed;
  final int seatsTotal;
  final String? billingCycle;
  final String? paymentMethod;
  final List<({String id, String date, double amount})> invoices;
}

class RegionalCalendar {
  const RegionalCalendar({
    required this.id,
    required this.country,
    this.workWeek = const [],
    this.holidays = const [],
  });

  final String id;
  final String country;

  /// ISO weekday numbers (1 = Monday).
  final List<int> workWeek;
  final List<({String name, DateTime? date})> holidays;
}

class EstimateRecord {
  const EstimateRecord({
    required this.id,
    required this.taskKey,
    required this.title,
    required this.estimate,
    required this.actual,
    this.category,
  });

  final String id;
  final String taskKey;
  final String title;
  final int estimate;
  final int actual;
  final String? category;
}

class SprintRetro {
  const SprintRetro({
    required this.id,
    required this.sprintName,
    this.notes = const [],
    this.completedPoints = 0,
    this.committedPoints = 0,
  });

  final String id;
  final String sprintName;
  final List<String> notes;
  final int completedPoints;
  final int committedPoints;
}

class WeeklyClientSummary {
  const WeeklyClientSummary({
    required this.id,
    required this.clientName,
    required this.items,
    this.pullRequestCount = 0,
    this.generatedAt,
  });

  final String id;
  final String clientName;
  final List<String> items;
  final int pullRequestCount;
  final DateTime? generatedAt;
}

class ProjectReport {
  const ProjectReport({
    required this.id,
    required this.projectName,
    this.averagePointsPerSprint,
    this.averageCycleDays,
    this.reworkRatio,
    this.workDistribution = const <String, double>{},
    this.averageFirstReviewHours,
  });

  final String id;
  final String projectName;
  final double? averagePointsPerSprint;
  final double? averageCycleDays;
  final double? reworkRatio;

  /// `state` → share of the work (0..1).
  final Map<String, double> workDistribution;
  final double? averageFirstReviewHours;
}
