import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';

@freezed
abstract class Project with _$Project {
  const Project._();

  const factory Project({
    required String id,
    required String name,
    String? description,
    String? icon,
    String? colorHex,
    @Default(0) int openTasks,
    @Default(0) int doneTasks,
    @Default(0) int membersCount,
    String? repositoryFullName,
    @Default(false) bool isArchived,
    DateTime? updatedAt,
  }) = _Project;

  int get totalTasks => openTasks + doneTasks;

  double get progress => totalTasks == 0 ? 0 : doneTasks / totalTasks;
}
