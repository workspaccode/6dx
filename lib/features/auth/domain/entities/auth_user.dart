import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

@freezed
abstract class AuthUser with _$AuthUser {
  const AuthUser._();

  const factory AuthUser({
    required String id,
    required String login,
    String? name,
    String? email,
    String? avatarUrl,
    String? accessToken,
    @Default(false) bool isGuest,
  }) = _AuthUser;

  String get displayName => (name != null && name!.isNotEmpty) ? name! : login;
}
