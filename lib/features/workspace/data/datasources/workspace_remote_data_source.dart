import 'package:dio/dio.dart';

import '../../../../core/constants/app_endpoints.dart';

class WorkspaceRemoteDataSource {
  WorkspaceRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /workspaces/{id}/snapshot`
  Future<Map<String, dynamic>?> getSnapshot(String workspaceId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppEndpoints.workspaces}/$workspaceId/snapshot',
    );
    return response.data;
  }

  Future<void> sendInvites({
    required String workspaceId,
    required List<String> emails,
    required String role,
    required bool addToRepository,
  }) async {
    await _dio.post<void>(
      '${AppEndpoints.workspaces}/$workspaceId/invites',
      data: {
        'emails': emails,
        'role': role,
        'add_to_repository': addToRepository,
      },
    );
  }

  Future<void> reviewPullRequest(
    String workspaceId,
    int number, {
    required bool approve,
  }) async {
    await _dio.post<void>(
      '${AppEndpoints.workspaces}/$workspaceId/pull_requests/$number/review',
      data: {'approve': approve},
    );
  }

  Future<void> approveTimeEntries(String workspaceId) async {
    await _dio.post<void>(
      '${AppEndpoints.workspaces}/$workspaceId/time_entries/approve',
    );
  }

  Future<void> submitClientDecision(
    String workspaceId,
    int optionIndex,
  ) async {
    await _dio.post<void>(
      '${AppEndpoints.workspaces}/$workspaceId/client_decisions',
      data: {'option_index': optionIndex},
    );
  }
}
