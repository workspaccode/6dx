import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/project.dart';

part 'project_model.freezed.dart';
part 'project_model.g.dart';

@freezed
abstract class ProjectModel with _$ProjectModel {
  const ProjectModel._();

  const factory ProjectModel({
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
  }) = _ProjectModel;

  factory ProjectModel.fromJson(Map<String, dynamic> json) =>
      _$ProjectModelFromJson(json);

  Project toEntity() => Project(
        id: id,
        name: name,
        description: description,
        icon: icon,
        colorHex: colorHex,
        openTasks: openTasks,
        doneTasks: doneTasks,
        membersCount: membersCount,
        repositoryFullName: repositoryFullName,
        isArchived: isArchived,
        updatedAt: updatedAt,
      );

  factory ProjectModel.fromEntity(Project project) => ProjectModel(
        id: project.id,
        name: project.name,
        description: project.description,
        icon: project.icon,
        colorHex: project.colorHex,
        openTasks: project.openTasks,
        doneTasks: project.doneTasks,
        membersCount: project.membersCount,
        repositoryFullName: project.repositoryFullName,
        isArchived: project.isArchived,
        updatedAt: project.updatedAt,
      );
}
