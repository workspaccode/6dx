import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/workspace_snapshot.dart';
import '../providers/workspace_providers.dart';

/// التنقل بين مساحات العمل
@RoutePage()
class WorkspaceSwitchPage extends ConsumerWidget {
  const WorkspaceSwitchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(workspaceSnapshotProvider).value;

    return AppScreen(
      title: 'مساحات العمل',
      children: [
        if (snapshot?.workspaceName == null)
          const AppEmptyState(
            icon: Icons.business_outlined,
            title: 'لا توجد مساحات عمل',
            message: 'أنشئ مساحة عمل أو انضم إلى واحدة بدعوة.',
          )
        else ...[
          AppPanel(
            child: Row(
              children: [
                const InitialsAvatar(name: '6', color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot!.workspaceName!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'مساحة العمل الحالية',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SettingsTile(
          icon: Icons.add_business_outlined,
          title: 'إنشاء مساحة عمل',
          onTap: () {},
        ),
        SettingsTile(
          icon: Icons.mail_outline_rounded,
          title: 'الانضمام بدعوة',
          onTap: () {},
        ),
      ],
    );
  }
}

/// قبول الدعوة
@RoutePage()
class AcceptInvitePage extends ConsumerStatefulWidget {
  const AcceptInvitePage({super.key, this.invite});

  final WorkspaceInvite? invite;

  @override
  ConsumerState<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends ConsumerState<AcceptInvitePage> {
  bool _busy = false;

  Future<void> _accept(String? inviteId) async {
    setState(() => _busy = true);
    AppLogger.action('AcceptInvite', 'accepting invite ${inviteId ?? "(newest)"}');
    try {
      final workspaceId =
          await ref.read(acceptInviteProvider).call(inviteId: inviteId);
      if (!mounted) return;
      AppLogger.action('AcceptInvite', 'joined workspace $workspaceId');
      ref.invalidate(workspaceSnapshotProvider);
      ref.invalidate(pendingInvitesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الانضمام إلى مساحة العمل')),
      );
      if (context.mounted) context.go(AppRoutes.home);
    } catch (error) {
      if (!mounted) return;
      AppLogger.action('AcceptInvite', 'accept failed', error);
      final text = error.toString();
      final message = text.contains('22023')
          ? 'انتهت صلاحية الدعوة'
          : text.contains('P0002')
              ? 'لا توجد دعوة معلّقة لهذا الحساب'
              : text.contains('42501')
                  ? 'الدعوة مرتبطة ببريد إلكتروني آخر'
                  : 'تعذّر قبول الدعوة';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    if (invite == null) {
      // Opened from a notification: resolve the pending invite server-side.
      final pending = ref.watch(pendingInvitesProvider);
      final first = pending.value?.isNotEmpty == true ? pending.value!.first : null;

      return AppScreen(
        title: 'قبول الدعوة',
        children: [
          if (pending.isLoading)
            const AppLoadingView()
          else if (first == null)
            const AppEmptyState(
              icon: Icons.mail_outline_rounded,
              title: 'لا توجد دعوة',
              message: 'الرابط الذي فتحته غير صالح أو انتهت صلاحيته.',
            )
          else ...[
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الإيميل',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(first.email,
                      style: Theme.of(context).textTheme.titleMedium),
                  if (first.invitedBy != null) ...[
                    const SizedBox(height: 8),
                    Text('مساحة العمل: ${first.invitedBy}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : () => _accept(first.id),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('قبول الدعوة'),
            ),
          ],
        ],
      );
    }

    return AppScreen(
      title: 'انضم إلى مساحة العمل',
      subtitle: 'دعوة ${invite.role}',
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الإيميل', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(invite.email,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const HintBanner('الدعوة مرتبطة بهذا الإيميل ولا يمكن تغييره.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : () => _accept(invite.id),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('قبول الدعوة'),
        ),
      ],
    );
  }
}

/// ربط GitHub بعد القبول
@RoutePage()
class LinkGitHubPage extends StatelessWidget {
  const LinkGitHubPage({super.key, this.repository});

  final String? repository;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'خطوة واحدة فقط',
      subtitle: 'اربط حساب GitHub لتُنسب أعمالك تلقائيًا',
      children: [
        const _StepRow(
          index: 2,
          title: 'ربط حساب GitHub',
          body: 'يمكن أن يكون إيميل GitHub مختلفًا عن إيميل الدعوة.',
          active: true,
        ),
        const _StepRow(
          index: 3,
          title: 'قبول دعوة المستودع',
          body: 'اختر المستودعات التي تريد العمل عليها.',
        ),
        const SizedBox(height: 16),
        if (repository != null)
          AppPanel(
            child: Row(
              children: [
                const Icon(Icons.code_rounded, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Text(repository!,
                    style: const TextStyle(fontFamily: 'JetBrainsMono')),
                const Spacer(),
                const Text('write'),
              ],
            ),
          ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.code_rounded),
          label: const Text('ربط GitHub'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {},
          child: const Text('لاحقًا — دخول المشروع'),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.title,
    required this.body,
    this.active = false,
  });

  final int index;
  final String title;
  final String body;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor:
                active ? AppColors.accent : AppColors.surfaceElevated,
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.background : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// دعوة منتهية
@RoutePage()
class InviteExpiredPage extends StatelessWidget {
  const InviteExpiredPage({super.key, this.workspaceName, this.inviterName});

  final String? workspaceName;
  final String? inviterName;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'انتهت صلاحية هذه الدعوة',
      children: [
        Text(
          workspaceName == null
              ? 'الدعوة لم تعد صالحة.'
              : 'دعوة «$workspaceName» لم تعد صالحة.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (inviterName != null) ...[
          const SectionLabel('رسالة'),
          const TextField(
            decoration: InputDecoration(hintText: '(اختياري)'),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(onPressed: () {}, child: const Text('طلب دعوة جديدة')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () {},
          child: const Text('إنشاء مساحة عمل خاصة بي'),
        ),
      ],
    );
  }
}

/// طلبات الانضمام
@RoutePage()
class JoinRequestsPage extends ConsumerWidget {
  const JoinRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(workspaceSnapshotProvider).value;
    final requests = snapshot?.invites ?? const <WorkspaceInvite>[];

    return AppScreen(
      title: 'طلبات الانضمام',
      children: [
        if (requests.isEmpty)
          const AppEmptyState(
            icon: Icons.how_to_reg_outlined,
            title: 'لا توجد طلبات معلّقة',
            message: 'الطلبات التي تصل عبر رابط الدعوة الخاص بنطاقك تظهر هنا.',
          )
        else ...[
          const HintBanner(
            'وصلت عبر رابط الدعوة الخاص بالنطاق — يمكنك قبولهم تلقائيًا لاحقًا.',
          ),
          const SizedBox(height: 12),
          for (final request in requests)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(request.email,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(request.role,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () {}, child: const Text('رفض')),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () {}, child: const Text('قبول')),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// دعوة جماعية
@RoutePage()
class BulkInvitePage extends StatelessWidget {
  const BulkInvitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'دعوة جماعية',
      children: [
        const SectionLabel('الصق قائمة'),
        const TextField(
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'name@example.com\\nname@example.com',
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('أو من مؤسسة GitHub'),
        const SettingsTile(
          icon: Icons.business_rounded,
          title: 'اختيار مؤسسة',
          subtitle: 'اربط مؤسستك واستورد أعضائها',
          color: AppColors.accent,
        ),
        const SizedBox(height: 16),
        const SectionLabel('الصلاحية'),
        Wrap(
          spacing: 8,
          children: const [
            Chip(label: Text('مطوّر')),
            Chip(label: Text('مشاهد')),
            Chip(label: Text('مسؤول')),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () {}, child: const Text('إرسال الدعوات')),
      ],
    );
  }
}

/// التقويم والمنطقة
@RoutePage()
class RegionalCalendarPage extends ConsumerWidget {
  const RegionalCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(workspaceSnapshotProvider).value;
    final calendar = snapshot?.regionalCalendar;

    return AppScreen(
      title: 'التقويم والمنطقة',
      children: [
        const SectionLabel('أسبوع العمل'),
        if (calendar == null)
          const Text('لم يتم ضبط أسبوع العمل بعد.',
              style: TextStyle(color: AppColors.textMuted))
        else ...[
          Wrap(
            spacing: 8,
            children: [
              for (final day in const ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'])
                Chip(
                  label: Text(day),
                  avatar: calendar.workWeek.contains(
                        const [
                          'الأحد',
                          'الاثنين',
                          'الثلاثاء',
                          'الأربعاء',
                          'الخميس',
                          'الجمعة',
                          'السبت',
                        ].indexOf(day) +
                            1,
                      )
                      ? const Icon(Icons.check, size: 14)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          const SectionLabel('العطلات الرسمية'),
          if (calendar.holidays.isEmpty)
            const Text('لا توجد عطلات مضافة.',
                style: TextStyle(color: AppColors.textMuted))
          else
            for (final holiday in calendar.holidays)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(holiday.name),
                subtitle: Text(
                  holiday.date == null
                      ? 'حسب الرؤية'
                      : '${holiday.date!.day}/${holiday.date!.month}/${holiday.date!.year}',
                ),
              ),
        ],
        const SizedBox(height: 16),
        const SectionLabel('الدولة'),
        Wrap(
          spacing: 8,
          children: const [
            Chip(label: Text('مصر')),
            Chip(label: Text('السعودية')),
            Chip(label: Text('الإمارات')),
            Chip(label: Text('الأردن')),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () {}, child: const Text('حفظ')),
      ],
    );
  }
}

/// الخطة والفواتير
@RoutePage()
class BillingPage extends ConsumerWidget {
  const BillingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(workspaceSnapshotProvider).value;
    final billing = snapshot?.billing;

    if (billing == null) {
      return const AppScreen(
        title: 'الخطة والفواتير',
        children: [
          AppEmptyState(
            icon: Icons.credit_card_outlined,
            title: 'لا توجد خطة',
            message: 'ستظهر تفاصيل الاشتراك هنا.',
          ),
        ],
      );
    }

    return AppScreen(
      title: 'الخطة والفواتير',
      children: [
        const SectionLabel('المقاعد المستخدمة'),
        Row(
          children: [
            StatTile(
              value: '${billing.seatsUsed} / ${billing.seatsTotal}',
              label: 'مقاعد',
              color: billing.seatsUsed >= billing.seatsTotal
                  ? AppColors.danger
                  : AppColors.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                billing.seatsUsed >= billing.seatsTotal
                    ? 'وصلتم للحد الأقصى.'
                    : 'يمكن إضافة أعضاء حتى هذا العدد.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionLabel('الخطة'),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(billing.planName,
                  style: Theme.of(context).textTheme.titleMedium),
              if (billing.billingCycle != null) ...[
                const SizedBox(height: 4),
                Text(billing.billingCycle!,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              const StatusBadgeChip(
                label: 'الحالية',
                color: AppColors.accent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('طريقة الدفع'),
        AppPanel(
          child: Text(billing.paymentMethod ?? 'لا توجد طريقة دفع مسجّلة'),
        ),
        const SizedBox(height: 20),
        const SectionLabel('الفواتير السابقة'),
        if (billing.invoices.isEmpty)
          const Text('لا توجد فواتير.',
              style: TextStyle(color: AppColors.textMuted))
        else
          for (final invoice in billing.invoices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(invoice.id),
              subtitle: Text(invoice.date),
              trailing: Text(invoice.amount.toStringAsFixed(2)),
            ),
      ],
    );
  }
}

/// تصدير البيانات
@RoutePage()
class ExportDataPage extends ConsumerWidget {
  const ExportDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).value;

    return AppScreen(
      title: 'تصدير بياناتك',
      subtitle: 'قبل حذف الحساب، احتفظ بنسخة من عملك',
      children: [
        const SectionLabel('ما تريد تصديره'),
        ToggleRow(
          title: 'المشاريع والمهام',
          value: true,
          onChanged: (v) {},
        ),
        ToggleRow(
          title: 'التعليقات وسجل النشاط',
          value: true,
          onChanged: (v) {},
        ),
        ToggleRow(
          title: 'الفواتير والتقارير',
          value: false,
          onChanged: (v) {},
        ),
        const SizedBox(height: 16),
        HintBanner(
          user?.email == null
              ? 'سنرسل رابط التحميل إلى بريدك المسجّل.'
              : 'سنرسل رابط التحميل إلى ${user!.email} خلال دقائق. '
                  'الرابط صالح 7 أيام.',
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () {}, child: const Text('إنشاء نسخة التصدير')),
      ],
    );
  }
}
