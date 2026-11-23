import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/entities/task.dart';
import '../../../../core/utils/feedback.dart';
import '../../../workspace/presentation/providers/workspace_actions.dart';
import '../../../workspace/presentation/widgets/snapshot_status.dart';
import '../providers/task_providers.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// المهام الفرعية
class SubtasksPage extends ConsumerWidget {
  const SubtasksPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtasks = ref.watch(subtasksForTaskProvider(taskId));
    final done = subtasks.where((s) => s.isDone).length;
    final task = (ref.watch(tasksNotifierProvider).value ?? const <Task>[])
        .where((t) => t.id == taskId)
        .firstOrNull;

    return AppScreen(
      title: 'المهام الفرعية',
      subtitle: task == null ? null : '${task.key} · ${task.title}',
      children: [
        const SnapshotStatus(),
        SectionLabel('المهام الفرعية · $done / ${subtasks.length}'),
        if (subtasks.isEmpty)
          const AppEmptyState(
            icon: Icons.checklist_rounded,
            title: 'لا توجد مهام فرعية',
            message: 'قسّم المهمة إلى خطوات أصغر.',
          )
        else
          for (final sub in subtasks)
            InkWell(
              onTap: () => runAction(
                context,
                () => ref.read(workspaceActionsProvider).toggleSubtask(sub.id, done: !sub.isDone),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
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
            )),
        const SizedBox(height: 8),
        ComposeField(
          hint: 'مهمة فرعية جديدة',
          icon: Icons.add_rounded,
          maxLength: 200,
          onSubmit: (text) => runAction(
            context,
            () => ref.read(workspaceActionsProvider).addSubtask(taskId, text),
          ),
        ),
      ],
    );
  }
}

/// التعليقات والإشارات
class CommentsPage extends ConsumerWidget {
  const CommentsPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(commentsForTaskProvider(taskId));
    final task = (ref.watch(tasksNotifierProvider).value ?? const <Task>[])
        .where((t) => t.id == taskId)
        .firstOrNull;

    return AppScreen(
      title: 'التعليقات · ${comments.length}',
      subtitle: task?.title,
      children: [
        const SnapshotStatus(),
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
        ComposeField(
          hint: 'اكتب تعليقًا',
          icon: Icons.send_rounded,
          maxLength: 5000,
          onSubmit: (text) => runAction(
            context,
            () => ref.read(workspaceActionsProvider).addComment(taskId, text),
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

/// A text field with a send button: clears itself when [onSubmit] says it
/// worked, keeps the text when it did not.
class ComposeField extends StatefulWidget {
  const ComposeField({
    super.key,
    required this.hint,
    required this.icon,
    required this.onSubmit,
    this.maxLength,
  });

  final String hint;
  final IconData icon;
  final int? maxLength;
  final Future<bool> Function(String text) onSubmit;

  @override
  State<ComposeField> createState() => _ComposeFieldState();
}

class _ComposeFieldState extends State<ComposeField> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.onSubmit(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLength: widget.maxLength,
      enabled: !_sending,
      onSubmitted: (_) => _send(),
      decoration: InputDecoration(
        hintText: widget.hint,
        counterText: '',
        suffixIcon: IconButton(
          icon: _sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(widget.icon),
          onPressed: _sending ? null : _send,
        ),
      ),
    );
  }
}
