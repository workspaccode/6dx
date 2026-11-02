import 'package:dio/dio.dart';

import '../../../../core/constants/app_endpoints.dart';
import '../models/project_model.dart';

class ProjectRemoteDataSource {
  ProjectRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<ProjectModel>> getProjects() async {
    final response = await _dio.get<Map<String, dynamic>>(AppEndpoints.projects);
    final items = _list(response.data);
    return items.map(ProjectModel.fromJson).toList();
  }

  Future<ProjectModel> createProject({
    required String name,
    String? description,
    String? repositoryFullName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppEndpoints.projects,
      data: {
        'name': name,
        if (description != null) 'description': description,
        if (repositoryFullName != null) 'repository': repositoryFullName,
      },
    );
    return ProjectModel.fromJson(_unwrap(response.data));
  }

  Future<void> archiveProject(String id) async {
    await _dio.delete<void>('${AppEndpoints.projects}/$id');
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic>? body) {
    if (body == null) return const [];
    final data = body['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
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
