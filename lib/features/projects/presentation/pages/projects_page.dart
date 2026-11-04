import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/project.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../providers/project_providers.dart';

@RoutePage()
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectsState = ref.watch(projectsNotifierProvider);
    final filter = ref.watch(projectFilterProvider);
    final allProjects = ref.watch(projectsNotifierProvider).value ?? const [];
    final query = _searchController.text.trim().toLowerCase();
    final projects = query.isEmpty
        ? allProjects
        : allProjects
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                (p.repositoryFullName ?? '').toLowerCase().contains(query))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.projects),
        actions: [
          IconButton(
            tooltip: 'البحث',
            onPressed: () => context.push(AppRoutes.taskSearch),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () => context.push(AppRoutes.notifications),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'إعدادات المشروع',
            onPressed: () => context.push(AppRoutes.projectSettings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createProject),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.add),
        label: const Text('مشروع جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(projectsNotifierProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'ابحث في المشاريع',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'الكل',
                    count: allProjects.length,
                    selected: filter == ProjectFilter.all,
                    onTap: () => ref
                        .read(projectFilterProvider.notifier)
                        .setFilter(ProjectFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'أنا المالك',
                    count: allProjects.length,
                    selected: filter == ProjectFilter.active,
                    onTap: () => ref
                        .read(projectFilterProvider.notifier)
                        .setFilter(ProjectFilter.active),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'مشارك',
                    count: 0,
                    selected: filter == ProjectFilter.archived,
                    onTap: () => ref
                        .read(projectFilterProvider.notifier)
                        .setFilter(ProjectFilter.archived),
                  ),
                ],
              ),
            ),
            if (ref.watch(workspaceInvitesProvider).isNotEmpty) ...[
              const SizedBox(height: 12),
              const _PendingInviteCard(),
              const SizedBox(height: 8),
            ],
            if (projectsState.isLoading && projects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: AppLoadingView(),
              )
            else if (projects.isEmpty)
              const AppEmptyState(
                icon: Icons.folder_open_rounded,
                title: 'لا توجد مشاريع',
                message: 'أنشئ مشروعك الأول واربطه بمستودع GitHub.',
              )
            else
              ...projects.map((project) => _ProjectCard(project: project)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.6)
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Text(
          '$label · $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.accent : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _PendingInviteCard extends StatelessWidget {
  const _PendingInviteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لديك دعوة للانضمام إلى مشروع',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const StatusBadge(label: 'بصلاحية · مطوّر', color: AppColors.info),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('قبول الدعوة'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('رفض'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final hasRepository = project.repositoryFullName != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  project.icon ?? '📁',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasRepository
                          ? project.repositoryFullName!
                          : 'غير مربوط بمستودع',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (hasRepository)
                const StatusBadge(
                  label: 'متزامن',
                  color: AppColors.success,
                  icon: Icons.sync_rounded,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (project.description != null && project.description!.isNotEmpty) ...[
            Text(
              project.description!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: project.progress,
                    minHeight: 6,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${project.doneTasks} / ${project.totalTasks} مهمة',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.merge_type_rounded,
                  size: 14, color: AppColors.textDim),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '3 PR مفتوحة · 2 بانتظار مراجعتك',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.taskBoard),
                child: const Text('لوحة المهام'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
