import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/group_models.dart';
import '../providers/group_providers.dart';
import '../widgets/group_widgets.dart';
import '../providers/active_group.dart';

/// `/g/:gid/members`
class GroupMembersPage extends ConsumerWidget {
  const GroupMembersPage({super.key, required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupScope(
      gid: gid,
      builder: (context, access) {
        final members = ref.watch(groupMembersProvider(gid));
        final canManage = access.can(Caps.manageMembers);

        return AppScreen(
          title: 'الأعضاء',
          subtitle: access.name,
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/g/$gid/members/invite'),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('دعوة'),
                )
              : null,
          children: [
            members.when(
              loading: () => const AppLoadingView(),
              error: (error, _) => AppErrorView(
                message: describeError(error),
                onRetry: () => ref.invalidate(groupMembersProvider(gid)),
              ),
              data: (list) => Column(
                children: [
                  for (final member in list)
                    _MemberTile(
                      member: member,
                      access: access,
                      isMe: member.uid == access.uid,
                      onTap: canManage && member.groupRole != GroupRole.lead
                          ? () => _editMember(context, ref, access, member)
                          : null,
                    ),
                ],
              ),
            ),
            if (access.isMember && access.groupRole != GroupRole.lead) ...[
              const SizedBox(height: 16),
              SettingsTile(
                icon: Icons.logout_rounded,
                title: 'مغادرة المجموعة',
                color: AppColors.danger,
                onTap: () => _leave(context, ref, access.uid),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, String myUid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: const Text('تسيب المجموعة؟ هتحتاج دعوة جديدة علشان ترجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('مغادرة')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(groupsApiProvider).removeMember(gid, myUid);
      ref.read(activeGroupProvider.notifier).clear();
      ref.invalidate(groupsOverviewProvider);
      if (context.mounted) context.go('/groups');
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(error));
    }
  }

  Future<void> _editMember(
    BuildContext context,
    WidgetRef ref,
    GroupAccess access,
    GroupMember member,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _EditMemberSheet(gid: gid, access: access, member: member),
    );
    if (changed == true) ref.invalidate(groupMembersProvider(gid));
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.access,
    required this.isMe,
    this.onTap,
  });

  final GroupMember member;
  final GroupAccess access;
  final bool isMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (member.groupRole) {
      GroupRole.lead => AppColors.accent,
      GroupRole.admin => AppColors.info,
      GroupRole.guest => AppColors.purple,
      GroupRole.member => AppColors.textMuted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppPanel(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: InitialsAvatar(name: member.name, color: roleColor),
          title: Text(isMe ? '${member.name} (انت)' : member.name),
          subtitle: Text([
            if (member.groupRole != GroupRole.member) member.groupRole.label,
            if (member.groupRole != GroupRole.guest)
              functionalRoleLabel(access.type, member.functionalRole),
            if (member.email != null) member.email!,
          ].join(' · ')),
          trailing: onTap == null ? null : const Icon(Icons.more_horiz_rounded),
        ),
      ),
    );
  }
}

class _EditMemberSheet extends ConsumerStatefulWidget {
  const _EditMemberSheet({required this.gid, required this.access, required this.member});
  final String gid;
  final GroupAccess access;
  final GroupMember member;

