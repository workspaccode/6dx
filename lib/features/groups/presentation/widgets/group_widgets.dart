import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/group_models.dart';
import '../providers/group_providers.dart';

/// Human message for an API failure.
String describeError(Object error, {String fallback = 'حصل خطأ، حاول تاني.'}) {
  if (error is ServerException && error.message.isNotEmpty) return error.message;
  if (error is UnauthorizedException) return 'انتهت الجلسة، سجّل الدخول تاني.';
  return fallback;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Wraps every group screen: loads the caller's access, and renders the
/// not-a-member / missing-capability states instead of the screen.
///
/// This is the UX half of the guard; the API enforces the same capability on
/// every request.
class GroupScope extends ConsumerWidget {
  const GroupScope({
    super.key,
    required this.gid,
    required this.builder,
    this.requires,
  });

  final String gid;
  final String? requires;
  final Widget Function(BuildContext context, GroupAccess access) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(groupAccessProvider(gid));
    return access.when(
      loading: () => const Scaffold(body: AppLoadingView()),
      error: (error, _) => AppScreen(
        title: 'المجموعة',
        children: [
          AppEmptyState(
            icon: Icons.group_off_outlined,
            title: 'مش قادر تفتح المجموعة دي',
            message: describeError(error, fallback: 'تعذّر تحميل المجموعة.'),
            action: Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => ref.invalidate(groupAccessProvider(gid)),
                  child: const Text('إعادة المحاولة'),
                ),
                FilledButton(
                  onPressed: () => context.go('/groups'),
                  child: const Text('مجموعاتي'),
                ),
              ],
            ),
          ),
        ],
      ),
      data: (a) {
        final needed = requires;
        if (needed != null && !a.can(needed)) {
          return AppScreen(
            title: a.name,
            children: [
              AppEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'الصفحة دي مش متاحة لدورك',
                message: 'دورك في المجموعة: ${a.roleLabel}',
                action: FilledButton(
                  onPressed: () => context.go('/g/$gid/home'),
                  child: const Text('الرجوع للمجموعة'),
                ),
              ),
            ],
          );
        }
        return builder(context, a);
      },
    );
  }
}

class GroupTypeBadge extends StatelessWidget {
  const GroupTypeBadge(this.type, {super.key});
  final GroupType type;

  @override
  Widget build(BuildContext context) => StatusBadgeChip(
        label: type.label,
        color: type == GroupType.hardware ? AppColors.warning : AppColors.info,
      );
}

/// AppBar action: current group name; opens the switcher.
class GroupSwitcherButton extends ConsumerWidget {
  const GroupSwitcherButton({super.key, this.currentGroupId});
  final String? currentGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'تبديل المجموعة',
      icon: const Icon(Icons.workspaces_outline),
      onPressed: () => showGroupSwitcher(context, currentGroupId: currentGroupId),
    );
  }
}

Future<void> showGroupSwitcher(BuildContext context, {String? currentGroupId}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _GroupSwitcherSheet(currentGroupId: currentGroupId),
  );
}

class _GroupSwitcherSheet extends ConsumerWidget {
  const _GroupSwitcherSheet({this.currentGroupId});
  final String? currentGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(groupsOverviewProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: overview.when(
          loading: () => const SizedBox(height: 160, child: AppLoadingView()),
          error: (error, _) => AppErrorView(
            message: describeError(error),
            onRetry: () => ref.invalidate(groupsOverviewProvider),
          ),
          data: (data) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('مجموعاتي', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '${data.plan.usedGroups} / ${data.plan.maxGroups}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final group in data.active)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: InitialsAvatar(
                          name: group.name,
                          color: group.type == GroupType.hardware
                              ? AppColors.warning
                              : AppColors.info,
                        ),
                        title: Text(group.name),
                        subtitle: Text('${group.type.label} · ${group.roleLabel}'),
                        trailing: group.id == currentGroupId
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.accent)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.go('/g/${group.id}/home');
                        },
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_rounded),
                title: const Text('مجموعة جديدة'),
                enabled: data.plan.canAddGroup,
                subtitle: data.plan.canAddGroup
                    ? null
                    : const Text('وصلت لحد الخطة — أرشف مجموعة أو رقّي الخطة'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/groups/new');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.grid_view_rounded),
                title: const Text('كل المجموعات'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/groups');
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.home_outlined),
                title: const Text('الرئيسية'),
                subtitle: const Text('المهام والمراجعات والحساب'),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/home');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
