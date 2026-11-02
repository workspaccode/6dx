import '../../domain/entities/workspace_snapshot.dart';

/// Maps the API payload (`GET /workspaces/{id}/snapshot`) onto the domain
/// entities. Every field is optional on the wire so a partially available
/// backend still renders.
class WorkspaceSnapshotMapper {
  const WorkspaceSnapshotMapper();

  WorkspaceSnapshot fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WorkspaceSnapshot();
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    return WorkspaceSnapshot(
      workspaceId: _str(data['workspace_id']) ?? _str(data['id']),
      workspaceName: _str(data['name']),
      members: _list(data['members']).map(_member).toList(growable: false),
      invites: _list(data['invites']).map(_invite).toList(growable: false),
      comments: _list(data['comments']).map(_comment).toList(growable: false),
      subtasks: _list(data['subtasks']).map(_subtask).toList(growable: false),
      activity: _list(data['activity']).map(_activity).toList(growable: false),
      sprints: _list(data[' sprints']).map(_sprint).toList(growable: false),
      pullRequests:
          _list(data['pull_requests']).map(_pullRequest).toList(growable: false),
      labels: _list(data['labels']).map(_label).toList(growable: false),
      integrations:
          _list(data['integrations']).map(_integration).toList(growable: false),
      repositories:
          _list(data['repositories']).map(_repository).toList(growable: false),
      notifications:
          _list(data['notifications']).map(_notification).toList(growable: false),
      digest: _list(data['digest']).map(_digest).toList(growable: false),
      workload: _list(data['workload']).map(_workload).toList(growable: false),
      workloadSuggestions:
          _list(data['workload_suggestions']).map(_suggestion).toList(growable: false),
      clientReport: data['client_report'] is Map<String, dynamic>
          ? _clientReport(data['client_report'] as Map<String, dynamic>)
          : null,
      apiRateLimit: data['rate_limit'] is Map<String, dynamic>
          ? (
              used: _int((data['rate_limit'] as Map<String, dynamic>)['used']) ?? 0,
              limit: _int((data['rate_limit'] as Map<String, dynamic>)['limit']) ?? 0,
            )
          : null,
    );
  }

  // --- helpers -----------------------------------------------------------

  static List<Map<String, dynamic>> _list(Object? value) =>
      value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];

  static String? _str(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _int(Object? value) => value is num ? value.toInt() : null;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  WorkspaceMember _member(Map<String, dynamic> json) => WorkspaceMember(
        id: _str(json['id']) ?? '',
        name: _str(json['name']) ?? '',
        role: _str(json['role']) ?? '',
        email: _str(json['email']),
        avatarUrl: _str(json['avatar_url']),
        openTasks: _int(json['open_tasks']) ?? 0,
        isOnline: json['is_online'] == true,
      );

  WorkspaceInvite _invite(Map<String, dynamic> json) => WorkspaceInvite(
        id: _str(json['id']) ?? '',
        email: _str(json['email']) ?? '',
        role: _str(json['role']) ?? '',
        status: _str(json['status']) ?? 'pending',
        sentAt: _date(json['sent_at']),
        invitedBy: _str(json['invited_by']),
      );

  TaskComment _comment(Map<String, dynamic> json) => TaskComment(
        id: _str(json['id']) ?? '',
        taskId: _str(json['task_id']) ?? '',
        author: _str(json['author']) ?? '',
        body: _str(json['body']) ?? '',
        attachmentName: _str(json['attachment']),
        code: _str(json['code']),
        createdAt: _date(json['created_at']),
        isAuthor: json['is_author'] == true,
      );

  TaskSubtask _subtask(Map<String, dynamic> json) => TaskSubtask(
        id: _str(json['id']) ?? '',
        taskId: _str(json['task_id']) ?? '',
        title: _str(json['title']) ?? '',
        isDone: json['is_done'] == true,
      );

  ActivityEvent _activity(Map<String, dynamic> json) => ActivityEvent(
        id: _str(json['id']) ?? '',
        type: _str(json['type']) ?? '',
        text: _str(json['text']) ?? '',
        actor: _str(json['actor']),
        at: _date(json['at']),
      );

  Sprint _sprint(Map<String, dynamic> json) => Sprint(
        id: _str(json['id']) ?? '',
        name: _str(json['name']) ?? '',
        goal: _str(json['goal']),
        start: _date(json['start']) ?? DateTime.now(),
        end: _date(json['end']) ?? DateTime.now(),
        capacity: _int(json['capacity']) ?? 0,
        committed: _int(json['committed']) ?? 0,
        items: _list(json['items']).map(_sprintItem).toList(growable: false),
        memberIds: _strings(json['member_ids']),
      );

  SprintItem _sprintItem(Map<String, dynamic> json) => SprintItem(
        taskId: _str(json['task_id']) ?? '',
        key: _str(json['key']) ?? '',
        title: _str(json['title']) ?? '',
        points: _int(json['points']) ?? 0,
        assigneeId: _str(json['assignee_id']),
        fromGithub: json['from_github'] == true,
      );

  PullRequest _pullRequest(Map<String, dynamic> json) => PullRequest(
        id: _str(json['id']) ?? '',
        number: _int(json['number']) ?? 0,
        title: _str(json['title']) ?? '',
        author: _str(json['author']) ?? '',
        branch: _str(json['branch']) ?? '',
        baseBranch: _str(json['base_branch']) ?? 'main',
        state: _str(json['state']) ?? 'open',
        issueKey: _str(json['issue_key']),
        projectName: _str(json['project_name']),
        checks: _list(json['checks']).map(_check).toList(growable: false),
        files: _list(json['files']).map(_file).toList(growable: false),
        additions: _int(json['additions']) ?? 0,
        deletions: _int(json['deletions']) ?? 0,
        reviewerName: _str(json['reviewer_name']),
        lastCommit: _str(json['last_commit']),
        lastCommitAuthor: _str(json['last_commit_author']),
        failureReason: _str(json['failure_reason']),
        expectedStatus: _str(json['expected_status']),
        receivedStatus: _str(json['received_status']),
        waitingHours: _int(json['waiting_hours']) ?? 0,
        draft: json['draft'] == true,
      );

  CheckRun _check(Map<String, dynamic> json) => CheckRun(
        name: _str(json['name']) ?? '',
        duration: _str(json['duration']) ?? '',
        passed: json['passed'] == true,
      );

  ChangedFile _file(Map<String, dynamic> json) => ChangedFile(
        path: _str(json['path']) ?? '',
        additions: _int(json['additions']) ?? 0,
        deletions: _int(json['deletions']) ?? 0,
      );

  ProjectLabel _label(Map<String, dynamic> json) => ProjectLabel(
        id: _str(json['id']) ?? '',
        name: _str(json['name']) ?? '',
        color: _int(json['color']) ?? 0xFF9AA3B2,
      );

  ProjectIntegration _integration(Map<String, dynamic> json) => ProjectIntegration(
        id: _str(json['id']) ?? '',
        name: _str(json['name']) ?? '',
        kind: _str(json['kind']) ?? 'slack',
        connected: json['connected'] == true,
        workspace: _str(json['workspace']),
        channels: _strings(json['channels']),
        events: _strings(json['events']),
        comingSoon: json['coming_soon'] == true,
      );

  LinkedRepository _repository(Map<String, dynamic> json) => LinkedRepository(
        id: _str(json['id']) ?? '',
        fullName: _str(json['full_name']) ?? '',
        branch: _str(json['branch']) ?? 'main',
        description: _str(json['description']),
        lastSyncedAt: _date(json['last_synced_at']),
        language: _str(json['language']),
      );

  AppNotification _notification(Map<String, dynamic> json) => AppNotification(
        id: _str(json['id']) ?? '',
        kind: _str(json['kind']) ?? 'review',
        title: _str(json['title']) ?? '',
        body: _str(json['body']) ?? '',
        at: _date(json['at']),
        unread: json['unread'] == true,
        actionLabel: _str(json['action_label']),
        projectId: _str(json['project_id']),
      );

  DigestEntry _digest(Map<String, dynamic> json) => DigestEntry(
        id: _str(json['id']) ?? '',
        section: _str(json['section']) ?? 'today',
        text: _str(json['text']) ?? '',
        meta: _str(json['meta']),
        actionLabel: _str(json['action_label']),
        tone: _str(json['tone']),
      );

  WorkloadEntry _workload(Map<String, dynamic> json) => WorkloadEntry(
        memberId: _str(json['member_id']) ?? '',
        name: _str(json['name']) ?? '',
        openPoints: _int(json['open_points']) ?? 0,
        capacity: _int(json['capacity']) ?? 0,
      );

  WorkloadSuggestion _suggestion(Map<String, dynamic> json) => WorkloadSuggestion(
        id: _str(json['id']) ?? '',
        taskId: _str(json['task_id']) ?? '',
        taskTitle: _str(json['task_title']) ?? '',
        points: _int(json['points']) ?? 0,
        fromMemberId: _str(json['from_member_id']) ?? '',
        fromMemberName: _str(json['from_member_name']) ?? '',
        toMemberId: _str(json['to_member_id']) ?? '',
        toMemberName: _str(json['to_member_name']) ?? '',
        reason: _str(json['reason']),
      );

  ClientReport _clientReport(Map<String, dynamic> json) => ClientReport(
        clientName: _str(json['client_name']) ?? '',
        projectName: _str(json['project_name']) ?? '',
        period: _str(json['period']),
        progress: (json['progress'] is num ? (json['progress'] as num).toDouble() : 0),
        nextMilestone: _str(json['next_milestone']),
        milestoneDate: _date(json['milestone_date']),
        decisionQuestion: _str(json['decision_question']),
        decisionOptions: _strings(json['decision_options']),
        weeklyHighlights: _strings(json['weekly_highlights']),
        invoiceLines: _list(json['invoice_lines'])
            .map(
              (line) => ClientInvoiceLine(
                label: _str(line['label']) ?? '',
                hours: _str(line['hours']) ?? '',
              ),
            )
            .toList(growable: false),
        totalHours: _str(json['total_hours']),
        hourlyRate: _str(json['hourly_rate']),
        invoiceNumber: _str(json['invoice_number']),
        deliveredItems: _strings(json['delivered_items']),
        timeEntries: _list(json['time_entries'])
            .map(
              (entry) => TimeEntry(
                id: _str(entry['id']) ?? '',
                kind: _str(entry['kind']) ?? '',
                span: _str(entry['span']) ?? '',
                branch: _str(entry['branch']),
                clientName: _str(entry['client_name']),
              ),
            )
            .toList(growable: false),
        weekByClient: _list(json['week_by_client'])
            .map(
              (row) => (
                client: _str(row['client']) ?? '',
                hours: _str(row['hours']) ?? '',
              ),
            )
            .toList(growable: false),
      );

  static List<String> _strings(Object? value) =>
      value is List ? value.whereType<String>().toList(growable: false) : const [];
}
