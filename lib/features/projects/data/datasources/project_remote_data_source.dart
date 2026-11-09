import '../../../../core/network/api_client.dart';
import '../../../../core/network/current_workspace.dart';
import '../models/project_model.dart';

/// Projects of the current workspace — `GET/POST /v1/projects`.
class ProjectRemoteDataSource {
  ProjectRemoteDataSource(this._api, this._workspace);

  final ApiClient _api;
  final CurrentWorkspace _workspace;

  Future<List<ProjectModel>> getProjects() =>
      _api.run('projects.list', () async {
        await _workspace.resolve();
        final payload = await _api.get('/v1/projects');
        final rows = payload['projects'];
        if (rows is! List) return const <ProjectModel>[];
        return rows
            .whereType<Map>()
            .map((row) => _toModel(row))
            .toList(growable: false);
      });

  Future<ProjectModel> createProject({
    required String name,
    String? description,
    String? repositoryFullName,
  }) =>
      _api.run('projects.create', () async {
        await _workspace.resolve();
        final payload = await _api.post('/v1/projects', body: {
          'name': name,
          if (description != null) 'description': description,
          if (repositoryFullName != null && repositoryFullName.isNotEmpty)
            'repository_full_name': repositoryFullName,
        });
        final project = payload['project'];
        if (project is! Map) {
          throw ArgumentError('unexpected response shape');
        }
        return _toModel(project);
      });

  /// Projects are archived, never deleted: the `archived` filter reads the flag.
  Future<void> archiveProject(String id) =>
      _api.run('projects.archive', () async {
        await _workspace.resolve();
        await _api.post('/v1/projects/$id/archive');
      });

  ProjectModel _toModel(Map<dynamic, dynamic> row) => ProjectModel(
        id: '${row['id']}',
        name: '${row['name']}',
        description: row['description'] as String?,
        icon: row['icon'] as String?,
        colorHex: row['color'] as String?,
        openTasks: (row['open_tasks'] as num?)?.toInt() ?? 0,
        doneTasks: (row['done_tasks'] as num?)?.toInt() ?? 0,
        repositoryFullName: row['repository_full_name'] as String?,
        isArchived: row['is_archived'] == true,
        updatedAt: DateTime.tryParse('${row['updated_at']}'),
      );
}