  @override
  ConsumerState<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends ConsumerState<_EditMemberSheet> {
  late GroupRole _role = widget.member.groupRole;
  late String _functional = widget.member.functionalRole;
  bool _busy = false;

  bool get _isLead => widget.access.groupRole == GroupRole.lead || !widget.access.isMember;

  /// An assistant manages members and guests only (the API says the same).
  List<GroupRole> get _roles => [
        if (_isLead) GroupRole.admin,
        GroupRole.member,
        GroupRole.guest,
      ];

  bool get _canTouch => _isLead || widget.member.groupRole != GroupRole.admin;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(groupsApiProvider).updateMember(
            widget.gid,
            widget.member.uid,
            groupRole: _role,
            functionalRole: _role == GroupRole.guest ? 'client' : _functional,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showSnack(context, describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ref.read(groupsApiProvider).removeMember(widget.gid, widget.member.uid);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showSnack(context, describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.access.type;
    final options = Map.of(functionalRoles[type]!)..remove('client');
    if (_role != GroupRole.guest && !options.containsKey(_functional)) {
      _functional = options.keys.first;
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.member.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (!_canTouch)
              const HintBanner('تعديل أو إزالة مساعد خاص بقائد المجموعة.')
            else ...[
              Text('الدور الإداري', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final role in _roles)
                    ChoiceChip(
                      label: Text(role.label),
                      selected: _role == role,
                      onSelected: _busy ? null : (_) => setState(() => _role = role),
                    ),
                ],
              ),
              if (_role != GroupRole.guest) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _functional,
                  decoration: const InputDecoration(labelText: 'الدور الوظيفي'),
                  items: [
                    for (final e in options.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: _busy ? null : (value) => setState(() => _functional = value!),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _save, child: const Text('حفظ')),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _remove,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('إزالة من المجموعة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `/g/:gid/members/invite` — e-mails + preset roles.
class GroupInvitePage extends ConsumerStatefulWidget {
  const GroupInvitePage({super.key, required this.gid});
  final String gid;

  @override
  ConsumerState<GroupInvitePage> createState() => _GroupInvitePageState();
}

class _GroupInvitePageState extends ConsumerState<GroupInvitePage> {
  final _emails = TextEditingController();
  GroupRole _role = GroupRole.member;
  String? _functional;
  bool _busy = false;

  static const maxPerRequest = 50;

  @override
  void dispose() {
    _emails.dispose();
    super.dispose();
  }

  List<String> _parse() => _emails.text
      .split(RegExp(r'[\s,;]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _send(GroupAccess access) async {
    final emails = _parse();
    if (emails.isEmpty) {
      showSnack(context, 'اكتب إيميل واحد على الأقل');
      return;
    }
    if (emails.length > maxPerRequest) {
      showSnack(context, 'أقصى عدد في المرة الواحدة $maxPerRequest إيميل');
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await ref.read(groupsApiProvider).invite(
            widget.gid,
            emails: emails,
            groupRole: _role,
            functionalRole: _role == GroupRole.guest
                ? 'client'
                : (_functional ?? functionalRoles[access.type]!.keys.first),
          );
      if (!mounted) return;
      showSnack(context, 'اتبعتت $created دعوة');
      context.pop();
    } catch (error) {
      if (mounted) showSnack(context, describeError(error, fallback: 'تعذّر إرسال الدعوات.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GroupScope(
      gid: widget.gid,
      requires: Caps.manageMembers,
      builder: (context, access) {
        final isLead = access.groupRole == GroupRole.lead || !access.isMember;
        final options = Map.of(functionalRoles[access.type]!)..remove('client');
        _functional ??= access.type == GroupType.hardware ? 'electrical' : 'developer';
        final count = _parse().length;

        return AppScreen(
          title: 'دعوة للمجموعة',
          subtitle: access.name,
          children: [
            TextField(
              controller: _emails,
              minLines: 3,
              maxLines: 8,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'الإيميلات',
                hintText: 'إيميل في كل سطر، أو مفصولة بفاصلة',
                helperText: '$count / $maxPerRequest',
              ),
            ),
            const SizedBox(height: 16),
            Text('الدور الإداري', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final role in [if (isLead) GroupRole.admin, GroupRole.member, GroupRole.guest])
                  ChoiceChip(
                    label: Text(role.label),
                    selected: _role == role,
                    onSelected: _busy ? null : (_) => setState(() => _role = role),
                  ),
              ],
            ),
            if (_role == GroupRole.guest)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: HintBanner('الضيف (العميل) بيقرا بس، ومابيشوفش إيميلات الفريق ولا الأسعار.'),
              )
            else ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _functional,
                decoration: const InputDecoration(labelText: 'الدور الوظيفي'),
                items: [
                  for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: _busy ? null : (value) => setState(() => _functional = value),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy || count == 0 ? null : () => _send(access),
              child: Text(count <= 1 ? 'إرسال الدعوة' : 'إرسال $count دعوات'),
            ),
          ],
        );
      },
    );
  }
}
