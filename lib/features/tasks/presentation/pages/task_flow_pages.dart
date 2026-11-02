import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../providers/task_providers.dart';

/// تعديل وحذف المهمة
@RoutePage()
class EditTaskPage extends ConsumerWidget {
  const EditTaskPage({super.key, this.taskKey, this.title, this.description});

  final String? taskKey;
  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(workspaceMembersProvider);
    final labels = ref.watch(workspaceLabelsProvider);

    return AppScreen(
      title: 'تعديل المهمة',
      subtitle: taskKey,
      children: [
        TextField(
          controller: TextEditingController(text: title ?? ''),
          decoration: const InputDecoration(labelText: 'العنوان'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: TextEditingController(text: description ?? ''),
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'الوصف'),
        ),
        const SizedBox(height: 20),
        const SectionLabel('المسؤول'),
        if (members.isEmpty)
          const Text('لا يوجد أعضاء.',
              style: TextStyle(color: AppColors.textMuted))
        else
          Wrap(
            spacing: 8,
            children: [
              for (final member in members)
                ChoiceChip(label: Text(member.name), selected: false, onSelected: (_) {}),
            ],
          ),
        const SizedBox(height: 20),
        const SectionLabel('الأولوية'),
        Wrap(
          spacing: 8,
          children: const [
            Chip(label: Text('عالية')),
            Chip(label: Text('عاجلة')),
            Chip(label: Text('متوسطة')),
            Chip(label: Text('منخفضة')),
          ],
        ),
        const SizedBox(height: 20),
        const SectionLabel('Labels'),
        if (labels.isEmpty)
          const Text('لا توجد Labels.',
              style: TextStyle(color: AppColors.textMuted))
        else
          Wrap(
            spacing: 8,
            children: [
              for (final label in labels)
                ChoiceChip(label: Text(label.name), selected: false, onSelected: (_) {}),
            ],
          ),
        const SizedBox(height: 28),
        FilledButton(onPressed: () {}, child: const Text('حفظ')),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          onPressed: () {},
          child: const Text('حذف المهمة'),
        ),
      ],
    );
  }
}

/// تغيير الحالة (ورقة سفلية)
@RoutePage()
class StatusSheetPage extends ConsumerWidget {
  const StatusSheetPage({super.key, this.taskKey});

  final String? taskKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      title: 'تغيير الحالة',
      subtitle: taskKey,
      children: [
        const SectionLabel('نقل المهمة إلى'),
        for (final status in const [
          'قيد الانتظار',
          'قيد التنفيذ',
          'مراجعة',
          'مكتمل',
        ])
          RadioListTileSimple(label: status, selected: false),
        const SizedBox(height: 16),
        const HintBanner(
          'إن كان الـ PR مرتبطًا بالمهمة، ستتحرك الحالة تلقائيًا عند الدمج.',
        ),
      ],
    );
  }
}

/// الاعتماديات
@RoutePage()
class DependenciesPage extends ConsumerWidget {
  const DependenciesPage({super.key, this.taskKey});

  final String? taskKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dependencies = ref.watch(workspaceDependenciesProvider);

    return AppScreen(
      title: 'الاعتماديات',
      subtitle: taskKey,
      children: [
        if (dependencies.isEmpty)
          const AppEmptyState(
            icon: Icons.account_tree_outlined,
            title: 'لا توجد اعتماديات',
            message: 'اربط المهام التي تعيق هذه المهمة.',
          )
        else
          for (final dependency in dependencies)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(dependency.taskKey,
                          style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(dependency.title,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      StatusBadgeChip(
                        label: dependency.state,
                        color: dependency.state == 'blocked'
                            ? AppColors.danger
                            : AppColors.warning,
                      ),
                    ],
                  ),
                  if (dependency.reason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      dependency.reason!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded),
          label: const Text('+ إضافة اعتمادية'),
        ),
        const SizedBox(height: 12),
        const HintBanner(
          'متزامنة مع علاقات blocked by / blocking في GitHub',
        ),
      ],
    );
  }
}

/// سياق المهمة
@RoutePage()
class TaskContextPage extends ConsumerWidget {
  const TaskContextPage({super.key, this.taskKey, this.taskTitle});

  final String? taskKey;
  final String? taskTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prs = ref.watch(workspacePullRequestsProvider);

    return AppScreen(
      title: 'سياق المهمة',
      subtitle: taskKey == null ? null : '$taskKey${taskTitle == null ? '' : ' · $taskTitle'}',
      children: [
        const SectionLabel('الـ PRs والفروع المرتبطة'),
        if (prs.isEmpty)
          const Text('لا يوجد PRs مرتبطة.',
              style: TextStyle(color: AppColors.textMuted))
        else
          for (final pr in prs)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Row(
                children: [
                  Text(
                    '#${pr.number}',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pr.title,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(pr.branch,
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                  StatusBadgeChip(label: pr.state, color: AppColors.info),
                ],
              ),
            ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('حدّث الآن'),
        ),
      ],
    );
  }
}

/// تقرير Bug من الموبايل
@RoutePage()
class BugReportPage extends StatefulWidget {
  const BugReportPage({super.key});

  @override
  State<BugReportPage> createState() => _BugReportPageState();
}

class _BugReportPageState extends State<BugReportPage> {
  final _what = TextEditingController();
  final _steps = TextEditingController();

  @override
  void dispose() {
    _what.dispose();
    _steps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'تقرير Bug',
      children: [
        const SectionLabel('لقطة الشاشة'),
        Container(
          height: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: const Icon(Icons.image_outlined, size: 28, color: AppColors.textDim),
        ),
        const SizedBox(height: 8),
        const Text(
          'أدوات التحديد — استخدم الإخفاء لتغطية أرقام أو بيانات عملاء قبل الإرسال.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        const SectionLabel('ماذا حدث؟'),
        TextField(
          controller: _what,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'وصف المشكلة'),
        ),
        const SizedBox(height: 16),
        const SectionLabel('خطوات التكرار'),
        TextField(
          controller: _steps,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '1. افتح السلة\n2. اضغط على حقل كود الخصم',
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('مُرفق تلقائيًا'),
        const SettingsTile(
          icon: Icons.phonelink_setup_rounded,
          title: 'معلومات الجهاز',
          subtitle: 'النموذج · إصدار النظام · إصدار التطبيق',
          color: AppColors.info,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.code_rounded),
          label: const Text('إنشاء Issue في GitHub'),
        ),
      ],
    );
  }
}

/// تحديد متعدد
@RoutePage()
class BulkActionsPage extends ConsumerWidget {
  const BulkActionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksNotifierProvider).value ?? const [];

    return AppScreen(
      title: 'تحديد متعدد',
      subtitle: '${tasks.length} مهمة',
      children: [
        const SectionLabel('تحديد الكل'),
        if (tasks.isEmpty)
          const AppEmptyState(
            icon: Icons.checklist_rounded,
            title: 'لا توجد مهام',
            message: 'لا يمكن تحديد شيء.',
          )
        else ...[
          for (final task in tasks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: false,
              onChanged: (_) {},
              title: Text(task.title),
              subtitle: Text(task.key),
            ),
          const SizedBox(height: 12),
          const SectionLabel('الإجراءات'),
          Wrap(
            spacing: 8,
            children: const [
              Chip(label: Text('تعيين')),
              Chip(label: Text('الحالة')),
              Chip(label: Text('الأولوية')),
              Chip(label: Text('Sprint')),
              Chip(label: Text('المزيد')),
            ],
          ),
        ],
      ],
    );
  }
}
