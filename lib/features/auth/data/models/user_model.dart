import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/auth_user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String login,
    String? name,
    String? email,
    String? avatarUrl,
    String? accessToken,
    @Default(false) bool isGuest,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  AuthUser toEntity() => AuthUser(
        id: id,
        login: login,
        name: name,
        email: email,
        avatarUrl: avatarUrl,
        accessToken: accessToken,
        isGuest: isGuest,
      );

  factory UserModel.fromEntity(AuthUser user) => UserModel(
        id: user.id,
        login: user.login,
        name: user.name,
        email: user.email,
        avatarUrl: user.avatarUrl,
        accessToken: user.accessToken,
        isGuest: user.isGuest,
      );
}
