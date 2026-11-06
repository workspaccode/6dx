import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../workspace/domain/entities/workspace_snapshot.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// الأعضاء والصلاحيات
@RoutePage()
class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(workspaceMembersProvider);
    final invites = ref.watch(workspaceInvitesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('الأعضاء${members.isEmpty ? '' : ' · ${members.length}'}'),
      ),
      floatingActionButton: members.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              onPressed: () {},
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('+ دعوة'),
            ),
      body: members.isEmpty && invites.isEmpty
          ? const AppEmptyState(
              icon: Icons.group_outlined,
              title: 'لا يوجد أعضاء',
              message: 'ادعُ فريقك لعرض المشروع معك.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              children: [
                for (final member in members)
                  _MemberTile(
                    member: member,
                    onRemove: () => _showRemoveSheet(context, ref, member),
                  ),
                if (invites.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const SectionLabel('دعوات معلّقة'),
                  for (final invite in invites)
                    AppPanel(
                      margin: const EdgeInsetsDirectional.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.mail_outline_rounded,
                              color: AppColors.warning),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(invite.email),
                                Text(
                                  '${invite.role} · بانتظار القبول',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  void _showRemoveSheet(
    BuildContext context,
    WidgetRef ref,
    WorkspaceMember member,
  ) {
    final members = ref.read(workspaceMembersProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إزالة ${member.name} من المشروع؟',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('مهامه المفتوحة (${member.openTasks}) تنتقل إلى:',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final option in members.where((m) => m.id != member.id))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, size: 18),
                title: Text(option.name),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_off_outlined, size: 18),
              title: const Text('بدون مسؤول'),
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onRemove});

  final WorkspaceMember member;
  final VoidCallback onRemove;

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
          InitialsAvatar(
            name: member.initials,
            color: member.isOnline ? AppColors.accent : AppColors.info,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: Theme.of(context).textTheme.titleMedium),
                Text(member.role, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'change', child: Text('تغيير الصلاحية')),
              PopupMenuItem(value: 'remove', child: Text('إزالة من المشروع')),
            ],
            onSelected: (value) {
              if (value == 'remove') onRemove();
            },
          ),
        ],
      ),
    );
  }
}

/// دعوة الفريق
@RoutePage()
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  final _controller = TextEditingController();

  /// UI label → `member_role`. `owner` cannot be handed out by an invite
  /// (the RLS policy rejects it), so it is not offered.
  static const Map<String, String> _roles = {
    'مشاهد': 'viewer',
    'مطوّر': 'developer',
    'مراجِع': 'reviewer',
    'مدير': 'admin',
  };

  String _role = 'مطوّر';
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _emails => _controller.text
      .split(RegExp(r'[,\s\n]+'))
      .map((value) => value.trim())
      .where((value) => value.contains('@'))
      .toSet()
      .toList(growable: false);

  Future<void> _send() async {
    final emails = _emails;
    if (emails.isEmpty) {
      _showSnack('أدخل بريدًا إلكترونيًا صحيحًا');
      return;
    }

    setState(() => _sending = true);
    final role = _roles[_role]!;
    AppLogger.action('InvitePage', 'inviting ${emails.length} address(es) as $role');
    try {
      await ref.read(sendInvitesProvider).call(emails: emails, role: role);
      if (!mounted) return;
      _controller.clear();
      ref.invalidate(workspaceSnapshotProvider);
      _showSnack('تم إرسال ${emails.length} دعوة');
    } catch (error) {
      if (!mounted) return;
      AppLogger.action('InvitePage', 'invite failed', error);
      _showSnack(_describe(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// The server raises Postgres errors; show the ones a user can act on.
  String _describe(Object error) {
    final text = error.toString();
    if (text.contains('42501')) {
      return 'إرسال الدعوات يحتاج صلاحية مدير في مساحة العمل';
    }
    if (text.contains('23503')) {
      return 'بريد غير صالح';
    }
    return 'تعذّر إرسال الدعوات، حاول مرة أخرى';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final invites = ref.watch(workspaceInvitesProvider);

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
            hintText: 'name@example.com',
          ),
        ),
        const SizedBox(height: 8),
        const HintBanner('افصل بين العناوين بفاصلة، أو الصق قائمة كاملة.'),
        const SizedBox(height: 16),
        const SectionLabel('الصلاحية'),
        Wrap(
          spacing: 8,
          children: [
            for (final role in _roles.keys)
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
          value: false,
          onChanged: (_) {},
        ),
        if (invites.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionLabel('بانتظار القبول · تنتهي بعد 7 أيام'),
          for (final invite in invites)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline_rounded, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invite.email,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${invite.role} · أُرسلت أمس · لم تُفتح بعد',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton(onPressed: () {}, child: const Text('إعادة إرسال')),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.link_rounded),
          label: const Text('نسخ رابط دعوة'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _sending || _emails.isEmpty ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إرسال الدعوات'),
        ),
      ],
    );
  }
}
