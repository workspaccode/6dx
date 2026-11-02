import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// بدون إنترنت
@RoutePage()
class OfflinePage extends StatelessWidget {
  const OfflinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'بدون إنترنت',
      subtitle: 'بدون اتصال — تعرض آخر نسخة محفوظة',
      children: [
        const HintBanner(
          'أنت تعمل بدون اتصال. القراءة متاحة، والكتابة تُرسل تلقائيًا عند عودة الشبكة.',
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        const SectionLabel('يعمل بدون اتصال'),
        const _CapabilityRow(label: 'قراءة المهام', offline: true),
        const _CapabilityRow(label: 'كتابة تعليقات', offline: true),
        const _CapabilityRow(label: 'تغيير الحالة', offline: true),
        const SizedBox(height: 12),
        const SectionLabel('يحتاج اتصال'),
        const _CapabilityRow(label: 'مراجعة PR', offline: false),
        const _CapabilityRow(label: 'إرسال دعوات', offline: false),
        const _CapabilityRow(label: 'ربط مستودع', offline: false),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      ],
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.label, required this.offline});

  final String label;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            offline
                ? Icons.check_circle_outline_rounded
                : Icons.cloud_off_outlined,
            size: 16,
            color: offline ? AppColors.success : AppColors.textDim,
          ),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// فشل المزامنة
@RoutePage()
class SyncFailedPage extends StatelessWidget {
  const SyncFailedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'فشل المزامنة',
      children: [
        const HintBanner(
          'تعذّرت المزامنة مع GitHub. تعديلاتك محفوظة وستُرسل تلقائيًا.',
          color: AppColors.danger,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () {}, child: const Text('التفاصيل')),
      ],
    );
  }
}

/// سحب الوصول للمستودع
@RoutePage()
class AccessRevokedPage extends StatelessWidget {
  const AccessRevokedPage({super.key, this.repositoryName});

  final String? repositoryName;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'فقدنا الوصول للمستودع',
      children: [
        if (repositoryName != null) ...[
          Text(
            repositoryName!,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              color: AppColors.warning,
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text(
          'أُزيل التطبيق من هذا المستودع على GitHub، أو نُقل المستودع أو حُذف. '
          'مهامك آمنة، لكن الربط بالـ PRs والـ commits متوقف.',
        ),
        const SizedBox(height: 20),
        const SectionLabel('الأسباب الشائعة'),
        const _ReasonRow(text: 'مسؤول المؤسسة ألغى تثبيت التطبيق على GitHub'),
        const _ReasonRow(text: 'تغيّر اسم المستودع أو نُقل لمؤسسة أخرى'),
        const _ReasonRow(text: 'صاحب الربط الأصلي غادر المؤسسة'),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.link_rounded),
          label: const Text('إعادة الربط'),
        ),
      ],
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.textMuted)),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// لا تملك صلاحية
@RoutePage()
class NoPermissionPage extends StatelessWidget {
  const NoPermissionPage({super.key, this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'لا تملك صلاحية التعديل',
      children: [
        Text(
          role == null
              ? 'صلاحيتك في هذا المشروع لا تسمح بالتعديل.'
              : 'صلاحيتك في هذا المشروع هي «$role»: يمكنك قراءة المهام والتعليق عليها فقط.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        const _PermissionRow(label: 'قراءة', allowed: true),
        const _PermissionRow(label: 'تعليق', allowed: true),
        const _PermissionRow(label: 'تعديل', allowed: false),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('رجوع'),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.allowed});

  final String label;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            allowed ? Icons.check_rounded : Icons.close_rounded,
            size: 16,
            color: allowed ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// العنصر محذوف
@RoutePage()
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.itemKey});

  final String? itemKey;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'العنصر محذوف',
      children: [
        if (itemKey != null) ...[
          Text(
            itemKey!,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Text('هذه المهمة لم تعد موجودة.'),
        const SizedBox(height: 8),
        const Text(
          'الرابط الذي فتحته يشير إلى عنصر حُذف أو نُقل لمشروع آخر.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go(AppRoutes.taskBoard),
          child: const Text('فتح لوحة المشروع'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.taskSearch),
          child: const Text('البحث عن مهمة مشابهة'),
        ),
      ],
    );
  }
}

/// لا توجد مشاريع
@RoutePage()
class EmptyProjectsPage extends StatelessWidget {
  const EmptyProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'مشاريعي',
      children: [
        const AppEmptyState(
          icon: Icons.folder_open_rounded,
          title: 'لا توجد مشاريع',
          message: 'ابدأ بمشروع واحد. أسرع طريقة: استورده من مستودع موجود، '
              'وستتحول الـ Issues المفتوحة إلى مهام.',
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.connectRepository),
          icon: const Icon(Icons.download_rounded),
          label: const Text('استيراد من مستودع GitHub'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.createProject),
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('مشروع فارغ'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => context.push(AppRoutes.invite),
          child: const Text('أو ادعُ فريقك أولًا'),
        ),
      ],
    );
  }
}

/// حالة التحميل
@RoutePage()
class SkeletonPage extends StatelessWidget {
  const SkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'جاري التحميل…',
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 12, width: 90),
                SizedBox(height: 10),
                SkeletonBox(height: 16),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: 160),
              ],
            ),
          ),
      ],
    );
  }
}

/// طلب إذن الإشعارات
@RoutePage()
class PushPermissionPage extends StatelessWidget {
  const PushPermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'اعرف فورًا عندما يحتاجك فريقك',
      children: [
        const Text(
          'طلبات المراجعة وفشل الفحوصات والمهام الجديدة تصلك في وقتها، '
          'فلا ينتظر أحد بسببك.',
        ),
        const SizedBox(height: 12),
        const HintBanner(
          'لن نرسل أكثر مما تحتاج — تتحكم في كل نوع، ويمكنك تحديد ساعات هدوء.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {},
          child: const Text('تفعيل الإشعارات'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ليس الآن'),
        ),
      ],
    );
  }
}

/// إشعار بأزرار (معاينة إشعار القفل)
@RoutePage()
class RichNotificationPage extends StatelessWidget {
  const RichNotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'إشعار بأزرار',
      subtitle: 'شكل الإشعار على شاشة القفل',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppLogoMark(),
                  const SizedBox(width: 10),
                  Text(
                    '6DX',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const Spacer(),
                  Text('الآن', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'طلب مراجعة جديد',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text('طلب مراجعة جديد على PR #58'),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(onPressed: () {}, child: const Text('موافقة')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: () {}, child: const Text('فتح')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () {}, child: const Text('لاحقًا')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '{ }',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          color: AppColors.background,
        ),
      ),
    );
  }
}
