import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// الأعضاء والصلاحيات — V2Members.dc.html
@RoutePage()
class MembersPage extends StatelessWidget {
  const MembersPage({super.key});

  static const _members = <(String, String, Color, String)>[
    ('أسامة', 'مالك', AppColors.accent, 'أس'),
    ('أحمد', 'مطوّر', AppColors.info, 'أح'),
    ('سارة', 'مراجِع', AppColors.purple, 'سا'),
    ('منى', 'مطوّر', AppColors.info, 'من'),
    ('عماد', 'مشاهد', AppColors.textMuted, 'عم'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'الأعضاء',
      subtitle: '5 أعضاء · دعوة واحدة معلّقة',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
        onPressed: () {},
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('+ دعوة'),
      ),
      children: [
        for (final (name, role, color, initials) in _members)
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
                InitialsAvatar(name: initials, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      Text(role, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'change', child: Text('تغيير الصلاحية')),
                    PopupMenuItem(value: 'remove', child: Text('إزالة من المشروع')),
                  ],
                  onSelected: (value) {
                    if (value == 'remove') _showRemoveSheet(context, name);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showRemoveSheet(BuildContext context, String member) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إزالة $member من المشروع؟',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('مهامه المفتوحة (4) تنتقل إلى:',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final option in const ['منى — 5 نقاط', 'سارة — 8 نقاط', 'بدون مسؤول'])
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, size: 18),
                title: Text(option),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.background,
                    ),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('إزالة'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// دعوة الفريق — Invite.dc.html
@RoutePage()
class InvitePage extends StatefulWidget {
  const InvitePage({super.key});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final _controller = TextEditingController();
  String _role = 'مطوّر';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      title: 'دعوة الفريق',
      subtitle: '1 · التفاصيل   2 · المستودع   3 · الفريق',
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني',
            hintText: 'omar@company.com, mona@company.com',
          ),
        ),
        const SizedBox(height: 8),
        const HintBanner('افصل بين العناوين بفاصلة، أو الصق قائمة كاملة.'),
        const SizedBox(height: 16),
        const SectionLabel('الصلاحية'),
        Wrap(
          spacing: 8,
          children: [
            for (final role in const ['مشاهد', 'مطوّر', 'مراجِع', 'مالك'])
              ChoiceChip(
                label: Text(role),
                selected: _role == role,
                onSelected: (_) => setState(() => _role = role),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ToggleRow(
          title: 'إضافتهم أيضًا للمستودع على GitHub',
          subtitle: 'acme/store-mobile · write',
          value: false,
          onChanged: (v) {},
        ),
        const SizedBox(height: 16),
        const SectionLabel('بانتظار القبول · تنتهي بعد 7 أيام'),
        _PendingInvite(
          email: 'mona@company.com',
          details: 'مطوّر · أُرسلت أمس · لم تُفتح بعد',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.link_rounded),
          label: const Text('نسخ رابط دعوة (لنطاق @company.com فقط)'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : () {},
          child: const Text('إرسال الدعوات'),
        ),
      ],
    );
  }
}

class _PendingInvite extends StatelessWidget {
  const _PendingInvite({required this.email, required this.details});

  final String email;
  final String details;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        children: [
          const Icon(Icons.mail_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(details, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('إعادة إرسال')),
        ],
      ),
    );
  }
}