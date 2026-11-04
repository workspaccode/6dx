import '../../../../core/network/current_workspace.dart';
import '../../../../core/network/supabase_client.dart';
import '../models/project_model.dart';

/// Projects of the current workspace, stored in the `projects` table.
class ProjectRemoteDataSource {
  ProjectRemoteDataSource(this._client, this._workspace);

  final SupabaseClientResolver _client;
  final CurrentWorkspace _workspace;

  /// Columns the model needs, with the linked repository and the task statuses
  /// embedded so one request feeds the whole projects screen.
  static const String _columns =
      'id, name, description, icon, color, is_archived, updated_at, '
      'repositories(full_name), tasks(status)';

  Future<List<ProjectModel>> getProjects() =>
      runSupabase('projects.list', () async {
        final rows = await _client()
            .from('projects')
            .select(_columns)
            .eq('workspace_id', await _workspace.resolve())
            .order('updated_at', ascending: false);
        return rows.map(_toModel).toList(growable: false);
      });

  Future<ProjectModel> createProject({
    required String name,
    String? description,
    String? repositoryFullName,
  }) =>
      runSupabase('projects.create', () async {
        final db = _client();
        final workspaceId = await _workspace.resolve();
        final inserted = await db
            .from('projects')
            .insert({
              'workspace_id': workspaceId,
              'name': name,
              'description': description,
              'created_by': db.auth.currentUser?.id,
            })
            .select(_columns)
            .single();

        final hasRepository =
            repositoryFullName != null && repositoryFullName.isNotEmpty;
        if (hasRepository) {
          await db.from('repositories').insert({
            'project_id': inserted['id'],
            'full_name': repositoryFullName,
          });
          inserted['repositories'] = [
            {'full_name': repositoryFullName},
          ];
        }
        return _toModel(inserted);
      });

  /// Projects are archived, never deleted: the `archived` filter reads the flag.
  Future<void> archiveProject(String id) =>
      runSupabase('projects.archive', () async {
        await _client()
            .from('projects')
            .update({'is_archived': true})
            .eq('id', id)
            .eq('workspace_id', await _workspace.resolve());
      });

  ProjectModel _toModel(Map<String, dynamic> row) {
    final repositories =
        (row['repositories'] as List?)?.whereType<Map>() ?? const <Map>[];
    final tasks = (row['tasks'] as List?)?.whereType<Map>() ?? const <Map>[];
    var openTasks = 0;
    var doneTasks = 0;
    for (final task in tasks) {
      if (task['status'] == 'done') {
        doneTasks++;
      } else {
        openTasks++;
      }
    }

    return ProjectModel(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      icon: row['icon'] as String?,
      colorHex: row['color'] as String?,
      openTasks: openTasks,
      doneTasks: doneTasks,
      repositoryFullName: repositories.isEmpty
          ? null
          : repositories.first['full_name'] as String?,
      isArchived: row['is_archived'] == true,
      updatedAt: DateTime.tryParse('${row['updated_at']}'),
    );
  }
}
