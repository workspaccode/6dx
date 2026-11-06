import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/workspace_snapshot.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../datasources/workspace_remote_data_source.dart';
import '../models/workspace_snapshot_mapper.dart';

class WorkspaceRepositoryImpl implements WorkspaceRepository {
  WorkspaceRepositoryImpl({required WorkspaceRemoteDataSource remote})
      : _remote = remote,
        _mapper = const WorkspaceSnapshotMapper();

  final WorkspaceRemoteDataSource _remote;
  final WorkspaceSnapshotMapper _mapper;

  WorkspaceSnapshot _cache = const WorkspaceSnapshot();

  @override
  Future<WorkspaceSnapshot> getSnapshot() async {
    try {
      final payload = await _remote.getSnapshot();
      _cache = _mapper.fromJson(payload);
      return _cache;
    } on ServerException catch (e) {
      AppLogger.w('WorkspaceRepo', 'Failed to load snapshot', e);
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> sendInvites({
    required List<String> emails,
    required String role,
    bool addToRepository = false,
  }) async {
    await _remote.sendInvites(
      emails: emails,
      role: role,
      addToRepository: addToRepository,
    );
  }

  @override
  Future<void> reviewPullRequest(int number, {required bool approve}) async {
    await _remote.reviewPullRequest(number, approve: approve);
  }

  @override
  Future<void> approveTimeEntries() async {
    await _remote.approveTimeEntries();
  }

  @override
  Future<void> submitClientDecision(int optionIndex) async {
    await _remote.submitClientDecision(optionIndex);
  }

  @override
  Future<String?> acceptInvite({String? inviteId}) =>
      _remote.acceptInvite(inviteId: inviteId);

  @override
  Future<int> syncMyInvites() => _remote.syncMyInvites();

  @override
  Future<List<WorkspaceInvite>> pendingInvites() async {
    final rows = await _remote.myPendingInvites();
    return rows
        .map(
          (row) => WorkspaceInvite(
            id: '${row['invite_id'] ?? ''}',
            email: '${row['email'] ?? ''}',
            role: '${row['role'] ?? ''}',
            status: 'pending',
            sentAt: DateTime.tryParse('${row['sent_at']}'),
            invitedBy: row['workspace_name'] as String?,
          ),
        )
        .toList(growable: false);
  }
}
