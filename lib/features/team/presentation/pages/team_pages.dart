import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// حجم شغل الفريق — V2Workload.dc.html
@RoutePage()
class WorkloadPage extends StatelessWidget {
  const WorkloadPage({super.key});

  static const _members = <(String, int, int, Color)>[
    ('أحمد', 13, 10, AppColors.danger),
    ('سارة', 11, 12, AppColors.warning),
    ('منى', 5, 10, AppColors.success),
    ('عماد', 7, 8, AppColors.accent),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'حجم شغل الفريق',
      subtitle: 'تطبيق المتجر · Sprint 4',
      children: [
        const SectionLabel('النقاط المفتوحة مقابل السعة'),
        for (final (name, open, capacity, color) in _members)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium)),
                    Text(
                      '$open / $capacity نقاط',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (open / capacity).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: color,
                    backgroundColor: AppColors.border,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const SectionLabel('اقتراح لإعادة التوزيع'),
        AppPanel(
          accent: AppColors.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text('نقل MOB-22', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '«فلترة المنتجات» (3 نقاط) من أحمد إلى منى — لم يبدأ عليها أحد بعد.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(onPressed: () {}, child: const Text('نقل المهمة')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(onPressed: () {}, child: const Text('تجاهل')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// الملخص اليومي — V2Digest.dc.html
@RoutePage()
class DigestPage extends StatelessWidget {
  const DigestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'صباح الخير يا أسامة',
      subtitle: 'الإثنين 2 نوفمبر · مُجمّع من GitHub تلقائيًا',
      children: [
        const SectionLabel('أمس أنجزت'),
        AppPanel(
          child: Text(
            'دمج PR #50 وإغلاق MOB-18 · 3 commits على MOB-27',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('اليوم'),
        _TodayItem(
          color: AppColors.warning,
          title: 'الإشعارات الفورية لحالة الطلب',
          detail: 'تسليم غدًا',
        ),
        _TodayItem(
          color: AppColors.info,
          title: 'مراجعة PR #58 لأحمد',
          detail: 'صغير · 15 د',
        ),
        const SizedBox(height: 16),
        const SectionLabel('عوائق في الفريق'),
        _BlockerItem(
          text: 'PR #55 لمنى ينتظر مراجعة منذ يومين',
          action: 'مرّر لسارة',
        ),
        _BlockerItem(
          text: 'فحص فاشل على store-api #112',
          action: 'إعادة تشغيل',
        ),
        _BlockerItem(
          text: 'MOB-31 بلا مسؤول وموعدها الخميس',
          action: 'تعيين',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.campaign_outlined),
          label: const Text('نشر كتحديث Standup للفريق'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () {}, child: const Text('نسخ كنص')),
      ],
    );
  }
}

class _TodayItem extends StatelessWidget {
  const _TodayItem({
    required this.color,
    required this.title,
    required this.detail,
  });

  final Color color;
  final String title;
  final String detail;

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
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockerItem extends StatelessWidget {
  const _BlockerItem({required this.text, required this.action});

  final String text;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          TextButton(onPressed: () {}, child: Text(action)),
        ],
      ),
    );
  }
}