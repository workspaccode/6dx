// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
  id: json['id'] as String,
  login: json['login'] as String,
  name: json['name'] as String?,
  email: json['email'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  accessToken: json['accessToken'] as String?,
  isGuest: json['isGuest'] as bool? ?? false,
);

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'login': instance.login,
      'name': instance.name,
      'email': instance.email,
      'avatarUrl': instance.avatarUrl,
      'accessToken': instance.accessToken,
      'isGuest': instance.isGuest,
    };
