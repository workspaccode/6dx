import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/project_remote_data_source.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';
import '../../domain/usecases/project_usecases.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

final projectRemoteDataSourceProvider = Provider<ProjectRemoteDataSource>(
  (ref) => ProjectRemoteDataSource(ref.watch(dioProvider)),
);

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepositoryImpl(ref.watch(projectRemoteDataSourceProvider)),
);

final getProjectsProvider = Provider<GetProjects>(
  (ref) => GetProjects(ref.watch(projectRepositoryProvider)),
);

final getProjectProvider = Provider<GetProject>(
  (ref) => GetProject(ref.watch(projectRepositoryProvider)),
);

final createProjectProvider = Provider<CreateProject>(
  (ref) => CreateProject(ref.watch(projectRepositoryProvider)),
);

final archiveProjectProvider = Provider<ArchiveProject>(
  (ref) => ArchiveProject(ref.watch(projectRepositoryProvider)),
);

/// All projects for the current workspace.
class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    final result = await ref.watch(getProjectsProvider).call();
    return result.dataOrNull ?? const [];
  }

  Future<bool> refresh() async {
    state = const AsyncLoading();
    final result = await ref.read(getProjectsProvider).call();
    if (result.isSuccess) {
      state = AsyncData(result.dataOrNull ?? const []);
      return true;
    }
    state = AsyncError(result.failureOrNull!, StackTrace.current);
    return false;
  }

  Future<bool> create({
    required String name,
    String? description,
    String? repositoryFullName,
  }) async {
    final result = await ref.read(createProjectProvider).call(
          name: name,
          description: description,
          repositoryFullName: repositoryFullName,
        );
    final created = result.dataOrNull;
    if (created == null) return false;
    state = AsyncData([created, ...?state.value]);
    return true;
  }
}

final projectsNotifierProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(ProjectsNotifier.new);

/// Filters applied on the projects screen.
enum ProjectFilter { all, active, archived }

class ProjectFilterNotifier extends Notifier<ProjectFilter> {
  @override
  ProjectFilter build() => ProjectFilter.all;

  void setFilter(ProjectFilter filter) => state = filter;
}

final projectFilterProvider =
    NotifierProvider<ProjectFilterNotifier, ProjectFilter>(
  ProjectFilterNotifier.new,
);

final filteredProjectsProvider = Provider<List<Project>>((ref) {
  final projects = ref.watch(projectsNotifierProvider).value ?? const [];
  final filter = ref.watch(projectFilterProvider);
  return switch (filter) {
    ProjectFilter.all => projects,
    ProjectFilter.active => projects.where((p) => !p.isArchived).toList(),
    ProjectFilter.archived => projects.where((p) => p.isArchived).toList(),
  };
});
