import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// إعدادات المشروع — V2ProjectSettings.dc.html
@RoutePage()
class ProjectSettingsPage extends StatelessWidget {
  const ProjectSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'إعدادات المشروع',
      subtitle: 'تطبيق المتجر · MOB',
      children: [
        SettingsTile(
          icon: Icons.group_outlined,
          title: 'الأعضاء والصلاحيات',
          subtitle: '5 أعضاء · دعوة واحدة معلّقة',
          onTap: () => context.push(AppRoutes.members),
        ),
        SettingsTile(
          icon: Icons.sync_outlined,
          title: 'المستودعات والمزامنة',
          subtitle: 'مستودعان مربوطان',
          onTap: () => context.push(AppRoutes.syncSettings),
        ),
        SettingsTile(
          icon: Icons.label_outline_rounded,
          title: 'الـ Labels',
          subtitle: 'متزامنة مع GitHub',
          onTap: () => context.push(AppRoutes.labels),
        ),
        SettingsTile(
          icon: Icons.notifications_none_rounded,
          title: 'إشعارات المشروع',
          subtitle: 'قناة Slack غير مربوطة',
          onTap: () => context.push(AppRoutes.integrations),
        ),
        SettingsTile(
          icon: Icons.view_column_outlined,
          title: 'أعمدة اللوحة',
          subtitle: 'قيد الانتظار · قيد التنفيذ · مراجعة · مكتمل',
          trailing: TextButton(onPressed: () {}, child: const Text('+ عمود')),
        ),
        const SizedBox(height: 12),
        const SectionLabel('حد أقصى للمهام قيد العمل لكل عضو'),
        const _LimitStepper(),
        ToggleRow(
          title: 'تحذير عند تعيين مهمة لعضو تجاوز الحد',
          value: true,
          onChanged: (v) {},
        ),
        const SizedBox(height: 20),
        SettingsTile(
          icon: Icons.history_rounded,
          title: 'سجل النشاط',
          subtitle: 'يُحفظ 12 شهرًا',
          color: AppColors.info,
          onTap: () => context.push(AppRoutes.activityLog),
        ),
        SettingsTile(
          icon: Icons.archive_outlined,
          title: 'أرشفة أو حذف المشروع',
          color: AppColors.danger,
          onTap: () => context.push(AppRoutes.archiveProject),
        ),
      ],
    );
  }
}

class _LimitStepper extends StatelessWidget {
  const _LimitStepper();

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
          const Spacer(),
          Text(
            '3',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 22,
              color: AppColors.accent,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.remove_rounded),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.add_rounded)),
        ],
      ),
    );
  }
}

/// المستودعات والمزامنة — V2SyncSettings.dc.html
@RoutePage()
class SyncSettingsPage extends StatelessWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'المستودعات والمزامنة',
      children: [
        const SectionLabel('المستودعات المربوطة'),
        _RepoTile(
          repo: 'acme/store-mobile',
          details: 'التطبيق · رئيسي · منذ دقيقة',
          color: AppColors.success,
        ),
        _RepoTile(
          repo: 'acme/store-api',
          details: 'الـ Backend · منذ 3 دقائق',
          color: AppColors.success,
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded),
          label: const Text('+ ربط مستودع آخر'),
        ),
        const SizedBox(height: 20),
        const SectionLabel('إذا عُدّلت المهمة في المكانين، أيّ تعديل يُعتمد؟'),
        const HintBanner('GitHub هو المصدر — تعديلاته تلغي تعديل التطبيق.'),
        const SizedBox(height: 16),
        const SettingsTile(
          icon: Icons.webhook_rounded,
          title: 'Webhook',
          subtitle: 'يعمل · آخر حدث منذ دقيقة',
          color: AppColors.success,
        ),
        const SettingsTile(
          icon: Icons.speed_rounded,
          title: 'حد الـ API المتبقي',
          subtitle: '4,812 / 5,000',
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.sync_rounded),
          label: const Text('مزامنة الآن'),
        ),
      ],
    );
  }
}

class _RepoTile extends StatelessWidget {
  const _RepoTile({
    required this.repo,
    required this.details,
    required this.color,
  });

