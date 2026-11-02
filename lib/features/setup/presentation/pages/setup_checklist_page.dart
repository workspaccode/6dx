import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';

@RoutePage()
class SetupChecklistPage extends ConsumerStatefulWidget {
  const SetupChecklistPage({super.key});

  @override
  ConsumerState<SetupChecklistPage> createState() => _SetupChecklistPageState();
}

class _SetupChecklistPageState extends ConsumerState<SetupChecklistPage> {
  final _items = <_ChecklistItem>[
    const _ChecklistItem(
      title: 'أنشئ مشروعك الأول',
      subtitle: 'اربطه بمستودع GitHub ليبدأ استيراد الـ Issues',
      icon: Icons.create_new_folder_outlined,
    ),
    const _ChecklistItem(
      title: 'ادعُ فريقك',
      subtitle: 'أرسل دعوات بالبريد الإلكتروني',
      icon: Icons.person_add_alt_1_outlined,
    ),
    const _ChecklistItem(
      title: 'فعّل الإشعارات',
      subtitle: 'تنبيهك فورًا عند المراجعات الجديدة',
      icon: Icons.notifications_none_rounded,
    ),
    const _ChecklistItem(
      title: 'اربط حساباتك',
      subtitle: 'Slack أو Discord لمتابعة النشاط',
      icon: Icons.hub_outlined,
    ),
    const _ChecklistItem(
      title: 'خصّص مساحة العمل',
      subtitle: 'الاسم، المنطقة، وأيام العمل',
      icon: Icons.tune_rounded,
    ),
    const _ChecklistItem(
      title: 'جرّب لوحة المهام',
      subtitle: 'اسحب البطاقة لتغيير حالتها',
      icon: Icons.view_kanban_outlined,
    ),
  ];

  int get _done => _items.where((item) => item.done).length;

  @override
  Widget build(BuildContext context) {
    final progress = _items.isEmpty ? 0.0 : _done / _items.length;

    return Scaffold(
      appBar: AppBar(title: const Text('قائمة الإعداد')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'مرحبًا بك في Acme',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text('لنُكمل الإعداد', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_done / ${_items.length} اكتمل',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 24),
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChecklistCard(
                  item: item,
                  onToggle: () => setState(() {
                    _items[index] = item.copyWith(done: !item.done);
                  }),
                ),
              );
            }),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نصيحة 1 من 3',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'في لوحة المهام، اسحب أي بطاقة إلى العمود التالي، أو اضغط عليها مطوّلًا لخيارات أكثر.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  TextButton(onPressed: () {}, child: const Text('فهمت')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _done == _items.length
                  ? () => context.go(AppRoutes.home)
                  : null,
              child: const Text('التالي'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('إخفاء القائمة — يمكنك العودة إليها من حسابي'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem {
  const _ChecklistItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.done = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool done;

  _ChecklistItem copyWith({bool? done}) => _ChecklistItem(
        title: title,
        subtitle: subtitle,
        icon: icon,
        done: done ?? this.done,
      );
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.item, required this.onToggle});

  final _ChecklistItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.done
                ? AppColors.accent.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (item.done ? AppColors.accent : AppColors.info)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: item.done ? AppColors.accent : AppColors.info,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          decoration:
                              item.done ? TextDecoration.lineThrough : null,
                          color: item.done ? AppColors.textMuted : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              item.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: item.done ? AppColors.accent : AppColors.textDim,
            ),
          ],
        ),
      ),
    );
  }
}
