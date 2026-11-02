// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TaskModel _$TaskModelFromJson(Map<String, dynamic> json) => _TaskModel(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  status:
      $enumDecodeNullable(_$TaskStatusEnumMap, json['status']) ??
      TaskStatus.todo,
  priority:
      $enumDecodeNullable(_$TaskPriorityEnumMap, json['priority']) ??
      TaskPriority.medium,
  projectId: json['projectId'] as String?,
  projectName: json['projectName'] as String?,
  assigneeName: json['assigneeName'] as String?,
  assigneeAvatar: json['assigneeAvatar'] as String?,
  label: json['label'] as String?,
  prNumber: json['prNumber'] as String?,
  branchName: json['branchName'] as String?,
  subtasksDone: (json['subtasksDone'] as num?)?.toInt() ?? 0,
  subtasksTotal: (json['subtasksTotal'] as num?)?.toInt() ?? 0,
  commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$TaskModelToJson(_TaskModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'status': _$TaskStatusEnumMap[instance.status]!,
      'priority': _$TaskPriorityEnumMap[instance.priority]!,
      'projectId': instance.projectId,
      'projectName': instance.projectName,
      'assigneeName': instance.assigneeName,
      'assigneeAvatar': instance.assigneeAvatar,
      'label': instance.label,
      'prNumber': instance.prNumber,
      'branchName': instance.branchName,
      'subtasksDone': instance.subtasksDone,
      'subtasksTotal': instance.subtasksTotal,
      'commentsCount': instance.commentsCount,
      'dueDate': instance.dueDate?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$TaskStatusEnumMap = {
  TaskStatus.todo: 'todo',
  TaskStatus.inProgress: 'inProgress',
  TaskStatus.review: 'review',
  TaskStatus.done: 'done',
};

const _$TaskPriorityEnumMap = {
  TaskPriority.low: 'low',
  TaskPriority.medium: 'medium',
  TaskPriority.high: 'high',
  TaskPriority.urgent: 'urgent',
};
