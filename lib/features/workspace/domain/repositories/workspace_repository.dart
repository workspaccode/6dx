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
}
