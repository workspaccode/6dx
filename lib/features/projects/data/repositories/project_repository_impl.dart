import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';
import '../datasources/project_remote_data_source.dart';
import '../models/project_model.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl(this._remote);

  final ProjectRemoteDataSource _remote;

  final List<ProjectModel> _cache = [];

  @override
  Future<Result<List<Project>>> getProjects() => _guard(() async {
        final projects = await _remote.getProjects();
        _cache
          ..clear()
          ..addAll(projects);
        return projects.map((e) => e.toEntity()).toList();
      });

  @override
  Future<Result<Project>> getProject(String id) => _guard(() async {
        final cached = _cache.where((p) => p.id == id);
        if (cached.isNotEmpty) return cached.first.toEntity();
        final projects = await _remote.getProjects();
        _cache
          ..clear()
          ..addAll(projects);
        return projects.firstWhere((p) => p.id == id).toEntity();
      });

  @override
  Future<Result<Project>> createProject({
    required String name,
    String? description,
    String? repositoryFullName,
  }) =>
      _guard(() async {
        final model = await _remote.createProject(
          name: name,
          description: description,
          repositoryFullName: repositoryFullName,
        );
        _cache.insert(0, model);
        return model.toEntity();
      });

  @override
  Future<Result<void>> archiveProject(String id) => _guard(() async {
        await _remote.archiveProject(id);
        final index = _cache.indexWhere((p) => p.id == id);
        if (index != -1) {
          _cache[index] = _cache[index].copyWith(isArchived: true);
        }
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on UnauthorizedException {
      return const Result.failure(Failure.unauthorized());
    } on NetworkException catch (e) {
      return Result.failure(Failure.network(e.message));
    } on ServerException catch (e) {
      return Result.failure(Failure.server(e.message));
    } catch (e) {
      return Result.failure(Failure.unknown(e.toString()));
    }
  }
}
