import '../entities/workspace_snapshot.dart';

abstract interface class WorkspaceRepository {
  /// Fetches the whole workspace projection used by the secondary screens.
  Future<WorkspaceSnapshot> getSnapshot();

  /// Sends an invitation to [emails] with the given [role].
  Future<void> sendInvites({
    required List<String> emails,
    required String role,
    bool addToRepository = false,
  });

  /// Updates the status of a pull request (approve / merge).
  Future<void> reviewPullRequest(int number, {required bool approve});

  /// Acknowledges the daily time entries.
  Future<void> approveTimeEntries();

  /// Confirms a client decision (option index).
  Future<void> submitClientDecision(int optionIndex);

  /// Accepts a pending invitation; returns the joined workspace id.
  ///
  /// With no [inviteId] the server accepts the newest pending invite addressed
  /// to the caller's e-mail.
  Future<String?> acceptInvite({String? inviteId});

  /// Delivers notifications for invites that arrived before the account
  /// existed. Returns how many were created.
  Future<int> syncMyInvites();

  /// Pending invites for the signed-in account.
  Future<List<WorkspaceInvite>> pendingInvites();
}
