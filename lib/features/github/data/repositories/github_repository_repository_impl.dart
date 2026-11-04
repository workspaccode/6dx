import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/github_repository.dart';
import '../../domain/repositories/github_repository_repository.dart';
import '../datasources/github_api.dart';

class GithubRepositoryRepositoryImpl implements GithubRepositoryRepository {
  GithubRepositoryRepositoryImpl(this._api);

  final GithubApi _api;

  @override
  Future<Result<List<GithubRepository>>> listRepositories() => _guard(() async {
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
      return Result.failure(Failure.network(_describeGithubError(e)));
    } on ServerException catch (e) {
      return Result.failure(Failure.server(e.message));
    } catch (e) {
      return Result.failure(Failure.unknown(e.toString()));
    }
  }

  /// GitHub answers `401` when the app has no (or an expired) provider token.
  static String _describeGithubError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'لمنح التطبيق صلاحية قراءة مستودعاتك، سجّل الخروج ثم ادخل مرة '
          'أخرى بحساب GitHub.';
    }
    if (status == 404) {
      return 'حساب GitHub غير موجود أو المستودع غير متاح.';
    }
    return error.message ?? 'تعذّر الاتصال بـ GitHub.';
  }
}
