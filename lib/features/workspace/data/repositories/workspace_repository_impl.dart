import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/workspace_snapshot.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../datasources/workspace_remote_data_source.dart';
import '../models/workspace_snapshot_mapper.dart';

class WorkspaceRepositoryImpl implements WorkspaceRepository {
  WorkspaceRepositoryImpl({
    required WorkspaceRemoteDataSource remote,
    required this.workspaceId,
  })  : _remote = remote,
        _mapper = const WorkspaceSnapshotMapper();

  final WorkspaceRemoteDataSource _remote;
  final WorkspaceSnapshotMapper _mapper;
  final String workspaceId;

  WorkspaceSnapshot _cache = const WorkspaceSnapshot();

  @override
  Future<WorkspaceSnapshot> getSnapshot() async {
    if (AppConfig.useMockData) {
      // The demo catalogue is loaded by the provider layer in demo mode.
      return _cache;
    }
    try {
      final payload = await _remote.getSnapshot(workspaceId);
      _cache = _mapper.fromJson(payload);
      return _cache;
    } on DioException catch (e) {
      AppLogger.w('WorkspaceRepo', 'Failed to load snapshot', e);
      throw ServerException(e.message ?? 'تعذّر تحميل بيانات مساحة العمل');
    }
  }

  @override
  Future<void> sendInvites({
    required List<String> emails,
    required String role,
    bool addToRepository = false,
  }) async {
    if (AppConfig.useMockData) return;
    await _remote.sendInvites(
      workspaceId: workspaceId,
      emails: emails,
      role: role,
      addToRepository: addToRepository,
    );
  }

  @override
  Future<void> reviewPullRequest(int number, {required bool approve}) async {
    if (AppConfig.useMockData) return;
    await _remote.reviewPullRequest(workspaceId, number, approve: approve);
  }

  @override
  Future<void> approveTimeEntries() async {
    if (AppConfig.useMockData) return;
    await _remote.approveTimeEntries(workspaceId);
  }

  @override
  Future<void> submitClientDecision(int optionIndex) async {
    if (AppConfig.useMockData) return;
    await _remote.submitClientDecision(workspaceId, optionIndex);
  }
}
