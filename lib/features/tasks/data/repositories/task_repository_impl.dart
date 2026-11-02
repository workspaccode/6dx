import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/demo/demo_data.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_remote_data_source.dart';
import '../models/task_model.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._remote);

  final TaskRemoteDataSource _remote;

  final List<TaskModel> _cache = List.of(DemoData.tasks);

  @override
  Future<Result<List<Task>>> getTasks({String? projectId}) => _guard(() async {
        if (AppConfig.useMockData) {
          final filtered = projectId == null
              ? _cache
              : _cache.where((t) => t.projectId == projectId).toList();
          return filtered.map((e) => e.toEntity()).toList();
        }
        final tasks = await _remote.getTasks(projectId: projectId);
        _cache
          ..clear()
          ..addAll(tasks);
        return tasks.map((e) => e.toEntity()).toList();
      });

  @override
  Future<Result<Task>> getTask(String id) => _guard(() async {
        final found = _cache.firstWhere(
          (t) => t.id == id,
          orElse: () => _cache.first,
        );
        return found.toEntity();
      });

  @override
  Future<Result<Task>> createTask({
    required String title,
    String? description,
    String? projectId,
    TaskPriority priority = TaskPriority.medium,
    String? assigneeName,
  }) =>
      _guard(() async {
        final model = AppConfig.useMockData
            ? TaskModel(
                id: 't-${DateTime.now().millisecondsSinceEpoch}',
                title: title,
                description: description,
                status: TaskStatus.todo,
                priority: priority,
                projectId: projectId,
                projectName: '6DX Mobile',
                assigneeName: assigneeName ?? 'Sami',
                createdAt: DateTime.now(),
              )
            : await _remote.createTask(
                title: title,
                description: description,
                projectId: projectId,
                priority: priority.name,
                assigneeName: assigneeName,
              );
        _cache.insert(0, model);
        return model.toEntity();
      });

  @override
  Future<Result<Task>> updateStatus(String id, TaskStatus status) =>
      _guard(() async {
        final index = _cache.indexWhere((t) => t.id == id);
        if (index == -1) {
          throw const ServerException('Task not found');
        }
        final updated = _cache[index].copyWith(status: status);
        _cache[index] = updated;
        return updated.toEntity();
      });

  @override
  Future<Result<void>> deleteTask(String id) => _guard(() async {
        _cache.removeWhere((t) => t.id == id);
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
