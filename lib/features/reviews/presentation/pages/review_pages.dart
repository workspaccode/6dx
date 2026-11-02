import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// تفاصيل الـ PR — V2PRDetail.dc.html
@RoutePage()
class PrDetailPage extends StatelessWidget {
  const PrDetailPage({super.key, this.prNumber = '58'});

  final String prNumber;

  static const _files = <(String, String, String)>[
    ('lib/screens/otp_login.dart', '+214', '−18'),
    ('lib/services/otp_service.dart', '+64', '−12'),
    ('lib/widgets/code_input.dart', '+38', '−10'),
    ('test/otp_test.dart', '+52', '−0'),
    ('lib/main.dart', '+6', '−2'),
  ];

  static const _checks = <(String, String, bool)>[
    ('build', '2د 15ث', true),
    ('unit tests', '3د 40ث', true),
    ('ui tests', '4د 02ث', true),
    ('lint', '18ث', true),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'store-mobile #$prNumber',
      subtitle: 'feat: OTP login screen',
      trailing: TextButton(
        onPressed: () {},
        child: const Text('فتح في GitHub'),
      ),
      children: [
        AppPanel(
          child: Row(
            children: [
              const InitialsAvatar(name: 'أحمد', color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('أحمد يريد دمج',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'feat/MOB-24-otp → main',
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppPanel(
          child: Row(
            children: [
              Text('MOB-24', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'صفحة تسجيل الدخول بكود OTP',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const StatusBadgePR(label: 'مراجعة', color: AppColors.warning),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('الملفات المتغيرة · 7'),
        Row(
          children: const [
            StatTile(value: '+312', label: 'إضافات', color: AppColors.success),
            SizedBox(width: 10),
            StatTile(value: '−48', label: 'حذوفات', color: AppColors.danger),
          ],
        ),
        const SizedBox(height: 10),
        for (final (file, add, del) in _files)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined,
                    size: 16, color: AppColors.textDim),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    file,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Text(
                  add,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'JetBrainsMono',
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  del,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'JetBrainsMono',
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const SectionLabel('الفحوصات · 4/4'),
        for (final (name, duration, passed) in _checks)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              children: [
                Icon(
                  passed ? Icons.check_rounded : Icons.close_rounded,
                  size: 16,
                  color: passed ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(name)),
                Text(duration, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const TextField(
          decoration: InputDecoration(
            hintText: 'تعليق المراجعة',
            suffixIcon: Icon(Icons.send_rounded),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.merge_rounded),
          label: const Text('اعتماد ودمج'),
        ),
      ],
    );
  }
}

class StatusBadgePR extends StatelessWidget {
  const StatusBadgePR({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// فشل الـ CI — V2CIFailure.dc.html
@RoutePage()
class CiFailurePage extends StatelessWidget {
  const CiFailurePage({super.key});

  static const _checks = <(String, String, bool)>[
    ('build', '1د 12ث', true),
    ('lint', '18ث', true),
    ('integration-tests', '3د 40ث', false),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'فشل فحص واحد',
      subtitle: 'store-api #112 · fix: rate limiter on /otp',
      children: [
        for (final (name, duration, passed) in _checks)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: passed
                    ? Theme.of(context).colorScheme.outline
                    : AppColors.danger.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  passed ? Icons.check_rounded : Icons.close_rounded,
                  size: 18,
                  color: passed ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(duration, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const SectionLabel('سبب الفشل'),
        AppPanel(
          accent: AppColors.danger,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('otp.spec.ts › rate limit',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                '✕ blocks 6th request within 60s\nExpected status: 429\nReceived status: 200',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'at limiter.test.ts:42:18',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const InitialsAvatar(name: 'سارة'),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'آخر commit من سارة · a3f9c21 · قبل 3 ساعات',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة تشغيل الفحص'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('إنشاء مهمة إصلاح'),
        ),
      ],
    );
  }
}

/// مهلة المراجعة — V3ReviewSLA.dc.html
@RoutePage()
class ReviewSlaPage extends StatelessWidget {
  const ReviewSlaPage({super.key});

  static const _prs = <(String, String, String, double)>[
    ('#58', 'سارة', 'منذ 9 ساعات', 0.38),
    ('#61', 'أحمد', 'منذ 14 ساعة', 0.58),
    ('#63', 'منى', 'منذ 30 ساعة', 0.83),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'مهلة المراجعة',
      children: [
        const SectionLabel('سياسة الفريق'),
        const SettingsTile(
          icon: Icons.timer_outlined,
          title: 'أول رد خلال 24 ساعة',
          color: AppColors.accent,
          subtitle: 'متوسط الانتظار: 9 ساعات ↓ من 4 أيام',
        ),
        const SizedBox(height: 12),
        const SectionLabel('إجراءات تلقائية'),
        const HintBanner(
          '• تذكير للمراجِع عند 18 ساعة\n• تحويل لمراجِع آخر عند 36 ساعة',
        ),
        const SizedBox(height: 12),
        const SectionLabel('PRs مفتوحة'),
        for (final (num, reviewer, waiting, progress) in _prs)
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
                Text(
                  num,
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
                      Text('المراجِع: $reviewer'),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(waiting, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {},
          child: const Text('إعادة التعيين'),
        ),
      ],
    );
  }
}