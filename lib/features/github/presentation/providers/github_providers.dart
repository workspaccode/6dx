import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/github_api.dart';
import '../../data/repositories/github_repository_repository_impl.dart';
import '../../domain/entities/github_repository.dart';
import '../../domain/repositories/github_repository_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

final githubApiProvider = Provider<GithubApi>(
  (ref) => GithubApi(ref.watch(githubDioProvider)),
);

final githubRepositoryRepositoryProvider = Provider<GithubRepositoryRepository>(
  (ref) => GithubRepositoryRepositoryImpl(ref.watch(githubApiProvider)),
);

final githubRepositoriesProvider = FutureProvider<List<GithubRepository>>((ref) async {
  final result =
      await ref.watch(githubRepositoryRepositoryProvider).listRepositories();
  return result.dataOrNull ?? const [];
});

/// Search term used by the repository picker.
class GithubSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final githubSearchProvider =
    NotifierProvider<GithubSearchNotifier, String>(GithubSearchNotifier.new);

final filteredGithubRepositoriesProvider = Provider<List<GithubRepository>>((ref) {
  final repos = ref.watch(githubRepositoriesProvider).value ?? const [];
  final query = ref.watch(githubSearchProvider).trim().toLowerCase();
  if (query.isEmpty) return repos;
  return repos
      .where((r) => r.fullName.toLowerCase().contains(query))
      .toList(growable: false);
});
