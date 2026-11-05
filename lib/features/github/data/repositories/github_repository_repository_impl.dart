import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/github_installation.dart';
import '../../domain/entities/github_repository.dart';
import '../../domain/repositories/github_repository_repository.dart';
import '../datasources/github_api.dart';

class GithubRepositoryRepositoryImpl implements GithubRepositoryRepository {
  GithubRepositoryRepositoryImpl(this._api);

  final GithubApi _api;

  @override
  Future<Result<List<GithubRepository>>> listRepositories() => _guard(() async {
        final repos = await _api.listRepositories();
        return repos.map((e) => e.toEntity()).toList(growable: false);
      });

  @override
  Future<Result<GithubInstallation?>> installation() =>
      _guard<GithubInstallation?>(_api.installation);

  @override
  Future<Result<String>> installUrl() => _guard<String>(_api.installUrl);

  @override
  Future<Result<void>> disconnect() => _guard<void>(_api.disconnect);

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on UnauthorizedException {
      return const Result.failure(Failure.unauthorized());
    } on ServerException catch (e) {
      return Result.failure(Failure.server(e.message));
    } catch (e) {
      return Result.failure(Failure.unknown(e.toString()));
    }
  }
}
