import '../../../../core/network/api_client.dart';
import '../../../../core/network/current_workspace.dart';
import '../../domain/entities/task.dart';
import '../models/task_model.dart';

/// Tasks of the current workspace — `/v1/tasks`.
class TaskRemoteDataSource {
  TaskRemoteDataSource(this._api, this._workspace);

  final ApiClient _api;
  final CurrentWorkspace _workspace;

  Future<List<TaskModel>> getTasks({String? projectId}) =>
      _api.run('tasks.list', () async {
        await _workspace.resolve();
        final payload = await _api.get(
          '/v1/tasks',
          query: projectId == null ? null : {'project_id': projectId},
        );
        final rows = payload['tasks'];
        if (rows is! List) return const <TaskModel>[];
        return rows
            .whereType<Map>()
            .map((row) => _toModel(row))
            .toList(growable: false);
      });

  /// Creates a task. The assignee is not settable from the app yet.
  Future<TaskModel> createTask({
    required String title,
    String? description,
    String? projectId,
    String? priority,
    String? assigneeUid,
    int? points,
    DateTime? dueDate,
  }) =>
      _api.run('tasks.create', () async {
        await _workspace.resolve();
        final payload = await _api.post('/v1/tasks', body: {
          'title': title,
          if (description != null) 'description': description,
          if (projectId != null) 'project_id': projectId,
          if (priority != null) 'priority': priority,
          if (assigneeUid != null) 'assignee_uid': assigneeUid,
          if (points != null) 'points': points,
          if (dueDate != null)
            'due_at': '${dueDate.year.toString().padLeft(4, '0')}-'
                '${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
        });
        final task = payload['task'];
        if (task is! Map) throw ArgumentError('unexpected response shape');
        return _toModel(task);
      });

  Future<TaskModel> updateStatus(String id, String status) =>
      _api.run('tasks.update_status', () async {
        await _workspace.resolve();
        final payload = await _api.patch('/v1/tasks/$id/status',
            body: {'status': statusToDb(statusFromDb(status))});
        final task = payload['task'];
        if (task is! Map) throw ArgumentError('unexpected response shape');
        return _toModel(task);
      });

  Future<void> deleteTask(String id) => _api.run('tasks.delete', () async {
        await _workspace.resolve();
        await _api.delete('/v1/tasks/$id');
      });

  TaskModel _toModel(Map<dynamic, dynamic> row) => TaskModel(
        id: '${row['id']}',
        title: '${row['title']}',
        description: row['description'] as String?,
        status: statusFromDb(row['status']),
        priority: TaskPriority.values.firstWhere(
          (value) => value.name == row['priority'],
          orElse: () => TaskPriority.medium,
        ),
        projectId: row['project_id'] as String?,
        projectName: row['project_name'] as String?,
        assigneeName: row['assignee_name'] as String?,
        assigneeUid: row['assignee_uid'] as String?,
        stateId: row['state_id'] as String?,
        label: row['label'] as String?,
        branchName: row['branch'] as String?,
        prNumber: row['pr_number']?.toString(),
        dueDate: DateTime.tryParse('${row['due_at']}'),
        createdAt: DateTime.tryParse('${row['created_at']}'),
      );

  /// The backend keeps snake_case statuses, the Dart enum does not.
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
