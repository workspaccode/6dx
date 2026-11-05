import '../../../../core/utils/result.dart';
import '../entities/github_installation.dart';
import '../entities/github_repository.dart';

abstract interface class GithubRepositoryRepository {
  /// Repositories the GitHub App can see for this workspace — i.e. the ones the
  /// user (or the org admin) selected during installation.
  Future<Result<List<GithubRepository>>> listRepositories();

  /// The installation connected to the workspace, `null` when there is none.
  Future<Result<GithubInstallation?>> installation();

  /// The GitHub page where the user picks the repositories to expose.
  Future<Result<String>> installUrl();

  /// Forgets the installation for this workspace (it is **not** uninstalled on
  /// GitHub — the owner does that from their settings).
  Future<Result<void>> disconnect();
}
