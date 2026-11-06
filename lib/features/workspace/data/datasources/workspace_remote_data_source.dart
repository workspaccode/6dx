import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import '../../../../core/network/current_workspace.dart';
import '../../../../core/network/firebase_client.dart';

/// Reads and writes the workspace projection through Firestore + Cloud
/// Functions.
///
/// The old backend served one SQL function (`get_workspace_snapshot`) that
/// joined everything in a single query. Firestore has no joins, so the same
/// payload is assembled here from parallel collection reads — the shape is
/// identical, so `WorkspaceSnapshotMapper` does not change.
///
/// Everything a member cannot do with plain reads (invites, accepting,
/// client decisions) goes through Cloud Functions, which re-check the roles
/// the way the RLS policies used to.
class WorkspaceRemoteDataSource {
  WorkspaceRemoteDataSource(this._db, this._workspace);

  final FirebaseFirestoreResolver _db;
  final CurrentWorkspace _workspace;

  /// The one payload every screen reads — the Firestore twin of
  /// `get_workspace_snapshot(target)`.
  Future<Map<String, dynamic>?> getSnapshot() =>
      runFirestore('workspace.snapshot', () async {
        final db = _db();
        final wsId = await _workspace.resolve();
        final wsRef = db.doc('workspaces/$wsId');
        final userId = FirebaseAuth.instance.currentUser?.uid;

        final workspace = await wsRef.get();
        if (!workspace.exists) return null;

        final membersSnap =
            await wsRef.collection('members').orderBy('createdAt').get();
        final invitesSnap = await wsRef.collection('invites').get();
        final tasksSnap = await wsRef
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .get();
        final activitySnap = await wsRef
            .collection('activity')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .get();
        final sprintsSnap =
            await wsRef.collection('sprints').orderBy('startsAt').get();
        final prsSnap = await wsRef.collection('pullRequests').get();
        final integrationsSnap = await wsRef.collection('integrations').get();
        final reportSnap =
            await wsRef.collection('clientReport').doc('report').get();

        // Projects + labels + repositories (labels and repositories hang
        // off their project, exactly like the SQL schema).
        final projectsSnap =
            await wsRef.collection('projects').orderBy('updatedAt').get();
        final labels = <Map<String, dynamic>>[];
        final repositories = <Map<String, dynamic>>[];
        final projectNameById = <String, String>{};
        final labelLists = await Future.wait([
          for (final project in projectsSnap.docs)
            project.reference.collection('labels').get(),
        ]);
        final repositoryLists = await Future.wait([
          for (final project in projectsSnap.docs)
            project.reference.collection('repositories').get(),
        ]);
        for (var i = 0; i < projectsSnap.docs.length; i++) {
          final project = projectsSnap.docs[i];
          projectNameById[project.id] = project.get('name') as String? ?? '';
          labels.addAll([
            for (final label in labelLists[i].docs)
              {
                'id': label.id,
                'name': label.get('name'),
                'color': label.get('color'),
              },
          ]);
          repositories.addAll([
            for (final repo in repositoryLists[i].docs)
              {
                'id': repo.id,
                'full_name': repo.get('fullName'),
                'branch': repo.get('branch') ?? 'main',
                'description': repo.get('description'),
                'language': repo.get('language'),
                'last_synced_at': _toIso(repo.get('lastSyncedAt')),
              },
          ]);
        }

        // Task subcollections in parallel (comments, subtasks, dependencies).
        final commentLists = await Future.wait([
          for (final task in tasksSnap.docs)
            task.reference.collection('comments').orderBy('createdAt').get(),
        ]);
        final subtaskLists = await Future.wait([
          for (final task in tasksSnap.docs)
            task.reference.collection('subtasks').get(),
        ]);
        final dependencyLists = await Future.wait([
          for (final task in tasksSnap.docs)
            task.reference.collection('dependencies').get(),
        ]);

        final comments = <Map<String, dynamic>>[];
        final subtasks = <Map<String, dynamic>>[];
        final dependencies = <Map<String, dynamic>>[];
        final commentAuthorIds = <String>{};
        final taskById = <String, DocumentSnapshot>{};
        for (var i = 0; i < tasksSnap.docs.length; i++) {
          final task = tasksSnap.docs[i];
          taskById[task.id] = task;
          for (final comment in commentLists[i].docs) {
            final authorId = comment.get('authorId') as String?;
            if (authorId != null) commentAuthorIds.add(authorId);
            comments.add({
              'id': comment.id,
              'task_id': task.id,
              'author_id': authorId,
              'author': authorId,
              'body': comment.get('body'),
              'attachment': comment.get('attachment'),
              'code': comment.get('code'),
              'created_at': _toIso(comment.get('createdAt')),
            });
          }
          subtasks.addAll([
            for (final subtask in subtaskLists[i].docs)
              {
                'id': subtask.id,
                'task_id': task.id,
                'title': subtask.get('title'),
                'is_done': subtask.get('isDone') == true,
              },
          ]);
          dependencies.addAll([
            for (final dependency in dependencyLists[i].docs)
              {
                'id': dependency.id,
                'task_id': task.id,
                'blocked_by': dependency.get('blockedBy'),
                'state': dependency.get('state') ?? 'blocked',
                'reason': dependency.get('reason'),
              },
          ]);
        }

        // Sprint items live under each sprint, keyed by the task id.
        final sprintItemLists = await Future.wait([
          for (final sprint in sprintsSnap.docs)
            sprint.reference.collection('items').get(),
        ]);

        // Profiles of everybody that shows a name (members, comment authors).
        final profileIds = <String>{
          for (final member in membersSnap.docs) member.id,
          ...commentAuthorIds,
        };
        final profiles = await _loadProfiles(db, profileIds);

        final tasks = [
          for (final task in tasksSnap.docs)
            {
              'id': task.id,
              'key': task.get('key'),
              'title': task.get('title'),
              'description': task.get('description'),
              'status': task.get('status') ?? 'todo',
              'priority': task.get('priority') ?? 'medium',
              'points': task.get('points') ?? 0,
              'project_id': task.get('projectId'),
              'project_name':
                  projectNameById[task.get('projectId') as String?],
              'assignee_id': task.get('assigneeId'),
              'assignee_name': _profileName(profiles, task.get('assigneeId')),
              'label': task.get('label'),
              'branch': task.get('branch'),
              'pr_number': task.get('prNumber'),
              'due_at': _toIso(task.get('dueAt')),
              'created_at': _toIso(task.get('createdAt')),
            },
        ];
        final taskKeyById = <String, String>{
          for (final task in tasksSnap.docs)
            task.id: (task.get('key') as String?) ?? '',
        };

        // Per-user surfaces of the caller only.
        Map<String, dynamic>? notificationsPayload;
        Map<String, dynamic>? digestPayload;
        List<Map<String, dynamic>> timeEntriesPayload = const [];
        if (userId != null) {
          final notifications = await db
              .collection('users/$userId/notifications')
              .orderBy('createdAt', descending: true)
              .limit(100)
              .get();
          final digest = await db
              .collection('users/$userId/digest')
              .where('workspaceId', isEqualTo: wsId)
              .get();
          final timeEntries = await db
              .collection('users/$userId/timeEntries')
              .where('workspaceId', isEqualTo: wsId)
              .get();
          notificationsPayload = {
            for (final notification in notifications.docs)
              notification.id: {
                'id': notification.id,
                'kind': notification.get('kind') ?? 'review',
                'title': notification.get('title') ?? '',
                'body': notification.get('body') ?? '',
                'action_label': notification.get('actionLabel'),
                'project_id': notification.get('projectId'),
                'unread': notification.get('isRead') != true,
                'at': _toIso(notification.get('createdAt')),
                'invite_id': notification.get('inviteId'),
              },
          };
          digestPayload = {
            for (final entry in digest.docs)
              entry.id: {
                'id': entry.id,
                'section': entry.get('section') ?? 'today',
                'text': entry.get('text') ?? '',
                'meta': entry.get('meta'),
                'action_label': entry.get('actionLabel'),
                'tone': entry.get('tone'),
              },
          };
          timeEntriesPayload = [
            for (final entry in timeEntries.docs)
              {
                'id': entry.id,
                'kind': entry.get('kind'),
                'span': entry.get('span'),
                'branch': entry.get('branch'),
                'client_name': entry.get('clientName'),
                'created_at': _toIso(entry.get('createdAt')),
              },
          ];
        }

        final reportData = reportSnap.data();
        return <String, dynamic>{
          'workspace_id': wsId,
          'name': workspace.get('name') ?? 'مساحة عمل',
          'members': [
            for (final member in membersSnap.docs)
              {
                'id': member.id,
                'name': _profileName(profiles, member.id),
                'role': member.get('role') ?? 'developer',
                'email': _profileEmail(profiles, member.id),
                'avatar_url': _profileAvatar(profiles, member.id),
                'open_tasks': _openTasks(tasks, member.id),
                'is_online': false,
              },
          ],
          'invites': [
            for (final invite in invitesSnap.docs)
              {
                'id': invite.id,
                'email': invite.get('email'),
                'role': invite.get('role'),
                'status': invite.get('status') ?? 'pending',
                'sent_at': _toIso(invite.get('sentAt')),
                'invited_by': _profileName(profiles, invite.get('invitedBy')),
              },
          ],
          'tasks': tasks,
          'comments': comments,
          'subtasks': subtasks,
          'dependencies': [
            for (final dependency in dependencies)
              {
                ...dependency,
                'task_key': taskKeyById[dependency['task_id']] ?? '',
                'assignee_name': _profileName(
                    profiles, taskById[dependency['task_id']]?.get('assigneeId')),
              },
          ],
          'activity': [
            for (final event in activitySnap.docs)
              {
                'id': event.id,
                'type': event.get('type') ?? '',
                'text': event.get('text') ?? '',
                'actor': _profileName(profiles, event.get('actorId')),
                'at': _toIso(event.get('createdAt')),
              },
          ],
          'sprints': [
            for (var i = 0; i < sprintsSnap.docs.length; i++)
              {
                'id': sprintsSnap.docs[i].id,
                'name': sprintsSnap.docs[i].get('name') ?? '',
                'goal': sprintsSnap.docs[i].get('goal'),
                'start': _toIso(sprintsSnap.docs[i].get('startsAt')),
                'end': _toIso(sprintsSnap.docs[i].get('endsAt')),
                'capacity': sprintsSnap.docs[i].get('capacity') ?? 0,
                'committed': sprintsSnap.docs[i].get('committed') ?? 0,
                'items': [
                  for (final item in sprintItemLists[i].docs)
                    {
                      'task_id': item.id,
                      'key': taskKeyById[item.id] ?? '',
                      'title': taskById[item.id]?.get('title') ?? '',
                      'points': item.get('points') ?? 0,
                      'assignee_id': taskById[item.id]?.get('assigneeId'),
                    },
                ],
              },
          ],
          'pull_requests': [
            for (final pr in prsSnap.docs)
              {
                'id': pr.id,
                'number': pr.get('number') ?? 0,
                'title': pr.get('title') ?? '',
                'author': pr.get('author'),
                'branch': pr.get('branch') ?? '',
                'base_branch': pr.get('baseBranch') ?? 'main',
                'state': pr.get('state') ?? 'open',
                'issue_key': null,
                'project_name': null,
                'checks': pr.get('checks') ?? <String>[],
                'files': pr.get('files') ?? <String>[],
                'additions': pr.get('additions') ?? 0,
                'deletions': pr.get('deletions') ?? 0,
                'reviewer_name': _profileName(profiles, pr.get('reviewerId')),
                'last_commit': pr.get('lastCommit'),
                'last_commit_author': null,
                'waiting_hours': 0,
              },
          ],
          'labels': labels,
          'integrations': [
            for (final integration in integrationsSnap.docs)
              {
                'id': integration.id,
                'name': integration.get('name') ?? '',
                'kind': integration.get('kind') ?? 'slack',
                'connected': integration.get('connected') == true,
                'workspace': integration.get('workspace'),
                'channels': integration.get('channels') ?? <String>[],
                'events': integration.get('events') ?? <String>[],
              },
          ],
          'repositories': repositories,
          'notifications': notificationsPayload?.values.toList() ?? const [],
          'digest': digestPayload?.values.toList() ?? const [],
          'client_report': reportData == null
              ? null
              : {
                  'client_name': reportData['clientName'],
                  'project_name': reportData['projectName'],
                  'period': reportData['period'],
                  'progress': reportData['progress'] ?? 0,
                  'next_milestone': reportData['nextMilestone'],
                  'milestone_date': reportData['milestoneDate'],
                  'decision_question': reportData['decisionQuestion'],
                  'decision_options': reportData['decisionOptions'] ?? <String>[],
                  'weekly_highlights':
                      reportData['weeklyHighlights'] ?? <String>[],
                  'invoice_lines': reportData['invoiceLines'] ?? <String>[],
                  'total_hours': reportData['totalHours'],
                  'hourly_rate': reportData['hourlyRate'],
                  'invoice_number': reportData['invoiceNumber'],
                  'delivered_items': reportData['deliveredItems'] ?? <String>[],
                  'decision_choice': reportData['decisionChoice'],
                  'time_entries': timeEntriesPayload,
                  'week_by_client': [
                    for (final entry in timeEntriesPayload)
                      {
                        'client': entry['client_name'],
                        'hours': entry['span'],
                      },
                  ],
                },
        };
      });

