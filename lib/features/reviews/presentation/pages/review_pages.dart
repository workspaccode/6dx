import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../workspace/domain/entities/workspace_snapshot.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// تفاصيل الـ PR
@RoutePage()
class PrDetailPage extends ConsumerWidget {
  const PrDetailPage({super.key, this.prNumber = 58});

  final int prNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pr = ref.watch(pullRequestProvider(prNumber));

    if (pr == null) {
      return const AppScreen(
        title: 'تفاصيل الـ PR',
        children: [
          AppEmptyState(
            icon: Icons.merge_type_rounded,
            title: 'الـ PR غير موجود',
            message: 'ربما حُذف أو تغيّر رقمه.',
          ),
        ],
      );
    }

    return AppScreen(
      title: '${pr.projectName ?? 'PR'} #${pr.number}',
      subtitle: pr.title,
      trailing: TextButton(onPressed: () {}, child: const Text('فتح في GitHub')),
      children: [
        AppPanel(
          child: Row(
            children: [
              InitialsAvatar(name: pr.author, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${pr.author} يريد دمج',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${pr.branch} → ${pr.baseBranch}',
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (pr.issueKey != null) ...[
          const SizedBox(height: 10),
          AppPanel(
            child: Row(
              children: [
                Text(pr.issueKey!,
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(pr.title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                StatusBadgePR(label: pr.state, color: _stateColor(pr.state)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const SectionLabel('الملفات المتغيرة'),
        Row(
          children: [
            StatTile(value: '+${pr.additions}', label: 'إضافات', color: AppColors.success),
            const SizedBox(width: 10),
            StatTile(value: '-${pr.deletions}', label: 'حذوفات', color: AppColors.danger),
          ],
        ),
        const SizedBox(height: 10),
        for (final file in pr.files)
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
                    file.path,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                Text('+${file.additions}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'JetBrainsMono',
                        color: AppColors.success)),
                const SizedBox(width: 6),
                Text('-${file.deletions}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'JetBrainsMono',
                        color: AppColors.danger)),
              ],
            ),
          ),
        if (pr.checks.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionLabel('الفحوصات · ${pr.checks.where((c) => c.passed).length}/${pr.checks.length}'),
          for (final check in pr.checks)
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
                    check.passed ? Icons.check_rounded : Icons.close_rounded,
                    size: 16,
                    color: check.passed ? AppColors.success : AppColors.danger,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(check.name)),
                  Text(check.duration,
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
        ],
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

  static Color _stateColor(String state) => switch (state) {
        'review' => AppColors.warning,
        'open' => AppColors.info,
        'failed' => AppColors.danger,
        _ => AppColors.success,
      };
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

/// فشل الـ CI
@RoutePage()
class CiFailurePage extends ConsumerWidget {
  const CiFailurePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prs = ref.watch(workspacePullRequestsProvider);
    PullRequest? failed;
    for (final pr in prs) {
      if (pr.checks.any((c) => !c.passed)) {
        failed = pr;
        break;
      }
    }

    if (failed == null) {
      return const AppScreen(
        title: 'فشل الـ CI',
        children: [
          AppEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'لا توجد فحوصات فاشلة',
            message: 'كل الفحوصات الحالية ناجحة.',
          ),
        ],
      );
    }

    return AppScreen(
      title: 'فشل فحص واحد',
      subtitle: '${failed.projectName ?? ''} #${failed.number} · ${failed.title}',
      children: [
        for (final check in failed.checks)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: check.passed
                    ? Theme.of(context).colorScheme.outline
                    : AppColors.danger.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  check.passed ? Icons.check_rounded : Icons.close_rounded,
                  size: 18,
                  color: check.passed ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    check.name,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(check.duration,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        if (failed.failureReason != null) ...[
          const SizedBox(height: 16),
          const SectionLabel('سبب الفشل'),
          AppPanel(
            accent: AppColors.danger,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(failed.failureReason!,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Expected status: ${failed.expectedStatus ?? '-'}\n'
                  'Received status: ${failed.receivedStatus ?? '-'}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (failed.lastCommit != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const InitialsAvatar(name: '?'),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'آخر commit من ${failed.lastCommitAuthor ?? ''} · '
                  '${failed.lastCommit} · قبل 3 ساعات',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
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

/// مهلة المراجعة
@RoutePage()
class ReviewSlaPage extends ConsumerWidget {
  const ReviewSlaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prs = ref.watch(workspacePullRequestsProvider);
    final open = prs.where((p) => p.state != 'merged').toList();

    return AppScreen(
      title: 'مهلة المراجعة',
      children: [
        const SectionLabel('سياسة الفريق'),
        const SettingsTile(
          icon: Icons.timer_outlined,
          title: 'أول رد خلال 24 ساعة',
          color: AppColors.accent,
          subtitle: 'يتم reminders تلقائي حسب السياسة',
        ),
        const SizedBox(height: 12),
        const SectionLabel('إجراءات تلقائية'),
        const HintBanner(
          '• تذكير للمراجِع عند 18 ساعة\n• تحويل لمراجِع آخر عند 36 ساعة',
        ),
        const SizedBox(height: 12),
        const SectionLabel('PRs مفتوحة'),
        if (open.isEmpty)
          const AppEmptyState(
            icon: Icons.rate_review_outlined,
            title: 'لا توجد PRs مفتوحة',
            message: 'كل الـ PRs تم مراجعتها.',
          )
        else
          for (final pr in open)
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
                        Text('المراجِع: ${pr.reviewerName ?? '—'}'),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (pr.waitingHours / 24).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: AppColors.border,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('منذ ${pr.waitingHours} ساعة',
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
      ],
    );
  }
}
