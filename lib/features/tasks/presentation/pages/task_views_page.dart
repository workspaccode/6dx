import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/entities/task.dart';
import '../pages/task_board_page.dart' show statusLabel, statusColor;
import '../providers/task_providers.dart';
import '../widgets/task_view_switcher.dart';

/// عرض القائمة — V2ListView.dc.html
@RoutePage()
class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksNotifierProvider).value ?? const [];

    return AppScreen(
      title: 'تطبيق المتجر',
      subtitle: 'عرض القائمة',
      trailing: const TaskViewSwitcher(current: 'قائمة'),
      children: [
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
              const SizedBox(height: 2),
              Text('غدًا', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// عرض التقويم — V2Calendar.dc.html
@RoutePage()
class TaskCalendarPage extends ConsumerWidget {
  const TaskCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksNotifierProvider).value ?? const [];
    final today = DateTime.now();

    return AppScreen(
      title: 'تطبيق المتجر',
      subtitle: 'عرض التقويم · نوفمبر 2026',
      trailing: const TaskViewSwitcher(current: 'تقويم'),
      children: [
        const HintBanner('Sprint 4 ينتهي الخميس — 11 مهمة لم تُغلق بعد.'),
        _MonthGrid(
          month: today,
          busyDays: tasks.map((t) => t.dueDate).whereType<DateTime>().toList(),
        ),
        const SizedBox(height: 16),
        const SectionLabel('المستحق قريبًا'),
        for (final task in tasks.take(3))
          AppPanel(
            child: Row(
              children: [
                Expanded(child: Text(task.title)),
                Text('· ${task.assigneeName ?? '؟'}'),
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
@RoutePage()
class TaskSearchPage extends ConsumerStatefulWidget {
  const TaskSearchPage({super.key});

  @override
  ConsumerState<TaskSearchPage> createState() => _TaskSearchPageState();
}

class _TaskSearchPageState extends ConsumerState<TaskSearchPage> {
  final _controller = TextEditingController();

  static const _savedFilters = [
    ['مهامي المتأخرة', Icons.schedule_rounded, AppColors.danger],
    ['بلا مسؤول', Icons.person_off_outlined, AppColors.warning],
    ['CI فاشل', Icons.error_outline_rounded, AppColors.danger],
  ];

  static const _quickFilters = [
    'مراجعة',
    'قيد التنفيذ',
    'مكتمل',
    'عاجلة',
    'بانتظار مراجعتي',
  ];

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
        const SizedBox(height: 12),
        const SectionLabel('فلاتر محفوظة', actionLabel: 'مسح الكل'),
        for (final filter in _savedFilters)
          SettingsTile(
            icon: filter[1] as IconData,
            title: filter[0] as String,
            color: filter[2] as Color,
            onTap: () {},
          ),
        const SizedBox(height: 12),
        const SectionLabel('فلاتر سريعة'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _quickFilters)
              Chip(label: Text(f), onDeleted: () {}),
          ],
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionLabel('${results.length} نتيجة'),
          for (final task in results)
            AppPanel(
              child: Row(
                children: [
                  Expanded(child: Text(task.title)),
                  Text(task.key, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
        ],
      ],
    );
  }
}