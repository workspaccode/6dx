import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  Future<Result<AuthUser>> signInWithGithub({required String code});

  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AuthUser>> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<Result<AuthUser>> verifyOtp({required String email, required String otp});

  Future<Result<AuthUser?>> currentUser();

  Future<Result<void>> signOut();
}
