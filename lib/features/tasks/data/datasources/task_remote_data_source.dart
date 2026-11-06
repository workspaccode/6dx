import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/network/current_workspace.dart';
import '../../../../core/network/firebase_client.dart';
import '../../domain/entities/task.dart';
import '../models/task_model.dart';

/// Tasks of the current workspace, stored under `workspaces/{id}/tasks`.
class TaskRemoteDataSource {
  TaskRemoteDataSource(this._db, this._workspace);

  final FirebaseFirestoreResolver _db;
  final CurrentWorkspace _workspace;

  Future<List<TaskModel>> getTasks({String? projectId}) =>
      runFirestore('tasks.list', () async {
        final db = _db();
        final wsId = await _workspace.resolve();
        var query = db
            .collection('workspaces/$wsId/tasks')
            .orderBy('createdAt', descending: true);
        if (projectId != null) {
          query = query.where('projectId', isEqualTo: projectId);
        }
        final rows = await query.get();
        return rows.docs.map(_toModel).toList(growable: false);
      });

  /// Creates a task. The assignee is not settable from the app yet: the store
  /// keeps `assigneeId` (an account id the client cannot resolve from a
  /// display name), so [assigneeName] is accepted for API compatibility only.
  Future<TaskModel> createTask({
    required String title,
    String? description,
    String? projectId,
    String? priority,
    String? assigneeName,
  }) =>
      runFirestore('tasks.create', () async {
        final db = _db();
        final wsId = await _workspace.resolve();
        final now = FieldValue.serverTimestamp();
        final ref = db.collection('workspaces/$wsId/tasks').doc();
        await ref.set({
          'projectId': projectId,
          'sprintId': null,
          'key': null,
          'title': title,
          'description': description,
          'status': TaskStatus.todo.name,
          'priority': priority ?? TaskPriority.medium.name,
          'points': 0,
          'assigneeId': null,
          'label': null,
          'branch': null,
          'prNumber': null,
          'dueAt': null,
          'createdAt': now,
          'updatedAt': now,
        });
        return _toModel(await ref.get());
      });

  Future<TaskModel> updateStatus(String id, String status) =>
      runFirestore('tasks.update_status', () async {
        final db = _db();
        final ref = db.doc('workspaces/${await _workspace.resolve()}/tasks/$id');
        await ref.update({
          'status': statusToDb(statusFromDb(status)),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return _toModel(await ref.get());
      });

  Future<void> deleteTask(String id) =>
      runFirestore('tasks.delete', () async {
        await _db()
            .doc('workspaces/${await _workspace.resolve()}/tasks/$id')
            .delete();
      });

  TaskModel _toModel(DocumentSnapshot row) {
    final projectId = row.get('projectId') as String?;
    return TaskModel(
      id: row.id,
      title: row.get('title') as String? ?? '',
      description: row.get('description') as String?,
      status: statusFromDb(row.get('status')),
      priority: TaskPriority.values.firstWhere(
        (value) => value.name == row.get('priority'),
        orElse: () => TaskPriority.medium,
      ),
      projectId: projectId,
      projectName: null, // the workspace snapshot carries the join
      label: row.get('label') as String?,
      branchName: row.get('branch') as String?,
      prNumber: row.get('prNumber')?.toString(),
      dueDate: _toDateTime(row.get('dueAt')),
      createdAt: _toDateTime(row.get('createdAt')) ?? DateTime.now(),
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// The store keeps snake_case statuses, the Dart enum does not.
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
