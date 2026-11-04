import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
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

/// The user's GitHub repositories, for the project ↔ repository picker.
///
/// `retry` is disabled on purpose: a failing request must surface as an error
/// state right away. With Riverpod's default retry the page would look like an
/// endless loader while GitHub was hit ten more times.
final githubRepositoriesProvider = FutureProvider<List<GithubRepository>>(
  (ref) async {
    // Reload whenever the signed-in account changes.
    ref.watch(authNotifierProvider.select((state) => state.value?.id));
    final result =
        await ref.watch(githubRepositoryRepositoryProvider).listRepositories();
    final repos = result.dataOrNull;
    if (repos == null) {
      // Never show "no repositories" when the request actually failed.
      throw Exception(
        result.failureOrNull?.message ?? 'تعذّر تحميل المستودعات من GitHub.',
      );
    }
    return repos;
  },
  retry: (retryCount, error) => null,
);

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
