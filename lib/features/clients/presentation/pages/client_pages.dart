import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// بوابة العميل — V3ClientPortal.dc.html
@RoutePage()
class ClientPortalPage extends StatelessWidget {
  const ClientPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'شركة [اسم العميل]',
      subtitle: 'مقدَّم من Acme · تطبيق المتجر',
      children: [
        const SectionLabel('التقدم العام'),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(value: 0.64),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '64%',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 20,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const HintBanner('المرحلة القادمة: إطلاق الدفع الإلكتروني · 21 نوفمبر'),
        const SizedBox(height: 16),
        const SectionLabel('يحتاج قرارك'),
        AppPanel(
          accent: AppColors.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختيار مزوّد الدفع',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'الخيار (أ) أسرع في التنفيذ، والخيار (ب) أقل في الرسوم.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(onPressed: () {}, child: const Text('موافقة على (أ)')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(onPressed: () {}, child: const Text('تعليق أو سؤال')),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const HintBanner('تم إرسال موافقتك للفريق، شكرًا لك.', color: AppColors.success),
        const SizedBox(height: 16),
        const SectionLabel('ما تم هذا الأسبوع'),
        const AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• أصبح بإمكان العملاء الدخول برمز يصل على الهاتف بدل كلمة المرور'),
              SizedBox(height: 4),
              Text('• تحميل أسرع لصور المنتجات'),
              SizedBox(height: 4),
              Text('• إصلاح توقف التطبيق عند تدوير الشاشة'),
            ],
          ),
        ),
      ],
    );
  }
}

/// تقرير وفاتورة العميل — V3Invoice.dc.html
@RoutePage()
class InvoicePage extends StatelessWidget {
  const InvoicePage({super.key});

  static const _rows = <(String, String)>[
    ('تطوير مزايا جديدة', '52س'),
    ('إصلاح أخطاء', '14س'),
    ('مراجعة واختبار', '11س'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'تقرير أكتوبر',
      subtitle: 'شركة [اسم العميل] · تطبيق المتجر · رقم الفاتورة [رقم]',
      children: [
        const HintBanner('1 – 31 أكتوبر'),
        const SizedBox(height: 8),
        for (final (label, hours) in _rows)
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
                Expanded(child: Text(label)),
                Text(
                  hours,
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
                children: const [
                  Expanded(child: Text('الإجمالي')),
                  Text(
                    '77س',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 18,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Expanded(child: Text('السعر')),
                  Text('[السعر] / ساعة'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'المبلغ المستحق',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '[الإجمالي]',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'JetBrainsMono',
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('ما تم تسليمه'),
        const AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• الدخول برمز التحقق على الهاتف'),
              SizedBox(height: 4),
              Text('• تحميل أسرع لصور المنتجات'),
              SizedBox(height: 4),
              Text('• إصلاح توقف التطبيق عند تدوير الشاشة'),
            ],
          ),
        ),
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

/// الوقت المحسوب تلقائيًا — V3TimeTracking.dc.html
@RoutePage()
class TimeTrackingPage extends StatelessWidget {
  const TimeTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'وقتي اليوم',
      subtitle: 'محسوب من نشاط الفروع والـ commits · مسودة — راجعها قبل الاعتماد',
      children: [
        _EntryRow(kind: 'برمجة', span: '3س 40د', branch: 'feat/MOB-24-otp'),
        _EntryRow(kind: 'مراجعة', span: '45د', branch: 'PR #58'),
        _EntryRow(kind: 'اجتماع', span: '30د', branch: 'Sprint planning'),
        const SizedBox(height: 16),
        const SectionLabel('هذا الأسبوع حسب العميل'),
        const _WeekRow(client: 'شركة [اسم العميل]', time: '18س 40د'),
        const _WeekRow(client: 'مشاريع داخلية', time: '4س 15د'),
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

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.kind, required this.span, required this.branch});

  final String kind;
  final String span;
  final String branch;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind, style: Theme.of(context).textTheme.titleMedium),
                Text(branch, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          Text(
            span,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.edit_outlined, size: 16, color: AppColors.textDim),
        ],
      ),
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.client, required this.time});

  final String client;
  final String time;

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
          Expanded(child: Text(client)),
          Text(
            time,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}