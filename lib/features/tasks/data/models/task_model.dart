import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/task.dart';

part 'task_model.freezed.dart';
part 'task_model.g.dart';

@freezed
abstract class TaskModel with _$TaskModel {
  const TaskModel._();

  const factory TaskModel({
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
  }) = _TaskModel;

  factory TaskModel.fromJson(Map<String, dynamic> json) =>
      _$TaskModelFromJson(json);

  Task toEntity() => Task(
        id: id,
        title: title,
        description: description,
        status: status,
        priority: priority,
        projectId: projectId,
        projectName: projectName,
        assigneeName: assigneeName,
        assigneeAvatar: assigneeAvatar,
        label: label,
        prNumber: prNumber,
        branchName: branchName,
        subtasksDone: subtasksDone,
        subtasksTotal: subtasksTotal,
        commentsCount: commentsCount,
        dueDate: dueDate,
        createdAt: createdAt,
      );

  factory TaskModel.fromEntity(Task task) => TaskModel(
        id: task.id,
        title: task.title,
        description: task.description,
        status: task.status,
        priority: task.priority,
        projectId: task.projectId,
        projectName: task.projectName,
        assigneeName: task.assigneeName,
        assigneeAvatar: task.assigneeAvatar,
        label: task.label,
        prNumber: task.prNumber,
        branchName: task.branchName,
        subtasksDone: task.subtasksDone,
        subtasksTotal: task.subtasksTotal,
        commentsCount: task.commentsCount,
        dueDate: task.dueDate,
        createdAt: task.createdAt,
      );
}
