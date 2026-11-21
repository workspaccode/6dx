import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../domain/group_models.dart';
import '../providers/group_providers.dart';
import '../widgets/group_widgets.dart';

/// `/invite/:inviteId` — "Ahmed invited you to «Power Board» as Technician".
///
/// Signed-out users reach it through /login?from=/invite/:id (the router keeps
/// the target), so a link from an e-mail survives the sign-in.
class InviteLinkPage extends ConsumerStatefulWidget {
  const InviteLinkPage({super.key, required this.inviteId});
  final String inviteId;

  @override
  ConsumerState<InviteLinkPage> createState() => _InviteLinkPageState();
}

class _InviteLinkPageState extends ConsumerState<InviteLinkPage> {
  bool _busy = false;

  Future<void> _accept(InviteDetails invite) async {
    setState(() => _busy = true);
    try {
      final groupId = await ref.read(groupsApiProvider).acceptInvite(invite.id);
      ref
        ..invalidate(groupsOverviewProvider)
        ..invalidate(pendingInvitesProvider)
        ..invalidate(workspaceSnapshotProvider);
      if (!mounted) return;
      if (groupId != null) {
        await ref.read(lastGroupIdProvider).set(groupId);
        if (mounted) context.go('/g/$groupId/welcome');
      } else {
        context.go('/groups');
      }
    } catch (error) {
      if (mounted) showSnack(context, describeError(error, fallback: 'تعذّر قبول الدعوة.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(InviteDetails invite) async {
    setState(() => _busy = true);
    try {
      await ref.read(groupsApiProvider).declineInvite(invite.id);
      ref.invalidate(pendingInvitesProvider);
      if (mounted) context.go('/groups');
    } catch (error) {
      if (mounted) showSnack(context, describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = ref.watch(inviteDetailsProvider(widget.inviteId));
    return AppScreen(
      title: 'دعوة',
      children: [
        invite.when(
          loading: () => const AppLoadingView(),
          error: (error, _) {
            final otherEmail =
                error is ServerException && error.message.contains('لبريد تاني');
            return AppEmptyState(
              icon: otherEmail ? Icons.switch_account_outlined : Icons.link_off_rounded,
              title: otherEmail ? 'الدعوة دي مش لحسابك' : 'مش لاقيين الدعوة',
              message: describeError(error, fallback: 'الرابط غلط أو الدعوة اتلغت.'),
              action: otherEmail
                  ? OutlinedButton(
                      onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
                      child: const Text('بدّل الحساب'),
                    )
                  : FilledButton(
                      onPressed: () => context.go('/groups'),
                      child: const Text('مجموعاتي'),
                    ),
            );
          },
          data: (details) {
            if (details.alreadyMember && details.groupId != null) {
              return AppEmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: 'انت عضو في ${details.groupName ?? 'المجموعة'} بالفعل',
                action: FilledButton(
                  onPressed: () => context.go('/g/${details.groupId}/home'),
                  child: const Text('افتح المجموعة'),
                ),
              );
            }
            if (!details.isPending) {
              final expired = details.status == 'expired';
              return AppEmptyState(
                icon: Icons.timer_off_outlined,
                title: expired ? 'الدعوة انتهت صلاحيتها' : 'الدعوة دي مبقتش متاحة',
                message: expired
                    ? 'اطلب من ${details.invitedBy ?? 'قائد المجموعة'} يبعتلك دعوة جديدة.'
                    : null,
                action: FilledButton(
                  onPressed: () => context.go('/groups'),
                  child: const Text('مجموعاتي'),
                ),
              );
            }
            return _InviteCard(
              invite: details,
              busy: _busy,
              onAccept: () => _accept(details),
              onDecline: () => _decline(details),
            );
          },
        ),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final InviteDetails invite;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final hardware = invite.groupType == GroupType.hardware;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Center(
          child: InitialsAvatar(
            name: invite.groupName ?? invite.workspaceName,
            color: hardware ? AppColors.warning : AppColors.info,
            size: 72,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${invite.invitedBy ?? 'حد من الفريق'} دعاك',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          invite.groupName ?? invite.workspaceName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            GroupTypeBadge(invite.groupType),
            StatusBadgeChip(label: invite.roleLabel, color: AppColors.accent),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'مساحة العمل: ${invite.workspaceName}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onAccept,
          child: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('قبول الدعوة'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: busy ? null : onDecline, child: const Text('رفض')),
      ],
    );
  }
}
