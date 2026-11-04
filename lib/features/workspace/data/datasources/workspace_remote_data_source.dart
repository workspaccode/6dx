import '../../../../core/network/current_workspace.dart';
import '../../../../core/network/supabase_client.dart';

/// Reads and writes the workspace projection through Supabase.
///
/// Every query runs under the caller's JWT, so row level security keeps a
/// member inside their own workspace.
class WorkspaceRemoteDataSource {
  WorkspaceRemoteDataSource(this._client, this._workspace);

  final SupabaseClientResolver _client;
  final CurrentWorkspace _workspace;

  /// `get_workspace_snapshot(target)` — one payload for every screen, so the
  /// app never runs an N+1 query per widget.
  Future<Map<String, dynamic>?> getSnapshot() =>
      runSupabase('workspace.snapshot', () async {
        final payload = await _client().rpc(
          'get_workspace_snapshot',
          params: {'target': await _workspace.resolve()},
        );
        return payload is Map<String, dynamic> ? payload : null;
      });

  /// Inserts one invite row per email.
  ///
  /// [addToRepository] has no column in the schema (repository access travels
  /// with the project, not with the invite), so the flag is accepted only for
  /// API compatibility.
  Future<void> sendInvites({
    required List<String> emails,
    required String role,
    required bool addToRepository,
  }) =>
      runSupabase('workspace.invites', () async {
        final db = _client();
        final workspaceId = await _workspace.resolve();
        final invitedBy = db.auth.currentUser?.id;
        await db.from('workspace_invites').insert([
          for (final email in emails)
            {
              'workspace_id': workspaceId,
              'email': email.trim(),
              'role': role,
              'invited_by': invitedBy,
            },
        ]);
        await _logActivity(
          'member_invited',
          'تمت دعوة ${emails.length} عضو بدور $role',
        );
      });

  /// Records the review verdict on the pull request.
  Future<void> reviewPullRequest(int number, {required bool approve}) =>
      runSupabase('workspace.pr_review', () async {
        final db = _client();
        await db
            .from('pull_requests')
            .update({
              'state': approve ? 'approved' : 'changes_requested',
              'reviewer_id': db.auth.currentUser?.id,
            })
            .eq('workspace_id', await _workspace.resolve())
            .eq('number', number);
      });

  /// The schema has no approval column on `time_entries`: the approval is
  /// recorded as an activity event so the client report can show it.
  Future<void> approveTimeEntries() =>
      runSupabase('workspace.time_approve', () async {
        final db = _client();
        final workspaceId = await _workspace.resolve();
        final entries = await db
            .from('time_entries')
            .select('id')
            .eq('workspace_id', workspaceId);
        await _logActivity(
          'time_approved',
          'تم اعتماد ${entries.length} سجل وقت',
        );
      });

  /// Stores the chosen option of the client report as an activity event.
  Future<void> submitClientDecision(int optionIndex) =>
      runSupabase('workspace.client_decision', () async {
        final db = _client();
        final workspaceId = await _workspace.resolve();
        final rows = await db
            .from('client_reports')
            .select('decision_options')
            .eq('workspace_id', workspaceId)
            .limit(1);
        final options = rows.isEmpty
            ? const <dynamic>[]
            : (rows.first['decision_options'] as List?) ?? const <dynamic>[];
        final chosen = optionIndex >= 0 && optionIndex < options.length
            ? '${options[optionIndex]}'
            : 'الخيار ${optionIndex + 1}';
        await _logActivity('client_decision', 'قرار العميل: $chosen');
      });

  Future<void> _logActivity(String type, String text) async {
    final db = _client();
    await db.from('activity_events').insert({
      'workspace_id': await _workspace.resolve(),
      'type': type,
      'text': text,
      'actor_id': db.auth.currentUser?.id,
    });
  }
}
