import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/entities/task.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../providers/task_providers.dart';

@RoutePage()
class NewTaskPage extends ConsumerStatefulWidget {
  const NewTaskPage({super.key});

  @override
  ConsumerState<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends ConsumerState<NewTaskPage> {
  final _titleController = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  final int _points = 3;
  String? _assignee;
  bool _createIssue = true;
  bool _createBranch = true;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String get _branch {
    final slug = _titleController.text.trim().toLowerCase().replaceAll(' ', '-');
    return 'feat/${slug.isEmpty ? 'new-task' : slug}';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    await ref.read(tasksNotifierProvider.notifier).create(
          title: title,
          priority: _priority,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(workspaceMembersProvider);
    return AppScreen(
      title: 'مهمة جديدة',
      subtitle: null,
      children: [
        TextField(
          controller: _titleController,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'العنوان'),
        ),
        const SizedBox(height: 16),
        const SectionLabel('المسؤول'),
        const HintBanner(
          'اختر عضوًا بعد التحقق من حجم الشغل الحالي عليه.',
        ),
        if (members.isEmpty)
          const Text('لا يوجد أعضاء بعد.',
              style: TextStyle(color: AppColors.textMuted))
        else
          Wrap(
            spacing: 8,
            children: [
              for (final member in members)
                ChoiceChip(
                  label: Text(member.name),
                  selected: _assignee == member.id,
                  onSelected: (_) => setState(() => _assignee = member.id),
                ),
            ],
          ),
        const SizedBox(height: 20),
        const SectionLabel('الأولوية'),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in {
              TaskPriority.urgent: 'عاجلة',
              TaskPriority.high: 'عالية',
              TaskPriority.medium: 'متوسطة',
              TaskPriority.low: 'منخفضة',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _priority == entry.key,
                onSelected: (_) => setState(() => _priority = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _PointPicker(label: 'التقدير (نقاط)', value: _points)),
            const SizedBox(width: 12),
            Expanded(
              child: _PointPicker(
                label: 'التسليم',
                value: null,
                placeholder: 'غدًا',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ToggleRow(
          title: 'إنشاء Issue في GitHub',
          value: _createIssue,
          onChanged: (v) => setState(() => _createIssue = v),
        ),
        ToggleRow(
          title: 'إنشاء فرع تلقائيًا',
          subtitle: _branch,
          value: _createBranch,
          onChanged: (v) => setState(() => _createBranch = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _titleController.text.trim().isEmpty ? null : _submit,
          child: const Text('إنشاء المهمة'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push(AppRoutes.taskBoard),
          child: const Text('فتح لوحة المهام'),
        ),
      ],
    );
  }
}

class _PointPicker extends StatelessWidget {
  const _PointPicker({required this.label, required this.value, this.placeholder});

  final String label;
  final int? value;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: value == null ? null : () => _adjust(-1),
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              Expanded(
                child: Text(
                  value?.toString() ?? placeholder ?? '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    color: value == null ? AppColors.textMuted : AppColors.accent,
                  ),
                ),
              ),
              IconButton(
                onPressed: value == null ? null : () => _adjust(1),
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: avoid_unused_constructor_parameters
  void _adjust(int delta) {}
}