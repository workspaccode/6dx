import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../workspace/domain/entities/workspace_snapshot.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/presentation/providers/task_providers.dart';

/// الـ Backlog
class BacklogPage extends ConsumerWidget {
  const BacklogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprints = ref.watch(workspaceSprintsProvider);
    final inSprint = {for (final s in sprints) for (final i in s.items) i.taskId};
    final tasks = (ref.watch(tasksNotifierProvider).value ?? const <Task>[])
        .where((t) => t.status != TaskStatus.done && !inSprint.contains(t.id))
        .toList()
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
    final items = [
      for (final t in tasks)
        SprintItem(taskId: t.id, key: t.key, title: t.title, points: 0),
    ];

    return AppScreen(
      title: 'الـ Backlog',
      subtitle: items.isEmpty ? null : '${items.length} مهمة مش في أي sprint · مرتبة حسب الأولوية',
      children: [
        if (items.isEmpty)
          const AppEmptyState(
            icon: Icons.layers_outlined,
            title: 'الـ Backlog فارغ',
            message: 'أضف مهام من GitHub أو من لوحة المهام.',
          )
        else
          for (final item in items) _BacklogRow(item: item),
      ],
    );
  }
}

class _BacklogRow extends StatelessWidget {
  const _BacklogRow({required this.item});

  final SprintItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.points == 0 ? AppColors.textMuted : AppColors.info;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.key, style: Theme.of(context).textTheme.labelSmall),
                    if (item.fromGithub) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.code_rounded, size: 12, color: AppColors.textDim),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.points == 0 ? '—' : '${item.points}',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// تخطيط الـ Sprint
class SprintPlanPage extends ConsumerWidget {
  const SprintPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprints = ref.watch(workspaceSprintsProvider);
    if (sprints.isEmpty) {
      return const AppScreen(
        title: 'تخطيط الـ Sprint',
        children: [
          AppEmptyState(
            icon: Icons.flag_outlined,
            title: 'لا يوجد Sprint',
            message: 'أنشئ Sprint لتخطيط السعة والالتزام.',
          ),
        ],
      );
    }

    final sprint = sprints.first;
    final overloaded = sprint.committed > sprint.capacity;

    return AppScreen(
      title: sprint.name,
      subtitle: _range(sprint.start, sprint.end),
      children: [
        TextField(
          controller: TextEditingController(text: sprint.goal ?? ''),
          decoration: const InputDecoration(
            labelText: 'هدف الـ Sprint',
            hintText: 'مثال: إطلاق الدفع الإلكتروني',
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('السعة مقابل الالتزام'),
        Row(
          children: [
            StatTile(value: '${sprint.capacity}', label: 'السعة (نقاط)'),
            const SizedBox(width: 10),
            StatTile(
              value: '${sprint.committed}',
              label: 'الالتزام',
              color: overloaded ? AppColors.danger : AppColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 10),
        HintBanner(
          overloaded
              ? 'الالتزام أعلى من السعة بـ ${sprint.committed - sprint.capacity} نقاط — أزل مهمة أو قلّل تقديرًا.'
              : 'الميزان مناسب — يمكن بدء الـ Sprint.',
          color: overloaded ? AppColors.danger : AppColors.accent,
        ),
        if (sprint.items.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('مهام الـ Sprint'),
          for (final item in sprint.items) _BacklogRow(item: item),
        ],
      ],
    );
  }

  static String _range(DateTime from, DateTime to) =>
      '${from.day}/${from.month} – ${to.day}/${to.month}';
}

/// ملخص الـ Sprint
class SprintSummaryPage extends ConsumerWidget {
  const SprintSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sprints = ref.watch(workspaceSprintsProvider);
    if (sprints.isEmpty) {
      return const AppScreen(
        title: 'ملخص الـ Sprint',
        children: [
          AppEmptyState(
            icon: Icons.summarize_outlined,
            title: 'لا يوجد Sprint',
            message: 'يُعرض هنا ملخص آخر Sprint بعد انتهائه.',
          ),
        ],
      );
    }

    final sprint = sprints.last;
    final done = sprint.items.where((i) => i.points > 0).length;

    return AppScreen(
      title: 'انتهى ${sprint.name}',
      subtitle: '${sprint.start.day}/${sprint.start.month} – ${sprint.end.day}/${sprint.end.month}',
      children: [
        const SectionLabel('المهام المنجزة'),
        Row(
          children: [
            StatTile(value: '$done / ${sprint.items.length}', label: 'المهام المنجزة'),
            const SizedBox(width: 10),
            StatTile(value: '${sprint.committed}', label: 'النقاط'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            StatTile(
              value: '${sprint.capacity}',
              label: 'السعة',
              color: AppColors.info,
            ),
            const SizedBox(width: 10),
            StatTile(
              value: '${sprint.committed - sprint.capacity}',
              label: 'نقاط متبقية',
              color: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionLabel('النقاط المتبقية · الفعلي مقابل المثالي'),
        SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final value in const [0.35, 0.55, 0.75, 0.9, 1.0])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 80 * value,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.85),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        HintBanner(
          '${sprint.items.length} مهام لم تكتمل — أزِلها إلى الـ Sprint التالي.',
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () {}, child: const Text('نقلها إلى Sprint التالي')),
      ],
    );
  }
}
