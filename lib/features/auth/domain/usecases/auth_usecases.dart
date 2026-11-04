import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';
import '../entities/github_device_code.dart';
import '../repositories/auth_repository.dart';

class SignInWithGithub {
  const SignInWithGithub(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthUser>> call() => _repository.signInWithGithub();
}

class StartGithubDeviceFlow {
  const StartGithubDeviceFlow(this._repository);

  final AuthRepository _repository;

  Future<Result<GithubDeviceCode>> call() => _repository.startGithubDeviceFlow();
}

class CompleteGithubDeviceFlow {
  const CompleteGithubDeviceFlow(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthUser>> call(
    GithubDeviceCode deviceCode, {
    void Function(bool pending)? onPending,
  }) =>
      _repository.completeGithubDeviceFlow(deviceCode, onPending: onPending);
}

class SignInWithEmail {
  const SignInWithEmail(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthUser>> call({
    required String email,
    required String password,
  }) =>
      _repository.signInWithEmail(email: email, password: password);
}

class RegisterWithEmail {
  const RegisterWithEmail(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthUser>> call({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _repository.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
}

class VerifyOtp {
  const VerifyOtp(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthUser>> call({required String email, required String otp}) =>
      _repository.verifyOtp(email: email, otp: otp);
}

class GetCurrentUser {
  const GetCurrentUser(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthUser?>> call() => _repository.currentUser();
}

class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.signOut();
}
