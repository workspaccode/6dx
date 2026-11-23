import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/feedback.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/entities/task.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../providers/task_providers.dart';

class NewTaskPage extends ConsumerStatefulWidget {
  const NewTaskPage({super.key});

  @override
  ConsumerState<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends ConsumerState<NewTaskPage> {
  final _titleController = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  int _points = 0;
  String? _assignee;
  DateTime? _due;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }


  /// The screen closes only when the task exists; a failure stays here
  /// with its message so nothing typed is lost.
  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => ref.read(tasksNotifierProvider.notifier).create(
            title: title,
            priority: _priority,
            assigneeUid: _assignee,
            points: _points == 0 ? null : _points,
            dueDate: _due,
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null && mounted) setState(() => _due = picked);
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
            Expanded(
              child: _PointPicker(
                label: 'التقدير (نقاط)',
                value: _points,
                onChanged: (v) => setState(() => _points = v.clamp(0, 100)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDue,
                icon: const Icon(Icons.event_outlined),
                label: Text(_due == null
                    ? 'ميعاد التسليم'
                    : '${_due!.year}-${_due!.month.toString().padLeft(2, '0')}-${_due!.day.toString().padLeft(2, '0')}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _titleController.text.trim().isEmpty || _saving ? null : _submit,
          child: Text(_saving ? 'جاري الإنشاء…' : 'إنشاء المهمة'),
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
  const _PointPicker({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

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
                onPressed: value <= 0 ? null : () => onChanged(value - 1),
                icon: const Icon(Icons.remove_rounded, size: 18),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    color: value == 0 ? AppColors.textMuted : AppColors.accent,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

}