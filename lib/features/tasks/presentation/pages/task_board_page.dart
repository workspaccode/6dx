import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/task.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../providers/task_providers.dart';
import '../widgets/task_view_switcher.dart';

@RoutePage()
class TaskBoardPage extends ConsumerWidget {
  const TaskBoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = ref.watch(tasksByStatusProvider);
    final isLoading = ref.watch(tasksNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المهام'),
        actions: [
          IconButton(
            tooltip: 'البحث',
            onPressed: () => context.push(AppRoutes.taskSearch),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            onPressed: () => ref.read(tasksNotifierProvider.notifier).refresh(),
            icon: const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: isLoading && grouped.isEmpty
          ? const AppLoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: const TaskViewSwitcher(current: 'لوحة'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'الـ Backlog',
                      onPressed: () => context.push(AppRoutes.backlog),
                      icon: const Icon(Icons.layers_outlined),
                    ),
                    IconButton(
                      tooltip: 'تخطيط الـ Sprint',
                      onPressed: () => context.push(AppRoutes.sprintPlan),
                      icon: const Icon(Icons.flag_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const _BoardHeader(),
                const SizedBox(height: 16),
                for (final status in TaskStatus.values) ...[
                  _ColumnSection(
                    status: status,
                    tasks: grouped[status] ?? const [],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newTask),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        icon: const Icon(Icons.add),
        label: const Text('مهمة جديدة'),
      ),
    );
  }

}

class _BoardHeader extends ConsumerWidget {
  const _BoardHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repos = ref.watch(workspaceRepositoriesProvider);
    final repoName = repos.isEmpty
        ? 'لا يوجد مستودع مربوط'
        : '${repos.first.fullName} · تمت المزامنة منذ دقيقة';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تطبيق المتجر',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                repoName,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
        const StatusBadge(
          label: 'Sprint 4 · 3 أيام متبقية',
          color: AppColors.accent,
          dense: true,
        ),
      ],
    );
  }
}

class _ColumnSection extends ConsumerWidget {
  const _ColumnSection({required this.status, required this.tasks});

  final TaskStatus status;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              statusLabel(status),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            Text('${tasks.length}', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Text(
              'لا توجد مهام هنا. اسحب مهمة إلى هذا العمود أو أنشئ واحدة جديدة.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ...tasks.map((task) => _TaskCard(task: task)),
      ],
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push(AppRoutes.taskDetailPath(task.id)),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(task.key, style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                StatusBadge(
                  label: priorityLabel(task.priority),
                  color: priorityColor(task.priority),
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(task.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (task.branchName != null)
                  MonoChip(label: task.branchName!, icon: Icons.commit),
                if (task.prNumber != null)
                  MonoChip(label: 'PR #${task.prNumber}', icon: Icons.merge_type),
                if (task.label != null)
                  StatusBadge(
                    label: task.label!,
                    color: statusColor(task.status),
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Avatar(
                  name: task.assigneeName ?? '؟',
                  color: statusColor(task.status),
                ),
                const SizedBox(width: 8),
                Text(
                  task.assigneeName ?? 'غير معيّن',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (task.dueDate != null)
                  Text(
                    _formatDate(task.dueDate!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: task.isOverdue
                              ? AppColors.danger
                              : AppColors.textDim,
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initials = name.isEmpty ? '؟' : name.characters.take(2).toString();
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        initials,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

Color statusColor(TaskStatus status) => switch (status) {
      TaskStatus.todo => AppColors.textMuted,
      TaskStatus.inProgress => AppColors.info,
      TaskStatus.review => AppColors.warning,
      TaskStatus.done => AppColors.success,
    };

String statusLabel(TaskStatus status) => switch (status) {
      TaskStatus.todo => 'قيد الانتظار',
      TaskStatus.inProgress => 'قيد التنفيذ',
      TaskStatus.review => 'مراجعة',
      TaskStatus.done => 'مكتمل',
    };

Color priorityColor(TaskPriority priority) => switch (priority) {
      TaskPriority.low => AppColors.textDim,
      TaskPriority.medium => AppColors.info,
      TaskPriority.high => AppColors.warning,
      TaskPriority.urgent => AppColors.danger,
    };

String priorityLabel(TaskPriority priority) => switch (priority) {
      TaskPriority.low => 'منخفضة',
      TaskPriority.medium => 'متوسطة',
      TaskPriority.high => 'عالية',
      TaskPriority.urgent => 'عاجلة',
    };
