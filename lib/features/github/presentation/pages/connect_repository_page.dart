import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/entities/github_installation.dart';
import '../providers/github_providers.dart';

/// Picks the GitHub repository a project is linked to.
///
/// Access goes through a GitHub App: the user installs it on the repositories
/// they choose, so the app never receives a credential for the whole account.
/// `Navigator.pop(repo.fullName)` hands the choice back to the caller.
@RoutePage()
class ConnectRepositoryPage extends ConsumerStatefulWidget {
  const ConnectRepositoryPage({super.key});

  @override
  ConsumerState<ConnectRepositoryPage> createState() =>
      _ConnectRepositoryPageState();
}

class _ConnectRepositoryPageState extends ConsumerState<ConnectRepositoryPage> {
  static const String _tag = 'GitHubApp';

  bool _openingInstall = false;

  Future<void> _openInstallPage() async {
    setState(() => _openingInstall = true);
    final result =
        await ref.read(githubRepositoryRepositoryProvider).installUrl();
    if (!mounted) return;
    setState(() => _openingInstall = false);

    final url = result.dataOrNull;
    if (url == null) {
      final reason = result.failureOrNull?.message ?? 'تعذّر بدء التثبيت.';
      AppLogger.action(_tag, 'install url failed: $reason');
      _showSnack(reason);
      return;
    }

    AppLogger.action(_tag, 'opening the installation page');
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showSnack('تعذّر فتح المتصفح — افتح الرابط يدويًا: $url');
    }
  }

  void _refresh() {
    AppLogger.action(_tag, 'refresh requested by the user');
    ref.invalidate(githubInstallationProvider);
    ref.invalidate(githubRepositoriesProvider);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final installationState = ref.watch(githubInstallationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ربط مستودع GitHub'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: installationState.isLoading
          ? const AppLoadingView()
          : installationState.hasError
              ? AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'تعذّر قراءة حالة تطبيق GitHub',
                  message: '${installationState.error}'.replaceFirst(
                    'Exception: ',
                    '',
                  ),
                )
              : installationState.value == null
                  ? _InstallCard(
                      busy: _openingInstall,
                      onInstall: _openInstallPage,
                      onRefresh: _refresh,
                    )
                  : _RepositoryPicker(
                      installation: installationState.value!,
                      onRefresh: _refresh,
                    ),
    );
  }
}

/// Shown while the workspace has no installation yet.
class _InstallCard extends StatelessWidget {
  const _InstallCard({
    required this.busy,
    required this.onInstall,
    required this.onRefresh,
  });

  final bool busy;
  final VoidCallback onInstall;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'اربط تطبيق 6DX بحساب GitHub',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'التطبيق بياخد وصول للمستودعات اللي تختارها بس — مش كل '
                'مستودعاتك. تقدر تغيّر الاختيار أو تلغي التثبيت في أي وقت من '
                'إعدادات GitHub.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : onInstall,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('تثبيت التطبيق على GitHub'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('ثبّتته؟ حدّث الحالة'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The repositories the installation can see.
class _RepositoryPicker extends ConsumerWidget {
  const _RepositoryPicker({
    required this.installation,
    required this.onRefresh,
  });

  final GithubInstallation installation;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reposState = ref.watch(githubRepositoriesProvider);
    final repos = ref.watch(filteredGithubRepositoriesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              const Icon(Icons.link_rounded, size: 16, color: AppColors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'مرتبط بـ ${installation.displayName} · '
                  '${reposState.value?.length ?? 0} مستودع متاح',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
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
              : reposState.hasError
                  ? AppEmptyState(
                      icon: Icons.error_outline_rounded,
                      title: 'تعذّر تحميل المستودعات',
                      message: '${reposState.error}'.replaceFirst(
                        'Exception: ',
                        '',
                      ),
                    )
                  : repos.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.code_off_rounded,
                          title: 'لا توجد مستودعات',
                          message: 'عدّل اختيار المستودعات من إعدادات تثبيت '
                              'التطبيق على GitHub ثم اضغط تحديث.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: repos.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star_border_rounded,
                                      size: 16),
                                  Text(
                                    '${repo.stargazersCount}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                              // Hand the choice back to the create-project
                              // form.
                              onTap: () =>
                                  Navigator.of(context).pop(repo.fullName),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
