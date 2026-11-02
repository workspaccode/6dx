import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';

enum TaskStatus { todo, inProgress, review, done }

enum TaskPriority { low, medium, high, urgent }

@freezed
abstract class Task with _$Task {
  const Task._();

  const factory Task({
    required String id,
    required String title,
    String? description,
    @Default(TaskStatus.todo) TaskStatus status,
    @Default(TaskPriority.medium) TaskPriority priority,
    String? projectId,
    String? projectName,
    String? assigneeName,
    String? assigneeAvatar,
    String? label,
    String? prNumber,
    String? branchName,
    @Default(0) int subtasksDone,
    @Default(0) int subtasksTotal,
    @Default(0) int commentsCount,
    DateTime? dueDate,
    DateTime? createdAt,
  }) = _Task;

  String get key =>
      projectName == null ? id : '${projectName!.toUpperCase()}-$id';

  bool get isOverdue {
    if (dueDate == null || status == TaskStatus.done) return false;
    return dueDate!.isBefore(DateTime.now());
  }
}
