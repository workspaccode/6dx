import '../../../../core/utils/result.dart';
import '../entities/auth_user.dart';
import '../entities/github_device_code.dart';
import '../repositories/auth_repository.dart';

class StartGithubDeviceFlow {
  const StartGithubDeviceFlow(this._repository);

  final AuthRepository _repository;

  Future<Result<GithubDeviceCode>> call() =>
      _repository.startGithubDeviceFlow();
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
