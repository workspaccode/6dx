import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/demo/demo_data.dart';
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

  final List<ProjectModel> _cache = List.of(DemoData.projects);

  @override
  Future<Result<List<Project>>> getProjects() => _guard(() async {
        if (AppConfig.useMockData) {
          return _cache.map((e) => e.toEntity()).toList();
        }
        final projects = await _remote.getProjects();
        _cache
          ..clear()
          ..addAll(projects);
        return projects.map((e) => e.toEntity()).toList();
      });

  @override
  Future<Result<Project>> getProject(String id) => _guard(() async {
        if (AppConfig.useMockData) {
          final found = _cache.firstWhere(
            (p) => p.id == id,
            orElse: () => _cache.first,
          );
          return found.toEntity();
        }
        final project = await _remote.getProjects();
        final found = project.firstWhere((p) => p.id == id);
        return found.toEntity();
      });

  @override
  Future<Result<Project>> createProject({
    required String name,
    String? description,
    String? repositoryFullName,
  }) =>
      _guard(() async {
        final model = AppConfig.useMockData
            ? ProjectModel(
                id: 'p-${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                description: description,
                repositoryFullName: repositoryFullName,
                icon: '🚀',
                colorHex: '#B8F25A',
                updatedAt: DateTime.now(),
              )
            : await _remote.createProject(
                name: name,
                description: description,
                repositoryFullName: repositoryFullName,
              );
        _cache.insert(0, model);
        return model.toEntity();
      });

  @override
  Future<Result<void>> archiveProject(String id) => _guard(() async {
        if (AppConfig.useMockData) {
          _cache.removeWhere((p) => p.id == id);
        } else {
          await _remote.archiveProject(id);
          _cache.removeWhere((p) => p.id == id);
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
    } on DioException catch (e) {
      return Result.failure(Failure.network(e.message ?? 'Network error'));
    } catch (e) {
      return Result.failure(Failure.unknown(e.toString()));
    }
  }

}
