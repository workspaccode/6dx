import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/entities/task.dart';
import '../pages/task_board_page.dart' show statusLabel, statusColor;
import '../providers/task_providers.dart';
import '../widgets/task_view_switcher.dart';

/// عرض القائمة — V2ListView.dc.html
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksNotifierProvider).value ?? const [];

    return AppScreen(
      title: 'المهام',
      subtitle: 'عرض القائمة',
      trailing: const TaskViewSwitcher(current: 'قائمة'),
      children: [
        if (tasks.isEmpty)
          const HintBanner('مفيش مهام.'),
        for (final task in tasks) _TaskRow(task: task),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.taskDetailPath(task.id)),
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
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor(task.status),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.key, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(task.title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusLabel(task.status),
                style: TextStyle(fontSize: 12, color: statusColor(task.status)),
              ),
              if (task.dueDate != null) ...[
                const SizedBox(height: 2),
                Text(
                  _date(task.dueDate!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: task.isOverdue ? AppColors.danger : null,
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    ));
  }
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _monthNames = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// عرض التقويم — V2Calendar.dc.html
class TaskCalendarPage extends ConsumerWidget {
  const TaskCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksNotifierProvider).value ?? const [];
    final today = DateTime.now();
    final open = tasks.where((t) => t.status != TaskStatus.done).toList();
    final sprint = ref
        .watch(workspaceSprintsProvider)
        .where((s) => !s.start.isAfter(today) && !s.end.isBefore(today))
        .firstOrNull;
    // Open tasks with a due date, nearest first.
    final dueSoon = open.where((t) => t.dueDate != null).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    return AppScreen(
      title: 'المهام',
      subtitle: 'عرض التقويم · ${_monthNames[today.month - 1]} ${today.year}',
      trailing: const TaskViewSwitcher(current: 'تقويم'),
      children: [
        if (sprint != null)
          HintBanner('${sprint.name} بينتهي ${_date(sprint.end)} — ${open.length} مهمة لسه مفتوحة.'),
        _MonthGrid(
          month: today,
          busyDays: tasks.map((t) => t.dueDate).whereType<DateTime>().toList(),
        ),
        const SizedBox(height: 16),
        const SectionLabel('المستحق قريبًا'),
        if (dueSoon.isEmpty) const HintBanner('مفيش مهام مفتوحة ليها ميعاد.'),
        for (final task in dueSoon.take(5))
          AppPanel(
            child: Row(
              children: [
                Expanded(child: Text(task.title)),
                Text('${_date(task.dueDate!)} · ${task.assigneeName ?? 'من غير مسؤول'}'),
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.busyDays});

  final DateTime month;
  final List<DateTime> busyDays;

  static const _days = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (firstDay.weekday - 1) % 7;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in _days)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var week = 0; week < 6; week++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Builder(
                          builder: (context) {
                            final dayIndex = week * 7 + i - leading + 1;
                            final valid = dayIndex >= 1 && dayIndex <= daysInMonth;
                            final busy = busyDays.any(
                              (d) =>
                                  d.day == dayIndex &&
                                  d.month == month.month &&
                                  d.year == month.year,
                            );
                            return Container(
                              margin: const EdgeInsets.all(2),
                              alignment: Alignment.topCenter,
                              decoration: BoxDecoration(
                                color: valid && busy
                                    ? AppColors.accent.withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: valid
                                    ? Border.all(
                                        color: busy
                                            ? AppColors.accent.withValues(alpha: 0.6)
                                            : Theme.of(context)
                                                .colorScheme
                                                .outline,
                                      )
                                    : null,
                              ),
                              child: valid
                                  ? Text(
                                      '$dayIndex',
                                      style: Theme.of(context).textTheme.labelSmall,
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// البحث والفلاتر — V2Search.dc.html
class TaskSearchPage extends ConsumerStatefulWidget {
  const TaskSearchPage({super.key});

  @override
  ConsumerState<TaskSearchPage> createState() => _TaskSearchPageState();
}

class _TaskSearchPageState extends ConsumerState<TaskSearchPage> {
  final _controller = TextEditingController();



  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksNotifierProvider).value ?? const [];
    final query = _controller.text.trim().toLowerCase();
    final results = query.isEmpty
        ? const <Task>[]
        : tasks
            .where((t) => t.title.toLowerCase().contains(query))
            .toList();

    return AppScreen(
      title: 'بحث في المهام',
      children: [
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'بحث في المهام',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
        if (query.isNotEmpty && results.isEmpty)
          const HintBanner('مفيش نتايج.'),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionLabel('${results.length} نتيجة'),
          for (final task in results)
            InkWell(
              onTap: () => context.push(AppRoutes.taskDetailPath(task.id)),
              child: AppPanel(
              child: Row(
                children: [
                  Expanded(child: Text(task.title)),
                  Text(task.key, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            )),
        ],
      ],
    );
  }
}