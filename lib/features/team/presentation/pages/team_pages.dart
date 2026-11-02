import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// حجم شغل الفريق
@RoutePage()
class WorkloadPage extends ConsumerWidget {
  const WorkloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workload = ref.watch(workspaceWorkloadProvider);
    final suggestions = ref.watch(workspaceSuggestionsProvider);

    return AppScreen(
      title: 'حجم شغل الفريق',
      subtitle: workload.isEmpty ? null : 'Sprint الحالي',
      children: [
        if (workload.isEmpty && suggestions.isEmpty)
          const AppEmptyState(
            icon: Icons.group_work_outlined,
            title: 'لا توجد بيانات حمل',
            message: 'ستظهر نقاط كل عضو بعد توزيع المهام في الـ Sprint.',
          )
        else ...[
          if (workload.isNotEmpty) ...[
            const SectionLabel('النقاط المفتوحة مقابل السعة'),
            for (final entry in workload)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: entry.overloaded
                        ? AppColors.danger.withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry.name,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        Text(
                          '${entry.openPoints} / ${entry.capacity} نقاط',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            color:
                                entry.overloaded ? AppColors.danger : AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: entry.capacity == 0
                            ? 0
                            : (entry.openPoints / entry.capacity).clamp(0.0, 1.0),
                        minHeight: 8,
                        color: entry.overloaded ? AppColors.danger : AppColors.accent,
                        backgroundColor: AppColors.border,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            const SectionLabel('اقتراح لإعادة التوزيع'),
            for (final suggestion in suggestions)
              AppPanel(
                accent: AppColors.accent,
                margin: const EdgeInsetsDirectional.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(suggestion.taskTitle,
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${suggestion.taskTitle} (${suggestion.points} نقاط) من '
                      '${suggestion.fromMemberName} إلى ${suggestion.toMemberName}'
                      '${suggestion.reason == null ? '' : ' — ${suggestion.reason}'}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {},
                            child: const Text('نقل المهمة'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            child: const Text('تجاهل'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ],
      ],
    );
  }
}

/// الملخص اليومي
@RoutePage()
class DigestPage extends ConsumerWidget {
  const DigestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final digest = ref.watch(workspaceDigestProvider);
    final user = ref.watch(authNotifierProvider).value;

    return AppScreen(
      title: user == null ? 'الملخص اليومي' : 'صباح الخير يا ${user.displayName}',
      subtitle: 'مُجمّع من GitHub تلقائيًا',
      children: [
        if (digest.isEmpty)
          const AppEmptyState(
            icon: Icons.wb_sunny_outlined,
            title: 'لا يوجد ملخص',
            message: 'سيظهر ملخص نشاط الأمس هنا.',
          )
        else ...[
          for (final section in const ['done', 'today', 'blocker']) ...[
            if (digest.any((e) => e.section == section)) ...[
              SectionLabel(switch (section) {
                'done' => 'أمس أنجزت',
                'today' => 'اليوم',
                _ => 'عوائق في الفريق',
              }),
              for (final entry in digest.where((e) => e.section == section))
                _DigestTile(entry: entry),
              const SizedBox(height: 12),
            ],
          ],
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('نشر كتحديث Standup للفريق'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () {}, child: const Text('نسخ كنص')),
        ],
      ],
    );
  }
}

class _DigestTile extends StatelessWidget {
  const _DigestTile({required this.entry});

  final dynamic entry;

  @override
  Widget build(BuildContext context) {
    final tone = entry.tone == 'danger' ? AppColors.danger : AppColors.info;
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
            height: 36,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.text, style: Theme.of(context).textTheme.bodyMedium),
                if (entry.meta != null)
                  Text(entry.meta!, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          if (entry.actionLabel != null)
            TextButton(onPressed: () {}, child: Text(entry.actionLabel!)),
        ],
      ),
    );
  }
}
