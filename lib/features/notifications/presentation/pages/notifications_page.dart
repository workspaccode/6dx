import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

@RoutePage()
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(workspaceNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notifications),
        actions: [
          if (notifications.any((n) => n.unread))
            TextButton(
              onPressed: () {},
              child: const Text('تعليم الكل كمقروء'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'لا توجد إشعارات',
              message: 'ستصلك هنا تنبيهات المراجعات والتعليقات والفحوصات.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kindColor(item.kind).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(kindIcon(item.kind),
                        size: 20, color: kindColor(item.kind)),
                  ),
                  title: Row(
                    children: [
                      StatusBadge(
                        label: kindLabel(item.kind),
                        color: kindColor(item.kind),
                        dense: true,
                      ),
                      const SizedBox(width: 8),
                      if (item.unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.body),
                        if (item.at != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _relative(item.at!),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: item.actionLabel == null
                      ? null
                      : TextButton(
                          // An invite is the only action the app can complete
                          // today; everything else is informational.
                          onPressed: item.kind == 'invite'
                              ? () => context.push(AppRoutes.acceptInvite)
                              : null,
                          child: Text(item.actionLabel!),
                        ),
                );
              },
            ),
    );
  }

  static IconData kindIcon(String kind) => switch (kind) {
        'review' => Icons.rate_review_outlined,
        'checks' => Icons.check_circle_outline_rounded,
        'comment' => Icons.chat_bubble_outline_rounded,
        'invite' => Icons.group_add_outlined,
        _ => Icons.notifications_none_rounded,
      };

  static Color kindColor(String kind) => switch (kind) {
        'review' => AppColors.warning,
        'checks' => AppColors.success,
        'comment' => AppColors.info,
        'invite' => AppColors.purple,
        _ => AppColors.textMuted,
      };

  static String kindLabel(String kind) => switch (kind) {
        'review' => 'مراجعة',
        'checks' => 'فحوصات',
        'comment' => 'تعليق',
        'invite' => 'دعوة',
        _ => 'إشعار',
      };

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'أمس';
  }
}
