import '../../../../core/utils/result.dart';
import '../entities/project.dart';

abstract interface class ProjectRepository {
  Future<Result<List<Project>>> getProjects();

  Future<Result<Project>> getProject(String id);

  Future<Result<Project>> createProject({
    required String name,
    String? description,
    String? repositoryFullName,
  });

  Future<Result<void>> archiveProject(String id);
}