  /// Creates one invite per e-mail through the `sendInvites` Cloud Function,
  /// which also notifies existing accounts (the old DB trigger).
  Future<void> sendInvites({
    required List<String> emails,
    required String role,
    required bool addToRepository,
  }) =>
      runFirestore('workspace.invites', () async {
        await callFunction('sendInvites', {
          'workspaceId': await _workspace.resolve(),
          'emails': emails,
          'role': role,
        });
      });

  /// Records the review verdict on the pull request.
  Future<void> reviewPullRequest(int number, {required bool approve}) =>
      runFirestore('workspace.pr_review', () async {
        final db = _db();
        await db
            .doc('workspaces/${await _workspace.resolve()}/pullRequests/$number')
            .update({
          'state': approve ? 'approved' : 'changes_requested',
          'reviewerId': _currentUid(),
        });
      });

  /// The approval is recorded as an activity event so the client report can
  /// show it (there is no approval column on the time entries).
  Future<void> approveTimeEntries() =>
      runFirestore('workspace.time_approve', () async {
        final db = _db();
        final wsId = await _workspace.resolve();
        final entries = await db
            .collection('users/${_currentUid() ?? ''}/timeEntries')
            .where('workspaceId', isEqualTo: wsId)
            .get();
        await db.collection('workspaces/$wsId/activity').add({
          'type': 'time_approved',
          'text': 'تم اعتماد ${entries.size} سجل وقت',
          'actorId': _currentUid(),
          'projectId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

  /// Stores the chosen option of the client report through the
  /// `submitClientDecision` Cloud Function, so a `viewer` (an external
  /// client) can record the decision too.
  Future<void> submitClientDecision(int optionIndex) =>
      runFirestore('workspace.client_decision', () async {
        await callFunction('submitClientDecision', {
          'workspaceId': await _workspace.resolve(),
          'optionIndex': optionIndex,
        });
      });

  /// Turns the caller's pending invite into a membership.
  ///
  /// Returns the workspace that was joined. [inviteId] may be null: the
  /// function then accepts the newest pending invite addressed to the
  /// caller's e-mail.
  Future<String?> acceptInvite({String? inviteId}) =>
      runFirestore('workspace.accept_invite', () async {
        final result = await callFunction('acceptInvite', {
          if (inviteId != null) 'inviteId': inviteId,
        });
        return result['workspaceId'] as String?;
      });

  /// Creates the notifications for invites that arrived before the account
  /// existed. Idempotent, so calling it on every app start is fine.
  Future<int> syncMyInvites() =>
      runFirestore('workspace.sync_invites', () async {
        final result = await callFunction('syncMyInvites', const {});
        return (result['created'] as num?)?.toInt() ?? 0;
      });

  /// Pending invites addressed to the caller, for the accept screen.
  Future<List<Map<String, dynamic>>> myPendingInvites() =>
      runFirestore('workspace.pending_invites', () async {
        final result = await callFunction('myPendingInvites', const {});
        final invites = result['invites'];
        if (invites is! List) return const <Map<String, dynamic>>[];
        return invites
            .whereType<Map>()
            .map((row) => <String, dynamic>{
                  for (final entry in row.entries) '${entry.key}': entry.value,
                })
            .toList(growable: false);
      });

  // --- helpers ------------------------------------------------------------

  String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;

  Future<Map<String, Map<String, dynamic>>> _loadProfiles(
    FirebaseFirestore db,
    Set<String> uids,
  ) async {
    final profiles = <String, Map<String, dynamic>>{};
    await Future.wait([
      for (final uid in uids)
        db.doc('users/$uid').get().then((doc) {
          if (doc.exists) profiles[uid] = doc.data() ?? const {};
        }),
    ]);
    return profiles;
  }

  static String? _profileName(
    Map<String, Map<String, dynamic>> profiles,
    Object? uid,
  ) {
    if (uid is! String || uid.isEmpty) return null;
    final profile = profiles[uid];
    final name = profile?['displayName'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final email = profile?['email'] as String?;
    return email;
  }

  static String? _profileEmail(
    Map<String, Map<String, dynamic>> profiles,
    String uid,
  ) =>
      profiles[uid]?['email'] as String?;

  static String? _profileAvatar(
    Map<String, Map<String, dynamic>> profiles,
    String uid,
  ) =>
      profiles[uid]?['photoURL'] as String?;

  static int _openTasks(List<Map<String, dynamic>> tasks, String memberId) =>
      tasks
          .where((task) =>
              task['assignee_id'] == memberId && task['status'] != 'done')
          .length;

  static String? _toIso(Object? value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    return null;
  }
}
