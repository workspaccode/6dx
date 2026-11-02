import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// إعدادات الحساب — V2Account.dc.html
@RoutePage()
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return AppScreen(
      title: 'إعدادات الحساب',
      children: [
        const SectionLabel('الحسابات المربوطة'),
        SettingsTile(
          icon: Icons.code_rounded,
          title: 'GitHub',
          subtitle: '@[github-username] · 3 repos',
          color: AppColors.accent,
          trailing: TextButton(onPressed: () {}, child: const Text('إدارة')),
        ),
        SettingsTile(
          icon: Icons.code_rounded,
          title: 'GitLab',
          subtitle: 'قريبًا',
          color: AppColors.textDim,
          trailing: TextButton(onPressed: () {}, child: const Text('أبلغني')),
        ),
        const SizedBox(height: 12),
        const SectionLabel('التفضيلات'),
        SettingsTile(
          icon: Icons.translate_rounded,
          title: 'اللغة',
          subtitle: 'العربية',
          color: AppColors.info,
          onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
        ),
        SettingsTile(
          icon: Icons.dark_mode_outlined,
          title: 'المظهر',
          subtitle: themeMode == ThemeMode.dark ? 'داكن' : 'فاتح',
          color: AppColors.purple,
          onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(
                themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
              ),
        ),
        const SettingsTile(
          icon: Icons.calendar_month_outlined,
          title: 'ساعات العمل',
          subtitle: 'الأحد–الخميس · 9–5',
          color: AppColors.warning,
        ),
        const SizedBox(height: 12),
        const SectionLabel('الأمان'),
        SettingsTile(
          icon: Icons.email_outlined,
          title: 'الإيميل',
          subtitle: ref.watch(authNotifierProvider).value?.email ?? '—',
          color: AppColors.info,
        ),
        const SettingsTile(
          icon: Icons.devices_rounded,
          title: 'الأجهزة المسجّل منها',
          subtitle: '2 أجهزة',
          color: AppColors.warning,
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          onPressed: () {},
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('حذف الحساب'),
        ),
      ],
    );
  }
}

/// إعدادات الإشعارات — V2NotifSettings.dc.html
@RoutePage()
class NotifSettingsPage extends StatefulWidget {
  const NotifSettingsPage({super.key});

  @override
  State<NotifSettingsPage> createState() => _NotifSettingsPageState();
}

class _NotifSettingsPageState extends State<NotifSettingsPage> {
  bool _push = true;
  bool _email = false;
  bool _quiet = true;
  bool _digest = true;

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'الإشعارات',
      children: [
        const SectionLabel('أبلغني عند'),
        _ChannelRow(
          label: 'طلب مراجعة',
          push: _push,
          email: _email,
          onPush: (v) => setState(() => _push = v),
          onEmail: (v) => setState(() => _email = v),
        ),
        _ChannelRow(
          label: 'فشل فحوصات CI',
          push: true,
          email: true,
          onPush: (v) {},
          onEmail: (v) {},
        ),
        _ChannelRow(
          label: 'تعليق على مهمتي',
          push: true,
          email: false,
          onPush: (v) {},
          onEmail: (v) {},
        ),
        const SizedBox(height: 16),
        const SectionLabel('ساعات الهدوء'),
        ToggleRow(
          title: 'ساعات الهدوء',
          subtitle: '10 م – 8 ص، ما عدا المهام العاجلة',
          value: _quiet,
          onChanged: (v) => setState(() => _quiet = v),
        ),
        ToggleRow(
          title: 'الملخص اليومي',
          subtitle: 'كل يوم عمل الساعة 9:00 ص',
          value: _digest,
          onChanged: (v) => setState(() => _digest = v),
        ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.label,
    required this.push,
    required this.email,
    required this.onPush,
    required this.onEmail,
  });

  final String label;
  final bool push;
  final bool email;
  final ValueChanged<bool> onPush;
  final ValueChanged<bool> onEmail;

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
          Expanded(child: Text(label)),
          const Icon(Icons.phone_iphone_rounded, size: 14, color: AppColors.textDim),
          const SizedBox(width: 4),
          Switch(value: push, onChanged: onPush),
          const SizedBox(width: 8),
          const Icon(Icons.email_outlined, size: 14, color: AppColors.textDim),
          const SizedBox(width: 4),
          Switch(value: email, onChanged: onEmail),
        ],
      ),
    );
  }
}

