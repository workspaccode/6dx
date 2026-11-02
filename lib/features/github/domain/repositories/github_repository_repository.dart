import '../../../../core/utils/result.dart';
import '../entities/github_repository.dart';

abstract interface class GithubRepositoryRepository {
  Future<Result<List<GithubRepository>>> listRepositories();

  Future<Result<List<GithubRepository>>> searchRepositories(String query);
}
