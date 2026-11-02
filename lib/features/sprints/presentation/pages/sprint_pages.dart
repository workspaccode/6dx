import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// الـ Backlog — V2Backlog.dc.html
@RoutePage()
class BacklogPage extends StatelessWidget {
  const BacklogPage({super.key});

  static const _items = <(String, String, String, Color)>[
    ('MOB-29', 'إضافة المنتجات للمفضلة', '5', AppColors.danger),
    ('MOB-31', 'بلا مسؤول وموعدها الخميس', '3', AppColors.danger),
    ('MOB-18', 'إغلاق تلقائي بعد 30 يومًا', '2', AppColors.warning),
    ('MOB-24', 'صفحة تسجيل الدخول بكود OTP', '5', AppColors.warning),
    ('API-12', 'تحديد معدل طلبات الـ OTP', '3', AppColors.info),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'الـ Backlog',
      subtitle: '18 مهمة · 54 نقطة · مرتبة حسب الأولوية',
      children: [
        Row(
          children: [
            _TabChip(label: 'الكل', count: 18, selected: true),
            const SizedBox(width: 8),
            _TabChip(label: 'من GitHub · 7', count: 7, selected: false),
            const SizedBox(width: 8),
            _TabChip(label: 'بلا تقدير · 4', count: 4, selected: false),
          ],
        ),
        const SizedBox(height: 14),
        for (final (key, title, points, color) in _items)
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
                          Text(key, style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(width: 8),
                          const Icon(Icons.code_rounded,
                              size: 12, color: AppColors.textDim),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    points,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip(
      {required this.label, required this.count, required this.selected});

  final String label;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.14)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.accent : AppColors.textMuted,
        ),
      ),
    );
  }
}

/// تخطيط الـ Sprint — V2SprintPlan.dc.html
@RoutePage()
class SprintPlanPage extends StatelessWidget {
  const SprintPlanPage({super.key});

  static const _committed = 42;

  @override
  Widget build(BuildContext context) {
    final overloaded = _committed > 38;
    final excess = _committed - 38;

    return AppScreen(
      title: 'Sprint 5',
      subtitle: '8 – 21 نوفمبر',
      children: [
        const TextField(
          decoration: InputDecoration(
            labelText: 'هدف الـ Sprint',
            hintText: 'مثال: إطلاق الدفع الإلكتروني',
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('السعة مقابل الالتزام'),
        const Row(
          children: [
            StatTile(value: '38', label: 'السعة (نقاط)'),
            SizedBox(width: 10),
            StatTile(
              value: '$_committed',
              label: 'الالتزام',
              color: AppColors.danger,
            ),
          ],
        ),
        const SizedBox(height: 10),
        HintBanner(
          overloaded
              ? 'الالتزام أعلى من السعة بـ $excess نقاط — أزل مهمة أو قلّل تقديرًا.'
              : 'الميزان مناسب — يمكن بدء الـ Sprint.',
          color: overloaded ? AppColors.danger : AppColors.accent,
        ),
        const SizedBox(height: 20),
        const SectionLabel('سعة كل عضو'),
        for (final (name, capacity, taken) in const [
          ('أحمد', '10 نقاط', 0.66),
          ('منى', '10 نقاط', 0.5),
          ('سارة', '12 نقاط', 0.83),
          ('عماد', '8 نقاط', 0.42),
        ])
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
                InitialsAvatar(name: name),
                const SizedBox(width: 12),
                Expanded(child: Text(name)),
                Text(capacity, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: taken,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: overloaded ? null : () {},
          child: const Text('بدء Sprint 5'),
        ),
      ],
    );
  }
}

/// ملخص الـ Sprint — V2SprintSummary.dc.html
@RoutePage()
class SprintSummaryPage extends StatelessWidget {
  const SprintSummaryPage({super.key});

  static const _bars = <(String, double)>[
    ('23 أكتوبر', 0.35),
    ('26 أكتوبر', 0.55),
    ('29 أكتوبر', 0.75),
    ('2 نوفمبر', 0.9),
    ('5 نوفمبر', 1.0),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'انتهى Sprint 4',
      subtitle: '23 أكتوبر – 5 نوفمبر',
      children: [
        const SectionLabel('المهام المنجزة'),
        const Row(
          children: [
            StatTile(value: '18 / 25', label: 'المهام المنجزة'),
            SizedBox(width: 10),
            StatTile(value: '31 / 42', label: 'النقاط'),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            StatTile(value: '14', label: 'PRs مدموجة', color: AppColors.success),
            SizedBox(width: 10),
            StatTile(
              value: '6 ساعات',
              label: 'متوسط وقت المراجعة',
              color: AppColors.info,
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
              for (final (label, value) in _bars)
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
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const HintBanner(
          '7 مهام لم تكتمل (11 نقطة) — 3 منها لها PR مفتوح.',
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () {}, child: const Text('نقلها إلى Sprint 5')),
      ],
    );
  }
}