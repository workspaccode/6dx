import '../../../../core/network/current_workspace.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/task.dart';
import '../models/task_model.dart';

/// Tasks of the current workspace, stored in the `tasks` table.
class TaskRemoteDataSource {
  TaskRemoteDataSource(this._client, this._workspace);

  final SupabaseClientResolver _client;
  final CurrentWorkspace _workspace;

  static const String _columns =
      'id, title, description, status, priority, project_id, label, branch, '
      'pr_number, due_at, created_at, projects(name)';

  Future<List<TaskModel>> getTasks({String? projectId}) =>
      runSupabase('tasks.list', () async {
        final base = _client()
            .from('tasks')
            .select(_columns)
            .eq('workspace_id', await _workspace.resolve());
        final filtered =
            projectId == null ? base : base.eq('project_id', projectId);
        final rows = await filtered.order('created_at', ascending: false);
        return rows.map(_toModel).toList(growable: false);
      });

  /// Creates a task. The assignee is not settable from the app yet: the schema
  /// stores `assignee_id` (an `auth.users` id the client cannot resolve from a
  /// display name), so [assigneeName] is accepted for API compatibility only.
  Future<TaskModel> createTask({
    required String title,
    String? description,
    String? projectId,
    String? priority,
    String? assigneeName,
  }) =>
      runSupabase('tasks.create', () async {
        final inserted = await _client()
            .from('tasks')
            .insert({
              'workspace_id': await _workspace.resolve(),
              'title': title,
              'description': description,
              'project_id': projectId,
              'priority': priority ?? TaskPriority.medium.name,
            })
            .select(_columns)
            .single();
        return _toModel(inserted);
      });

  Future<TaskModel> updateStatus(String id, String status) =>
      runSupabase('tasks.update_status', () async {
        final updated = await _client()
            .from('tasks')
            .update({'status': status})
            .eq('id', id)
            .eq('workspace_id', await _workspace.resolve())
            .select(_columns)
            .single();
        return _toModel(updated);
      });

  Future<void> deleteTask(String id) =>
      runSupabase('tasks.delete', () async {
        await _client()
            .from('tasks')
            .delete()
            .eq('id', id)
            .eq('workspace_id', await _workspace.resolve());
      });

  TaskModel _toModel(Map<String, dynamic> row) {
    final project = row['projects'];
    return TaskModel(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['description'] as String?,
      status: statusFromDb(row['status']),
      priority: TaskPriority.values.firstWhere(
        (value) => value.name == row['priority'],
        orElse: () => TaskPriority.medium,
      ),
      projectId: row['project_id'] as String?,
      projectName: project is Map ? project['name'] as String? : null,
      label: row['label'] as String?,
      branchName: row['branch'] as String?,
      prNumber: row['pr_number']?.toString(),
      dueDate: DateTime.tryParse('${row['due_at']}'),
      createdAt: DateTime.tryParse('${row['created_at']}'),
    );
  }

  /// The Postgres enum uses snake_case, the Dart enum does not.
  static TaskStatus statusFromDb(Object? value) => switch (value) {
        'in_progress' => TaskStatus.inProgress,
        'review' => TaskStatus.review,
        'done' => TaskStatus.done,
        _ => TaskStatus.todo,
      };

  /// The reverse mapping, used when writing.
  static String statusToDb(TaskStatus status) => switch (status) {
        TaskStatus.inProgress => 'in_progress',
        _ => status.name,
      };
}
