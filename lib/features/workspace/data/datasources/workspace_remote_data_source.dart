import '../../../../core/network/api_client.dart';
import '../../../../core/network/current_workspace.dart';

/// Reads and writes the workspace projection through the Go backend.
///
/// Every screen still consumes one snapshot payload
/// (`GET /v1/workspace/snapshot`) whose shape matches what the Postgres
/// function used to return, so `WorkspaceSnapshotMapper` and the screens are
/// unchanged.
class WorkspaceRemoteDataSource {
  WorkspaceRemoteDataSource(this._api, this._workspace);

  final ApiClient _api;
  final CurrentWorkspace _workspace;

  /// The one payload every screen reads.
  Future<Map<String, dynamic>?> getSnapshot() =>
      _api.run('workspace.snapshot', () async {
        await _workspace.resolve();
        return _api.get('/v1/workspace/snapshot');
      });

  /// Creates one invite per e-mail. The backend also notifies an invitee who
  /// already has an account.
  Future<void> sendInvites({
    required List<String> emails,
    required String role,
    required bool addToRepository,
  }) =>
      _api.run('workspace.invites', () async {
        await _workspace.resolve();
        await _api.post('/v1/invites', body: {
          'emails': emails,
          'role': role,
        });
      });

  /// Records the review verdict on the pull request.
  Future<void> reviewPullRequest(int number, {required bool approve}) =>
      _api.run('workspace.pr_review', () async {
        await _workspace.resolve();
        await _api.post('/v1/pull-requests/$number/review',
            body: {'approve': approve});
      });

  /// Records the approval as an activity event so the client report shows it.
  Future<void> approveTimeEntries() =>
      _api.run('workspace.time_approve', () async {
        await _workspace.resolve();
        await _api.post('/v1/time-entries/approve');
      });

  /// Stores the chosen option of the client report.
  ///
  /// The endpoint accepts any member, so a `viewer` (an external client) can
  /// record the decision too.
  Future<void> submitClientDecision(int optionIndex) =>
      _api.run('workspace.client_decision', () async {
        await _workspace.resolve();
        await _api.post('/v1/client-report/decision',
            body: {'option_index': optionIndex});
      });

  Future<void> markNotificationRead(String id) =>
      _api.run('workspace.notification_read', () async {
        await _workspace.resolve();
        await _api.post('/v1/notifications/${Uri.encodeComponent(id)}/read');
      });

  Future<void> markAllNotificationsRead() =>
      _api.run('workspace.notifications_read_all', () async {
        await _workspace.resolve();
        await _api.post('/v1/notifications/read-all');
      });

  /// Workspace role of a member (owner / admin only; the server enforces it).
  Future<void> changeMemberRole(String uid, String role) =>
      _api.run('workspace.member_role', () async {
        await _workspace.resolve();
        await _api.patch('/v1/members/${Uri.encodeComponent(uid)}', body: {'role': role});
      });

  Future<void> removeMember(String uid) =>
      _api.run('workspace.member_remove', () async {
        await _workspace.resolve();
        await _api.delete('/v1/members/${Uri.encodeComponent(uid)}');
      });

  Future<void> addComment(String taskId, String body) =>
      _api.run('workspace.comment_add', () async {
        await _workspace.resolve();
        await _api.post('/v1/tasks/${Uri.encodeComponent(taskId)}/comments', body: {'body': body});
      });

  Future<void> addSubtask(String taskId, String title) =>
      _api.run('workspace.subtask_add', () async {
        await _workspace.resolve();
        await _api.post('/v1/tasks/${Uri.encodeComponent(taskId)}/subtasks', body: {'title': title});
      });

  Future<void> toggleSubtask(String subtaskId, {required bool done}) =>
      _api.run('workspace.subtask_toggle', () async {
        await _workspace.resolve();
        await _api.patch('/v1/subtasks/${Uri.encodeComponent(subtaskId)}', body: {'done': done});
      });

  Future<void> declineInvite(String inviteId) =>
      _api.run('workspace.decline_invite', () async {
        await _api.post('/v1/invites/${Uri.encodeComponent(inviteId)}/decline');
      });

  /// Turns the caller's pending invite into a membership.
  ///
  /// Returns the workspace that was joined. [inviteId] may be null: the server
  /// then accepts the newest pending invite addressed to the caller's e-mail.
  Future<String?> acceptInvite({String? inviteId}) =>
      _api.run('workspace.accept_invite', () async {
        final payload = await _api.post('/v1/invites/accept', body: {
          if (inviteId != null) 'invite_id': inviteId,
        });
        final joined = payload['workspace_id'] as String?;
        if (joined != null && joined.isNotEmpty) {
          // Act on the workspace that was just joined. `resolve()` would ask
          // /v1/me without X-Workspace-Id, and the server then answers the
          // account's *first* membership — usually its personal workspace.
          _workspace.activate(joined);
        }
        return joined;
      });

  /// Creates the notifications for invites that arrived before the account
  /// existed. Idempotent, so calling it on every app start is fine.
  Future<int> syncMyInvites() => _api.run('workspace.sync_invites', () async {
        final payload = await _api.post('/v1/invites/sync');
        return (payload['created'] as num?)?.toInt() ?? 0;
      });

  /// Pending invites addressed to the caller, for the accept screen.
  Future<List<Map<String, dynamic>>> myPendingInvites() =>
      _api.run('workspace.pending_invites', () async {
        final payload = await _api.get('/v1/invites/pending');
        final invites = payload['invites'];
        if (invites is! List) return const <Map<String, dynamic>>[];
        return invites
            .whereType<Map>()
            .map((row) => <String, dynamic>{
                  for (final entry in row.entries) '${entry.key}': entry.value,
                })
            .toList(growable: false);
      });
}