  final String repo;
  final String details;
  final Color color;

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
          Icon(Icons.code_rounded, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repo,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                  ),
                ),
                Text(details, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// إدارة الـ Labels — V3Labels.dc.html
@RoutePage()
class LabelsPage extends StatelessWidget {
  const LabelsPage({super.key});

  static const _labels = <(String, Color)>[
    ('مراجعة', AppColors.warning),
    ('تطوير', AppColors.info),
    ('عميل', AppColors.purple),
    ('بحث', AppColors.textMuted),
    ('عاجل', AppColors.danger),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'الـ Labels',
      subtitle: 'متزامنة مع GitHub',
      children: [
        for (final (name, color) in _labels)
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
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(name)),
                const Icon(Icons.drag_indicator_rounded,
                    color: AppColors.textDim),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const SectionLabel('Label جديد'),
        const TextField(
          decoration: InputDecoration(labelText: 'اسم الـ Label'),
        ),
        const SizedBox(height: 12),
        const HintBanner('معاينة: مراجعة'),
        FilledButton(onPressed: () {}, child: const Text('إضافة')),
      ],
    );
  }
}

/// Slack وDiscord — V3Integrations.dc.html
@RoutePage()
class IntegrationsPage extends StatelessWidget {
  const IntegrationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'قنوات الفريق',
      subtitle: 'أرسل أحداث المشروع إلى حيث يتحدث فريقك',
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💬', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Slack')),
                  TextButton(onPressed: () {}, child: const Text('فصل')),
                ],
              ),
              const SizedBox(height: 6),
              const Text('متصل · مساحة Acme',
                  style: TextStyle(color: AppColors.success, fontSize: 12)),
              const SizedBox(height: 12),
              const Text('القناة:', style: TextStyle(fontSize: 12)),
              for (final channel in const ['#mobile-team', '#releases', '#general'])
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tag_rounded, size: 16),
                  title: Text(
                    channel,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'JetBrainsMono'),
                  ),
                  trailing: const Icon(Icons.check_circle_rounded, color: AppColors.accent),
                ),
              const Text('أرسل عند:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: const [
                  Chip(label: Text('PR مفتوح')),
                  Chip(label: Text('فشل CI')),
                  Chip(label: Text('Sprint انتهى')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppPanel(
          child: Column(
            children: [
              Row(
                children: [
                  const Text('🎮', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Discord')),
                  TextButton(onPressed: () {}, child: const Text('ربط')),
                ],
              ),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'غير متصل',
                  style: TextStyle(color: AppColors.textDim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppPanel(
          child: Column(
            children: [
              Row(
                children: [
                  const Text('📋', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Microsoft Teams')),
                  TextButton(onPressed: () {}, child: const Text('أبلغني')),
                ],
              ),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'قريبًا',
                  style: TextStyle(color: AppColors.info, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// سجل النشاط — V3ActivityLog.dc.html
@RoutePage()
class ActivityLogPage extends StatelessWidget {
  const ActivityLogPage({super.key});

  static const _events = <(IconData, Color, String, String)>[
    (Icons.merge_rounded, AppColors.success, 'دُمج PR #58 في main', 'منذ 40 دقيقة · أحمد'),
    (Icons.comment_outlined, AppColors.info, 'علّقت سارة على MOB-24', 'منذ ساعة'),
    (Icons.sync_rounded, AppColors.textMuted, 'استورد 12 Issue من GitHub', 'منذ 3 ساعات'),
    (Icons.person_add_alt_1_outlined, AppColors.purple, 'انضم عماد للمشروع', 'أمس · 4:12 م'),
    (Icons.delete_outline_rounded, AppColors.danger, 'حُذفت MOB-12', 'أمس · 4:12 م · أحمد'),
    (Icons.edit_outlined, AppColors.warning, 'غُيّرت صلاحية منى إلى مطوّر', 'الأحد'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'سجل النشاط',
      subtitle: 'تطبيق المتجر · يُحفظ 12 شهرًا',
      children: [
        for (final (icon, color, text, time) in _events)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: Theme.of(context).textTheme.bodyMedium),
                      Text(time, style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// أرشفة أو حذف المشروع — V2Archive.dc.html
@RoutePage()
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'إنهاء المشروع',
      children: [
        const SectionLabel('أرشفة'),
        const HintBanner(
          'يختفي المشروع من القائمة وتتوقف المزامنة. تبقى المهام والسجل محفوظة، ويمكنك استعادته في أي وقت.',
        ),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.archive_outlined),
          label: const Text('أرشفة المشروع'),
        ),
        const SizedBox(height: 28),
        const SectionLabel('حذف نهائي'),
        AppPanel(
          accent: AppColors.danger,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('حذف 25 مهمة وكل التعليقات والسجل', style: TextStyle(color: AppColors.danger)),
              const SizedBox(height: 6),
              const Text(
                '• إلغاء دعوة واحدة معلّقة\n• المستودعات على GitHub لن تُحذف',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'اكتب «تطبيق المتجر» للتأكيد',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          onPressed: () {},
          child: const Text('حذف المشروع نهائيًا'),
        ),
      ],
    );
  }
}