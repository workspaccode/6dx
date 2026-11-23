import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/workspace_remote_data_source.dart';
import 'workspace_providers.dart';

/// Writes from the classic screens. Each one calls the API and then
/// refreshes the snapshot, so every screen shows the new state; failures
/// are thrown to the caller, which shows them (never swallowed).
class WorkspaceActions {
  WorkspaceActions(this._ref);
  final Ref _ref;

  Future<void> _run(Future<void> Function(WorkspaceRemoteDataSource api) action) async {
    await action(_ref.read(workspaceRemoteDataSourceProvider));
    _ref.invalidate(workspaceSnapshotProvider);
  }

  Future<void> markNotificationRead(String id) => _run((api) => api.markNotificationRead(id));
  Future<void> markAllNotificationsRead() => _run((api) => api.markAllNotificationsRead());
  Future<void> changeMemberRole(String uid, String role) => _run((api) => api.changeMemberRole(uid, role));
  Future<void> removeMember(String uid) => _run((api) => api.removeMember(uid));
  Future<void> reviewPullRequest(int number,
          {required bool approve, String? repository}) =>
      _run((api) => api.reviewPullRequest(number,
          approve: approve, repository: repository));
  Future<void> approveTimeEntries() => _run((api) => api.approveTimeEntries());
  Future<void> submitClientDecision(int optionIndex) => _run((api) => api.submitClientDecision(optionIndex));
  Future<void> declineInvite(String inviteId) => _run((api) => api.declineInvite(inviteId));
  Future<void> addComment(String taskId, String body) => _run((api) => api.addComment(taskId, body));
  Future<void> addSubtask(String taskId, String title) => _run((api) => api.addSubtask(taskId, title));
  Future<void> toggleSubtask(String subtaskId, {required bool done}) =>
      _run((api) => api.toggleSubtask(subtaskId, done: done));
}

final workspaceActionsProvider = Provider<WorkspaceActions>(WorkspaceActions.new);
