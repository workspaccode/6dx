import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../domain/entities/task.dart';
import '../../../../core/utils/feedback.dart';
import '../../../workspace/domain/entities/workspace_snapshot.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../providers/task_providers.dart';
import 'task_board_page.dart';

class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksState = ref.watch(tasksNotifierProvider);
    final tasks = tasksState.value ?? const <Task>[];

    if (tasksState.isLoading && tasks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المهمة')),
        body: const AppLoadingView(),
      );
    }

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
            tooltip: 'حذف المهمة',
            onPressed: () => _delete(context, ref, task),
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
          _InfoRow(
            icon: Icons.event_outlined,
            label: 'التسليم',
            value: task.dueDate == null
                ? '—'
                : '${task.dueDate!.year}-${task.dueDate!.month.toString().padLeft(2, '0')}-${task.dueDate!.day.toString().padLeft(2, '0')}',
          ),
          // GitHub: only what is really linked (a branch, a PR).
          if (task.branchName != null || task.prNumber != null) ...[
            const SizedBox(height: 24),
            Text('على GitHub', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            InkWell(
              onTap: task.prNumber == null
                  ? null
                  : () => context.push(AppRoutes.prDetailPath(task.prNumber!)),
              child: _GithubCard(
                branch: task.branchName,
                pr: task.prNumber == null
                    ? null
                    : ref.watch(pullRequestProvider(int.tryParse(task.prNumber!) ?? -1)),
                prNumber: task.prNumber,
              ),
            ),
          ],
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
                  onSelected: (_) => runAction(
                    context,
                    () => ref.read(tasksNotifierProvider.notifier).updateStatus(task.id, status),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.subtasksPath(task.id),
                  ),
                  icon: const Icon(Icons.checklist_rounded),
                  label: const Text('المهام الفرعية'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.commentsPath(task.id),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('التعليقات'),
                ),
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
  const _GithubCard({required this.branch, required this.pr, required this.prNumber});

  final String? branch;

  /// The PR from the snapshot (null when it is not loaded / not found).
  final PullRequest? pr;
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
          if (pr?.repository != null) ...[
            Text(pr!.repository!, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
          ],
          if (branch != null) MonoChip(label: branch!, icon: Icons.commit),
          if (prNumber != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PR #$prNumber${pr == null ? '' : ' · ${pr!.state}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (pr != null && pr!.checks.isNotEmpty)
                  StatusBadge(
                    label: '${pr!.checks.where((c) => c.passed).length}/${pr!.checks.length} فحوصات',
                    color: pr!.allChecksPassed ? AppColors.success : AppColors.danger,
                    dense: true,
                  ),
              ],
            ),
            if (pr != null) ...[
              const SizedBox(height: 8),
              Text(
                '+${pr!.additions} −${pr!.deletions}',
                style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

Future<void> _delete(BuildContext context, WidgetRef ref, Task task) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('حذف المهمة؟'),
      content: Text('«${task.title}» هتتحذف هي وتعليقاتها ومهامها الفرعية.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('إلغاء')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final navigator = Navigator.of(context);
  final done = await runAction(context, () => ref.read(tasksNotifierProvider.notifier).remove(task.id),
      done: 'المهمة اتحذفت');
  if (done) navigator.maybePop();
}
