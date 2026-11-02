import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// بوابة العميل
@RoutePage()
class ClientPortalPage extends ConsumerWidget {
  const ClientPortalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(clientReportProvider);

    if (report == null) {
      return const AppScreen(
        title: 'بوابة العميل',
        children: [
          AppEmptyState(
            icon: Icons.business_outlined,
            title: 'لا يوجد مشروع عميل',
            message: 'ستظهر حالة المشروع هنا فور ربطه بالعميل.',
          ),
        ],
      );
    }

    return AppScreen(
      title: report.clientName,
      subtitle: report.projectName,
      children: [
        const SectionLabel('التقدم العام'),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: report.progress),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(report.progress * 100).round()}%',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 20,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        if (report.nextMilestone != null) ...[
          const SizedBox(height: 16),
          HintBanner(
            'المرحلة القادمة: ${report.nextMilestone}'
            '${report.milestoneDate == null ? '' : ' · ${_date(report.milestoneDate!)}'}',
          ),
        ],
        if (report.decisionQuestion != null) ...[
          const SizedBox(height: 16),
          const SectionLabel('يحتاج قرارك'),
          AppPanel(
            accent: AppColors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.decisionQuestion!,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {},
                        child: Text(report.decisionOptions.isEmpty
                            ? 'موافقة'
                            : 'موافقة على ${report.decisionOptions.first}'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('تعليق أو سؤال'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (report.weeklyHighlights.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionLabel('ما تم هذا الأسبوع'),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in report.weeklyHighlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $item'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static String _date(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

/// تقرير وفاتورة العميل
@RoutePage()
class InvoicePage extends ConsumerWidget {
  const InvoicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(clientReportProvider);

    if (report == null) {
      return const AppScreen(
        title: 'تقرير وفاتورة العميل',
        children: [
          AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'لا توجد فاتورة',
            message: 'تظهر الفاتورة هنا بعد اعتماد وقت الفريق.',
          ),
        ],
      );
    }

    return AppScreen(
      title: report.period == null ? 'تقرير العميل' : 'تقرير ${report.period}',
      subtitle: '${report.clientName} · ${report.projectName}',
      children: [
        if (report.invoiceNumber != null)
          Text('رقم الفاتورة ${report.invoiceNumber}',
              style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        for (final line in report.invoiceLines)
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
                Expanded(child: Text(line.label)),
                Text(
                  line.hours,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        AppPanel(
          accent: AppColors.accent,
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('الإجمالي')),
                  Text(
                    report.totalHours ?? '—',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 18,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              if (report.hourlyRate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('السعر')),
                    Text('${report.hourlyRate} / ساعة'),
                  ],
                ),
              ],
              if (report.totalHours != null && report.hourlyRate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'المبلغ المستحق',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      report.hourlyRate ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'JetBrainsMono',
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (report.deliveredItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionLabel('ما تم تسليمه'),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in report.deliveredItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $item'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download_rounded),
          label: const Text('إرفاق تفاصيل الفاتورة'),
        ),
      ],
    );
  }
}

/// الوقت المحسوب تلقائيًا
@RoutePage()
class TimeTrackingPage extends ConsumerWidget {
  const TimeTrackingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(clientReportProvider);

    if (report == null) {
      return const AppScreen(
        title: 'وقتي اليوم',
        children: [
          AppEmptyState(
            icon: Icons.schedule_outlined,
            title: 'لا يوجد وقت محسوب',
            message: 'يظهر الوقت تلقائيًا بعد ربط الفروع.',
          ),
        ],
      );
    }

    return AppScreen(
      title: 'وقتي اليوم',
      subtitle: 'محسوب من نشاط الفروع والـ commits · مسودة',
      children: [
        for (final entry in report.timeEntries)
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.kind,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (entry.branch != null)
                        Text(entry.branch!,
                            style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                Text(
                  entry.span,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        if (report.weekByClient.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionLabel('هذا الأسبوع حسب العميل'),
          for (final row in report.weekByClient)
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
                  Expanded(child: Text(row.client)),
                  Text(
                    row.hours,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 8),
        const HintBanner(
          'يراها أنت والمسؤول فقط · لا تُستخدم لمقارنة الأعضاء',
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: () {}, child: const Text('اعتماد وقت اليوم')),
      ],
    );
  }
}
