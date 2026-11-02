import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/entities/task.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// المهام الفرعية
@RoutePage()
class SubtasksPage extends ConsumerWidget {
  const SubtasksPage({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtasks = ref.watch(subtasksForTaskProvider(task.id));
    final done = subtasks.where((s) => s.isDone).length;

    return AppScreen(
      title: 'المهام الفرعية',
      subtitle: '${task.key} · ${task.title}',
      children: [
        SectionLabel('المهام الفرعية · $done / ${subtasks.length}'),
        const HintBanner(
          'تتزامن مع قائمة المهام (- [ ]) في وصف الـ PR، فتُعلَّم هنا عندما تُعلَّم هناك.',
        ),
        if (subtasks.isEmpty)
          const AppEmptyState(
            icon: Icons.checklist_rounded,
            title: 'لا توجد مهام فرعية',
            message: 'قسّم المهمة إلى خطوات أصغر.',
          )
        else
          for (final sub in subtasks)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Icon(
                    sub.isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: sub.isDone ? AppColors.accent : AppColors.textDim,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sub.title,
                      style: TextStyle(
                        decoration:
                            sub.isDone ? TextDecoration.lineThrough : null,
                        color: sub.isDone ? AppColors.textMuted : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
        const TextField(
          decoration: InputDecoration(
            hintText: 'مهمة فرعية جديدة',
            suffixIcon: Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

/// التعليقات والإشارات
@RoutePage()
class CommentsPage extends ConsumerWidget {
  const CommentsPage({super.key, this.taskKey = ''});

  final String taskKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(commentsForTaskProvider(taskKey));

    return AppScreen(
      title: 'التعليقات · ${comments.length}',
      subtitle: taskKey,
      children: [
        if (comments.isEmpty)
          const AppEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'لا توجد تعليقات',
            message: 'اكتب أول تعليق على هذه المهمة.',
          )
        else
          for (final comment in comments)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialsAvatar(
                    name: comment.author,
                    color: comment.isAuthor ? AppColors.accent : AppColors.info,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(comment.author,
                                style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            if (comment.createdAt != null)
                              Text(_relative(comment.createdAt!),
                                  style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(comment.body,
                            style: Theme.of(context).textTheme.bodySmall),
                        if (comment.attachmentName != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.image_outlined,
                                    size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 8),
                                Text(comment.attachmentName!,
                                    style: Theme.of(context).textTheme.labelSmall),
                              ],
                            ),
                          ),
                        ],
                        if (comment.code != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              comment.code!,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 8),
        const TextField(
          decoration: InputDecoration(
            hintText: 'اكتب تعليقًا',
            suffixIcon: Icon(Icons.send_rounded),
          ),
        ),
      ],
    );
  }

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    return 'منذ ${diff.inHours} س';
  }
}
