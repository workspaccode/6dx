import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/task.dart';
import '../providers/task_providers.dart';
import 'task_board_page.dart';

@RoutePage()
class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksNotifierProvider).value ?? const [];
    final task = tasks.where((t) => t.id == taskId).firstOrNull;

    if (task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المهمة')),
        body: const Center(child: Text('المهمة غير موجودة')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(task.key),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(tasksNotifierProvider.notifier).remove(task.id),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              StatusBadge(
                label: statusLabel(task.status),
                color: statusColor(task.status),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: priorityLabel(task.priority),
                color: priorityColor(task.priority),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(task.title, style: Theme.of(context).textTheme.headlineMedium),
          if (task.description != null) ...[
            const SizedBox(height: 12),
            Text(
              task.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          _InfoRow(
            icon: Icons.person_outline,
            label: 'المسؤول',
            value: task.assigneeName ?? '—',
          ),
          const _InfoRow(
            icon: Icons.person_search_outlined,
            label: 'المراجِع',
            value: 'سارة',
          ),
          const _InfoRow(
            icon: Icons.event_outlined,
            label: 'التسليم',
            value: 'غدًا · 5 نقاط',
          ),
          const SizedBox(height: 24),
          Text('على GitHub', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _GithubCard(
            repository: task.projectName ?? 'acme/store-mobile',
            issueNumber: '57',
            branch: task.branchName ?? 'feat/MOB-24-otp',
            prNumber: task.prNumber,
          ),
          const SizedBox(height: 24),
          Text('النشاط', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          const _ActivityItem(
            icon: Icons.auto_awesome,
            title: 'نُقلت المهمة تلقائيًا إلى «مراجعة»',
            subtitle: 'منذ 40 دقيقة · آليًا',
            color: AppColors.info,
          ),
          const _ActivityItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'علّقت: هل عدد المحاولات محدود قبل قفل الكود مؤقتًا؟',
            subtitle: 'منذ 15 دقيقة · سارة',
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              hintText: 'اكتب تعليقًا',
              suffixIcon: Icon(Icons.send_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Text('تغيير الحالة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in TaskStatus.values)
                ChoiceChip(
                  label: Text(statusLabel(status)),
                  selected: status == task.status,
                  onSelected: (_) => ref
                      .read(tasksNotifierProvider.notifier)
                      .updateStatus(task.id, status),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textDim),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _GithubCard extends StatelessWidget {
  const _GithubCard({
    required this.repository,
    required this.issueNumber,
    required this.branch,
    this.prNumber,
  });

  final String repository;
  final String issueNumber;
  final String branch;
  final String? prNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.code_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  repository,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Issue #$issueNumber · مفتوح',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          MonoChip(label: branch, icon: Icons.commit),
          const SizedBox(height: 12),
          if (prNumber != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PR #$prNumber · بانتظار المراجعة',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const StatusBadge(
                  label: '4/4 فحوصات',
                  color: AppColors.success,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                MonoChip(label: 'build ✓'),
                SizedBox(width: 6),
                MonoChip(label: 'tests ✓'),
                SizedBox(width: 6),
                MonoChip(label: 'lint ✓'),
                Spacer(),
                Text(
                  '+312 −48',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
