import 'package:dio/dio.dart';

import '../../../../core/constants/app_endpoints.dart';
import '../models/task_model.dart';

class TaskRemoteDataSource {
  TaskRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<TaskModel>> getTasks({String? projectId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      AppEndpoints.tasks,
      queryParameters: {if (projectId != null) 'project_id': projectId},
    );
    final items = _list(response.data);
    return items.map(TaskModel.fromJson).toList();
  }

  Future<TaskModel> createTask({
    required String title,
    String? description,
    String? projectId,
    String? priority,
    String? assigneeName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppEndpoints.tasks,
      data: {
        'title': title,
        if (description != null) 'description': description,
        if (projectId != null) 'project_id': projectId,
        if (priority != null) 'priority': priority,
        if (assigneeName != null) 'assignee': assigneeName,
      },
    );
    return TaskModel.fromJson(_unwrap(response.data));
  }

  Future<TaskModel> updateStatus(String id, String status) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${AppEndpoints.tasks}/$id',
      data: {'status': status},
    );
    return TaskModel.fromJson(_unwrap(response.data));
  }

  Future<void> deleteTask(String id) async {
    await _dio.delete<void>('${AppEndpoints.tasks}/$id');
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic>? body) {
    if (body == null) return const [];
    final data = body['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    return const [];
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) return const {};
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }
}