/// وضع التركيز — V3FocusMode.dc.html
@RoutePage()
class FocusModePage extends StatelessWidget {
  const FocusModePage({super.key});

  static const _rules = <(String, IconData, Color, bool)>[
    ('مهمة عاجلة', Icons.priority_high_rounded, AppColors.danger, false),
    ('إنتاج متوقف', Icons.warning_amber_rounded, AppColors.danger, false),
    ('@ من المدير', Icons.alternate_email_rounded, AppColors.warning, false),
    ('طلبات مراجعة عادية', Icons.rate_review_outlined, AppColors.textDim, true),
    ('تعليقات', Icons.chat_bubble_outline_rounded, AppColors.textDim, true),
    ('تحديثات المزامنة', Icons.sync_rounded, AppColors.textDim, true),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'وضع التركيز',
      subtitle: '7 إشعارات مؤجلة — ستصلك 11:00',
      children: [
        const HintBanner('يستثني المهمة العاجلة والإنتاج المتوقف ومن المدير.'),
        const SizedBox(height: 8),
        for (final (label, icon, color, deferred) in _rules)
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
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
                Text(
                  deferred ? 'يُؤجَّل' : 'يمر فورًا',
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        const SectionLabel('ضبط تلقائي يوميًا'),
        const SettingsTile(
          icon: Icons.schedule_rounded,
          title: 'من 9 إلى 12 · أيام العمل',
          subtitle: 'الإشعارات المؤجلة تُجمَّع وتُرسل بعد انتهاء الفترة',
          color: AppColors.accent,
        ),
        const SizedBox(height: 8),
        const HintBanner('ما يراه زملاؤك: «في وضع التركيز حتى 12:00» — لا يظهر كإجازة.'),
      ],
    );
  }
}

/// المساعدة وما الجديد — V3Help.dc.html
@RoutePage()
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _updates = <(String, String, String)>[
    ('v2.4', 'دمج PR من التطبيق', 'اسحب لليسار على أي مهمة في العمود المناسب.'),
    ('v2.3', 'خريطة المعرفة', 'شوف مين بس يعرف كل مجلد في الكود.'),
    ('v2.2', 'تقديرات ذكية', 'اقتراح نقاط مبني على مهامك السابقة.'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'المساعدة',
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'ابحث في المساعدة',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('ما الجديد'),
        for (final (version, title, description) in _updates)
          AppPanel(
            margin: const EdgeInsetsDirectional.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      version,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SettingsTile(
          icon: Icons.support_agent_rounded,
          title: 'تواصل مع الدعم',
          subtitle: 'نرد عادةً خلال ساعات العمل · الأحد–الخميس',
          color: AppColors.info,
          onTap: () {},
        ),
      ],
    );
  }
}

/// إنشاء مساحة عمل — V2Workspace.dc.html
@RoutePage()
class WorkspaceCreatePage extends StatefulWidget {
  const WorkspaceCreatePage({super.key});

  @override
  State<WorkspaceCreatePage> createState() => _WorkspaceCreatePageState();
}

class _WorkspaceCreatePageState extends State<WorkspaceCreatePage> {
  String _size = '2 – 10';

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'خطوة أخيرة',
      subtitle: 'أنشئ مساحة عمل لفريقك',
      children: [
        const HintBanner('مساحة العمل تجمع كل مشاريع الشركة والأعضاء والفواتير في مكان واحد.'),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            labelText: 'اسم الشركة أو الفريق',
            prefixText: '6dx.app/',
            hintText: 'my-company',
          ),
        ),
        const SizedBox(height: 16),
        const SectionLabel('حجم الفريق'),
        Wrap(
          spacing: 8,
          children: [
            for (final size in const ['فرد', '2 – 10', '11 – 50', '+50'])
              ChoiceChip(
                label: Text(size),
                selected: _size == size,
                onSelected: (_) => setState(() => _size = size),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const SectionLabel('ربط مؤسسة GitHub'),
        const SettingsTile(
          icon: Icons.business_rounded,
          title: 'ربط مؤسسة GitHub',
          subtitle: 'نقترح أعضاء المؤسسة عليك عند الدعوة',
          color: AppColors.accent,
          trailing: TextButton(onPressed: null, child: Text('ربط')),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () {}, child: const Text('إنشاء مساحة العمل')),
        const SizedBox(height: 8),
        TextButton(onPressed: () {}, child: const Text('لديّ دعوة لفريق موجود')),
      ],
    );
  }
}