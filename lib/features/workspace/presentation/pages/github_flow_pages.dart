import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../providers/workspace_providers.dart';

/// صلاحيات GitHub App
@RoutePage()
class GhAppInstallPage extends StatelessWidget {
  const GhAppInstallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'تثبيت التطبيق على GitHub',
      subtitle: 'سننقلك إلى GitHub لتوافق على هذه الصلاحيات فقط',
      children: [
        const Text(
          'يمكنك إلغاء التثبيت في أي وقت من إعدادات GitHub.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        const SectionLabel('ما سنطلبه'),
        const _ScopeRow(label: 'قراءة Issues و PRs', granted: true),
        const _ScopeRow(label: 'تحديث حالة المهام من PRs', granted: true),
        const _ScopeRow(label: 'إضافة تعليقات', granted: true),
        const SizedBox(height: 16),
        const SectionLabel('ما لن نطلبه أبدًا'),
        const _ScopeRow(label: 'الوصول إلى مستودعات لم تخترها', granted: false),
        const _ScopeRow(label: 'تعديل الكود أو حذفه', granted: false),
        const SizedBox(height: 16),
        const SectionLabel('على أي مستودعات؟'),
        const Text('ستختارها بنفسك بعد التثبيت.',
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {},
          child: const Text('المتابعة إلى GitHub'),
        ),
      ],
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_rounded : Icons.close_rounded,
            size: 16,
            color: granted ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// التثبيت وموافقة الأدمن
@RoutePage()
class GhInstallingPage extends ConsumerWidget {
  const GhInstallingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = ref.watch(codePlatformsProvider);

    return AppScreen(
      title: 'نجهّز مشروعك…',
      children: [
        if (platforms.isEmpty)
          const AppEmptyState(
            icon: Icons.hourglass_empty_rounded,
            title: 'لا توجد عملية تثبيت',
            message: 'ابدأ بتثبيت التطبيق على GitHub من إعدادات المشروع.',
          )
        else ...[
          for (final platform in platforms)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(platform.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          platform.connected
                              ? 'تم التثبيت · جاري جلب المستودعات'
                              : 'بانتظار موافقة مسؤول المؤسسة',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    platform.connected
                        ? Icons.check_circle_rounded
                        : Icons.hourglass_top_rounded,
                    color: platform.connected
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () {}, child: const Text('المتابعة')),
        ],
      ],
    );
  }
}

/// استيراد الـ Issues
@RoutePage()
class ImportIssuesPage extends ConsumerWidget {
  const ImportIssuesPage({super.key, this.repositoryName});

  final String? repositoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(workspaceLabelsProvider);

    return AppScreen(
      title: 'استيراد الـ Issues',
      subtitle: repositoryName,
      children: [
        const SectionLabel('تحويل الـ Labels إلى أولوية'),
        if (labels.isEmpty)
          const Text('لا توجد Labels لربطها.',
              style: TextStyle(color: AppColors.textMuted))
        else
          for (final label in labels)
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
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(label.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label.name)),
                  const Icon(Icons.arrow_back_rounded,
                      size: 16, color: AppColors.textDim),
                  const SizedBox(width: 6),
                  const Text('متوسطة',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
        const SizedBox(height: 16),
        const HintBanner(
          'يمكنك إغلاق التطبيق — سنكمل في الخلفية ونبلغك عند الانتهاء.',
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: () {}, child: const Text('فتح اللوحة الآن')),
      ],
    );
  }
}

/// ربط مساهمي GitHub
@RoutePage()
class MapContributorsPage extends ConsumerWidget {
  const MapContributorsPage({super.key, this.repositoryName});

  final String? repositoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contributors = ref.watch(unlinkedContributorsProvider);

    return AppScreen(
      title: 'مساهمون غير معروفين',
      subtitle: repositoryName,
      children: [
        if (contributors.isEmpty)
          const AppEmptyState(
            icon: Icons.group_outlined,
            title: 'كل المساهمين مرتبطون',
            message: 'لا يوجد commits غير منسوبة لأعضاء.',
          )
        else ...[
          for (final contributor in contributors)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Row(
                children: [
                  const InitialsAvatar(name: '@', color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@${contributor.handle}',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${contributor.commitsCount} commits',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (contributor.isBot)
                    const StatusBadgeChip(
                      label: 'bot',
                      color: AppColors.textMuted,
                    )
                  else
                    TextButton(onPressed: () {}, child: const Text('إجراء')),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () {}, child: const Text('حفظ الربط')),
        ],
      ],
    );
  }
}

/// أكثر من منصة
@RoutePage()
class MultiProviderPage extends ConsumerWidget {
  const MultiProviderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = ref.watch(codePlatformsProvider);

    return AppScreen(
      title: 'منصات الكود',
      subtitle: 'مساحة العمل الحالية',
      children: [
        const HintBanner(
          'مهام من كل المنصات في لوحة واحدة — نفس قواعد المزامنة والمراجعة تعمل على كل المنصات.',
        ),
        const SizedBox(height: 16),
        if (platforms.isEmpty)
          const AppEmptyState(
            icon: Icons.hub_outlined,
            title: 'لا توجد منصات مربوطة',
            message: 'اربط GitHub أو GitLab لعرض مهامهم هنا.',
          )
        else
          for (final platform in platforms)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.code_rounded, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(platform.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          platform.connected
                              ? 'متصل${platform.workspace == null ? '' : ' · ${platform.workspace}'}'
                              : 'غير متصل',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusBadgeChip(
                    label: platform.connected ? 'متصل' : 'غير متصل',
                    color: platform.connected
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
