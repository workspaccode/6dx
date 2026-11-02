import '../../../../core/utils/result.dart';
import '../entities/task.dart';

abstract interface class TaskRepository {
  Future<Result<List<Task>>> getTasks({String? projectId});

  Future<Result<Task>> getTask(String id);

  Future<Result<Task>> createTask({
    required String title,
    String? description,
    String? projectId,
    TaskPriority priority = TaskPriority.medium,
    String? assigneeName,
  });

  Future<Result<Task>> updateStatus(String id, TaskStatus status);

  Future<Result<void>> deleteTask(String id);
}
