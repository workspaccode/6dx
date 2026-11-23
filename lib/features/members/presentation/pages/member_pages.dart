import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../workspace/domain/entities/workspace_snapshot.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/feedback.dart';
import '../../../../routes/app_router.dart';
import '../../../workspace/presentation/providers/workspace_actions.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../workspace/presentation/widgets/snapshot_status.dart';

/// الأعضاء والصلاحيات
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
              onPressed: () => context.push(AppRoutes.invite),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('+ دعوة'),
            ),
      body: Column(children: [
        const SnapshotStatus(),
        Expanded(child: members.isEmpty && invites.isEmpty
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
                    onRemove: () => _remove(context, ref, member),
                    onChangeRole: () => _changeRole(context, ref, member),
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
            )),
      ]),
    );
  }

  /// The server decides who may change roles or remove (owner / admins,
  /// never the owner row); a refusal comes back as its message.
  Future<void> _remove(BuildContext context, WidgetRef ref, WorkspaceMember member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('إزالة ${member.name}؟'),
        content: Text(member.openTasks > 0
            ? 'عنده ${member.openTasks} مهمة مفتوحة هتفضل من غير مسؤول.'
            : 'هيخرج من مساحة العمل وكل مجموعاتها.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runAction(context, () => ref.read(workspaceActionsProvider).removeMember(member.id),
        done: 'اتشال');
  }

  Future<void> _changeRole(BuildContext context, WidgetRef ref, WorkspaceMember member) async {
    const roles = {'admin': 'مدير', 'developer': 'مطوّر', 'reviewer': 'مراجِع', 'viewer': 'مشاهد (عميل)'};
    final role = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in roles.entries)
            ListTile(
              title: Text(e.value),
              selected: e.key == member.role,
              onTap: () => Navigator.of(sheet).pop(e.key),
            ),
        ]),
      ),
    );
    if (role == null || role == member.role || !context.mounted) return;
    await runAction(context, () => ref.read(workspaceActionsProvider).changeMemberRole(member.id, role),
        done: 'الصلاحية اتغيرت');
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onRemove, required this.onChangeRole});

  final WorkspaceMember member;
  final VoidCallback onRemove;
  final VoidCallback onChangeRole;

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
              PopupMenuItem(value: 'remove', child: Text('إزالة من مساحة العمل')),
            ],
            onSelected: (value) {
              if (value == 'remove') onRemove();
              if (value == 'change') onChangeRole();
            },
          ),
        ],
      ),
    );
  }
}

/// دعوة الفريق
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

  /// The API answers with a ready-to-show Arabic message; anything else gets
  /// the generic one.
  String _describe(Object error) {
    if (error is ServerException && error.message.isNotEmpty) {
      return error.message;
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
