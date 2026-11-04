import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/current_workspace.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/task_remote_data_source.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/usecases/task_usecases.dart';

final taskRemoteDataSourceProvider = Provider<TaskRemoteDataSource>(
  (ref) => TaskRemoteDataSource(
    ref.watch(supabaseClientResolverProvider),
    ref.watch(currentWorkspaceProvider),
  ),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepositoryImpl(ref.watch(taskRemoteDataSourceProvider)),
);

final getTasksProvider = Provider<GetTasks>(
  (ref) => GetTasks(ref.watch(taskRepositoryProvider)),
);

final getTaskProvider = Provider<GetTask>(
  (ref) => GetTask(ref.watch(taskRepositoryProvider)),
);

final createTaskProvider = Provider<CreateTask>(
  (ref) => CreateTask(ref.watch(taskRepositoryProvider)),
);

final updateTaskStatusProvider = Provider<UpdateTaskStatus>(
  (ref) => UpdateTaskStatus(ref.watch(taskRepositoryProvider)),
);

final deleteTaskProvider = Provider<DeleteTask>(
  (ref) => DeleteTask(ref.watch(taskRepositoryProvider)),
);

class TasksNotifier extends AsyncNotifier<List<Task>> {
  String? _projectId;

  static const String _tag = 'Tasks';

  @override
  Future<List<Task>> build() async {
    // Reload whenever the signed-in account changes.
    ref.watch(authNotifierProvider.select((state) => state.value?.id));
    final result = await ref.watch(getTasksProvider).call(projectId: _projectId);
    _logResult('load', result);
    return result.dataOrNull ?? const [];
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final result = await ref.read(getTasksProvider).call(projectId: _projectId);
    _logResult('refresh', result);
    state = AsyncData(result.dataOrNull ?? const []);
  }

  Future<void> filterByProject(String? projectId) async {
    _projectId = projectId;
    state = const AsyncLoading();
    final result = await ref.read(getTasksProvider).call(projectId: projectId);
    _logResult('filter by project $projectId', result);
    state = AsyncData(result.dataOrNull ?? const []);
  }

  Future<bool> create({
    required String title,
    String? description,
    String? projectId,
    TaskPriority priority = TaskPriority.medium,
  }) async {
    final result = await ref.read(createTaskProvider).call(
          title: title,
          description: description,
          projectId: projectId,
          priority: priority,
        );
    _logResult('create "$title"', result);
    final created = result.dataOrNull;
    if (created == null) return false;
    state = AsyncData([created, ...?state.value]);
    return true;
  }

  Future<bool> updateStatus(String id, TaskStatus status) async {
    final result = await ref.read(updateTaskStatusProvider).call(id, status);
    _logResult('move $id to ${status.name}', result);
    final updated = result.dataOrNull;
    if (updated == null) return false;
    final current = [...?state.value];
    final index = current.indexWhere((t) => t.id == id);
    if (index != -1) {
      current[index] = updated;
      state = AsyncData(current);
    }
    return true;
  }

  Future<bool> remove(String id) async {
    final result = await ref.read(deleteTaskProvider).call(id);
    _logResult('delete $id', result);
    if (result.isFailure) return false;
    state = AsyncData(
      [...?state.value]..removeWhere((t) => t.id == id),
    );
    return true;
  }

  void _logResult<T>(String operation, Result<T> result) {
    final failure = result.failureOrNull;
    AppLogger.action(
      _tag,
      failure == null
          ? '$operation → ok'
          : '$operation → FAILED: ${failure.message}',
    );
  }
}

final tasksNotifierProvider =
    AsyncNotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

/// Tasks grouped by status — powers the Kanban board.
final tasksByStatusProvider = Provider<Map<TaskStatus, List<Task>>>((ref) {
  final tasks = ref.watch(tasksNotifierProvider).value ?? const [];
  final grouped = <TaskStatus, List<Task>>{
    for (final status in TaskStatus.values) status: <Task>[],
  };
  for (final task in tasks) {
    grouped[task.status]?.add(task);
  }
  return grouped;
});
