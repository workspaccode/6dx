import '../../../../core/utils/result.dart';
import '../entities/project.dart';
import '../repositories/project_repository.dart';

class GetProjects {
  const GetProjects(this._repository);

  final ProjectRepository _repository;

  Future<Result<List<Project>>> call() => _repository.getProjects();
}

class GetProject {
  const GetProject(this._repository);

  final ProjectRepository _repository;

  Future<Result<Project>> call(String id) => _repository.getProject(id);
}

class CreateProject {
  const CreateProject(this._repository);

  final ProjectRepository _repository;

  Future<Result<Project>> call({
    required String name,
    String? description,
    String? repositoryFullName,
  }) =>
      _repository.createProject(
        name: name,
        description: description,
        repositoryFullName: repositoryFullName,
      );
}

class ArchiveProject {
  const ArchiveProject(this._repository);

  final ProjectRepository _repository;

  Future<Result<void>> call(String id) => _repository.archiveProject(id);
}
