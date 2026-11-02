import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/github_repository.dart';
import '../../domain/repositories/github_repository_repository.dart';
import '../datasources/github_api.dart';
import '../models/github_repository_model.dart';

class GithubRepositoryRepositoryImpl implements GithubRepositoryRepository {
  GithubRepositoryRepositoryImpl(this._api);

  final GithubApi _api;

  @override
  Future<Result<List<GithubRepository>>> listRepositories() => _guard(() async {
        if (AppConfig.useMockData) {
          return _seed.map((e) => e.toEntity()).toList();
        }
        final repos = await _api.listRepositories();
        return repos.map((e) => e.toEntity()).toList();
      });

  @override
  Future<Result<List<GithubRepository>>> searchRepositories(String query) =>
      _guard(() async {
        final repos = await _api.listRepositories();
        final filtered = repos
            .where(
              (r) => r.fullName.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
        return filtered.map((e) => e.toEntity()).toList();
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on DioException catch (e) {
      return Result.failure(Failure.network(e.message ?? 'Network error'));
    } on ServerException catch (e) {
      return Result.failure(Failure.server(e.message));
    } catch (e) {
      return Result.failure(Failure.unknown(e.toString()));
    }
  }

  static final List<GithubRepositoryModel> _seed = [
    const GithubRepositoryModel(
      id: '1',
      name: '6dx',
      fullName: 'sixdx/6dx',
      description: 'Flutter app for managing projects, tasks and sprints',
      htmlUrl: 'https://github.com/sixdx/6dx',
      language: 'Dart',
      stargazersCount: 128,
      openIssuesCount: 17,
      defaultBranch: 'main',
    ),
    const GithubRepositoryModel(
      id: '2',
      name: '6dx-api',
      fullName: 'sixdx/6dx-api',
      description: 'REST API powering the 6DX platform',
      htmlUrl: 'https://github.com/sixdx/6dx-api',
      language: 'TypeScript',
      stargazersCount: 42,
      openIssuesCount: 6,
      defaultBranch: 'main',
    ),
    const GithubRepositoryModel(
      id: '3',
      name: 'design-system',
      fullName: 'sixdx/design-system',
      description: 'Shared design tokens and components',
      htmlUrl: 'https://github.com/sixdx/design-system',
      language: 'CSS',
      stargazersCount: 19,
      openIssuesCount: 3,
      defaultBranch: 'main',
    ),
  ];
}
