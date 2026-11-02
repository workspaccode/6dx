import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../providers/github_providers.dart';

@RoutePage()
class ConnectRepositoryPage extends ConsumerStatefulWidget {
  const ConnectRepositoryPage({super.key});

  @override
  ConsumerState<ConnectRepositoryPage> createState() =>
      _ConnectRepositoryPageState();
}

class _ConnectRepositoryPageState extends ConsumerState<ConnectRepositoryPage> {
  @override
  Widget build(BuildContext context) {
    final reposState = ref.watch(githubRepositoriesProvider);
    final repos = ref.watch(filteredGithubRepositoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ربط مستودع GitHub')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              onChanged: (value) =>
                  ref.read(githubSearchProvider.notifier).setQuery(value),
              decoration: const InputDecoration(
                hintText: 'ابحث عن مستودع',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: reposState.isLoading
                ? const AppLoadingView()
                : repos.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.code_off_rounded,
                        title: 'لا توجد مستودعات',
                        message: 'جرّب اسمًا آخر أو اربط حساب GitHub.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: repos.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final repo = repos[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.code_rounded,
                              color: AppColors.textMuted,
                            ),
                            title: Text(repo.fullName),
                            subtitle: Text(
                              repo.description ?? repo.language ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (repo.language != null)
                                  Text(
                                    repo.language!,
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                const SizedBox(width: 8),
                                const Icon(Icons.star_border_rounded, size: 16),
                                Text(
                                  '${repo.stargazersCount}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                            onTap: () => Navigator.of(context).pop(),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
