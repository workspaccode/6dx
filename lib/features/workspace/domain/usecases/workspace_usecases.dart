import '../entities/workspace_snapshot.dart';
import '../repositories/workspace_repository.dart';

class GetWorkspaceSnapshot {
  const GetWorkspaceSnapshot(this._repository);

  final WorkspaceRepository _repository;

  Future<WorkspaceSnapshot> call() => _repository.getSnapshot();
}

class SendInvites {
  const SendInvites(this._repository);

  final WorkspaceRepository _repository;

  Future<void> call({
    required List<String> emails,
    required String role,
    bool addToRepository = false,
  }) =>
      _repository.sendInvites(
        emails: emails,
        role: role,
        addToRepository: addToRepository,
      );
}

class AcceptInvite {
  const AcceptInvite(this._repository);

  final WorkspaceRepository _repository;

  Future<String?> call({String? inviteId}) =>
      _repository.acceptInvite(inviteId: inviteId);
}

class SyncMyInvites {
  const SyncMyInvites(this._repository);

  final WorkspaceRepository _repository;

  Future<int> call() => _repository.syncMyInvites();
}

class GetPendingInvites {
  const GetPendingInvites(this._repository);

  final WorkspaceRepository _repository;

  Future<List<WorkspaceInvite>> call() => _repository.pendingInvites();
}
