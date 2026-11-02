// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProjectModel _$ProjectModelFromJson(Map<String, dynamic> json) =>
    _ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      colorHex: json['colorHex'] as String?,
      openTasks: (json['openTasks'] as num?)?.toInt() ?? 0,
      doneTasks: (json['doneTasks'] as num?)?.toInt() ?? 0,
      membersCount: (json['membersCount'] as num?)?.toInt() ?? 0,
      repositoryFullName: json['repositoryFullName'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$ProjectModelToJson(_ProjectModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'icon': instance.icon,
      'colorHex': instance.colorHex,
      'openTasks': instance.openTasks,
      'doneTasks': instance.doneTasks,
      'membersCount': instance.membersCount,
      'repositoryFullName': instance.repositoryFullName,
      'isArchived': instance.isArchived,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
