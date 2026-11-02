import '../../../../core/utils/result.dart';
import '../entities/task.dart';
import '../repositories/task_repository.dart';

class GetTasks {
  const GetTasks(this._repository);

  final TaskRepository _repository;

  Future<Result<List<Task>>> call({String? projectId}) =>
      _repository.getTasks(projectId: projectId);
}

class GetTask {
  const GetTask(this._repository);

  final TaskRepository _repository;

  Future<Result<Task>> call(String id) => _repository.getTask(id);
}

class CreateTask {
  const CreateTask(this._repository);

  final TaskRepository _repository;

  Future<Result<Task>> call({
    required String title,
    String? description,
    String? projectId,
    TaskPriority priority = TaskPriority.medium,
    String? assigneeName,
  }) =>
      _repository.createTask(
        title: title,
        description: description,
        projectId: projectId,
        priority: priority,
        assigneeName: assigneeName,
      );
}

class UpdateTaskStatus {
  const UpdateTaskStatus(this._repository);

  final TaskRepository _repository;

  Future<Result<Task>> call(String id, TaskStatus status) =>
      _repository.updateStatus(id, status);
}

class DeleteTask {
  const DeleteTask(this._repository);

  final TaskRepository _repository;

  Future<Result<void>> call(String id) => _repository.deleteTask(id);
}
