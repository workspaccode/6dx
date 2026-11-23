import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../workspace/domain/entities/workspace_snapshot.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/feedback.dart';
import '../../../groups/domain/group_models.dart';
import '../../../groups/presentation/providers/active_group.dart';
import '../../../groups/presentation/providers/group_providers.dart';
import '../providers/project_providers.dart';

/// إعدادات المشروع
class ProjectSettingsPage extends ConsumerWidget {
  const ProjectSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(workspaceMembersProvider);
    final repos = ref.watch(workspaceRepositoriesProvider);

    return AppScreen(
      title: 'إعدادات المشروع',
      subtitle: 'المشروع الحالي',
      children: [
        SettingsTile(
          icon: Icons.group_outlined,
          title: 'الأعضاء والصلاحيات',
          subtitle: '${members.length} أعضاء',
          onTap: () => context.push(AppRoutes.members),
        ),
        SettingsTile(
          icon: Icons.sync_outlined,
          title: 'المستودعات والمزامنة',
          subtitle: '${repos.length} مستودع مربوط',
          onTap: () => context.push(AppRoutes.syncSettings),
        ),
        SettingsTile(
          icon: Icons.label_outline_rounded,
          title: 'الـ Labels',
          onTap: () => context.push(AppRoutes.labels),
        ),
        SettingsTile(
          icon: Icons.notifications_none_rounded,
          title: 'إشعارات المشروع',
          onTap: () => context.push(AppRoutes.integrations),
        ),
        // The board columns are the active group's task states.
        if (_groupId(ref) case final gid?)
          SettingsTile(
            icon: Icons.view_column_outlined,
            title: 'حالات المهام (أعمدة اللوحة)',
            subtitle: 'الأسماء والألوان والترتيب',
            onTap: () => context.push('/g/$gid/settings/workflow'),
          ),
        const SizedBox(height: 20),
        SettingsTile(
          icon: Icons.history_rounded,
          title: 'سجل النشاط',
          color: AppColors.info,
          onTap: () => context.push(AppRoutes.activityLog),
        ),
        SettingsTile(
          icon: Icons.archive_outlined,
          title: 'أرشفة مشروع',
          color: AppColors.danger,
          onTap: () => context.push(AppRoutes.archiveProject),
        ),
      ],
    );
  }
}

/// The active group, else the workspace's default group.
String? _groupId(WidgetRef ref) {
  final active = ref.watch(activeGroupProvider);
  if (active != null) return active;
  for (final g in ref.watch(groupsOverviewProvider).value?.groups ?? const <GroupSummary>[]) {
    if (g.isDefault) return g.id;
  }
  return null;
}

/// المستودعات والمزامنة
class SyncSettingsPage extends ConsumerWidget {
  const SyncSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repos = ref.watch(workspaceRepositoriesProvider);
    final snapshot = ref.watch(workspaceSnapshotProvider).value;

    return AppScreen(
      title: 'المستودعات والمزامنة',
      children: [
        const SectionLabel('المستودعات المربوطة'),
        if (repos.isEmpty)
          const AppEmptyState(
            icon: Icons.code_off_rounded,
            title: 'لا توجد مستودعات مربوطة',
            message: 'اربط مستودعًا لبدء استيراد الـ Issues.',
          )
        else
          for (final repo in repos) _RepoTile(repo: repo),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.connectRepository),
          icon: const Icon(Icons.add_rounded),
          label: const Text('+ ربط مستودع آخر'),
        ),
        const SizedBox(height: 20),
        const SectionLabel('إذا عُدّلت المهمة في المكانين، أيّ تعديل يُعتمد؟'),
        const HintBanner('GitHub هو المصدر — تعديلاته تلغي تعديل التطبيق.'),
        const SizedBox(height: 16),
        if (snapshot?.apiRateLimit != null)
          SettingsTile(
            icon: Icons.speed_rounded,
            title: 'حد الـ API المتبقي',
            subtitle:
                '${snapshot!.apiRateLimit!.used} / ${snapshot.apiRateLimit!.limit}',
            color: AppColors.warning,
          ),
      ],
    );
  }
}

class _RepoTile extends StatelessWidget {
  const _RepoTile({required this.repo});

  final LinkedRepository repo;

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
          const Icon(Icons.code_rounded, size: 18, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repo.fullName,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${repo.branch} · ${repo.language ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// إدارة الـ Labels
class LabelsPage extends ConsumerWidget {
  const LabelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(workspaceLabelsProvider);

    return AppScreen(
      title: 'الـ Labels',
      subtitle: 'متزامنة مع GitHub',
      children: [
        if (labels.isEmpty)
          const AppEmptyState(
            icon: Icons.label_outline_rounded,
            title: 'لا توجد Labels',
            message: 'أضف Label أو استوردها من GitHub.',
          )
        else
          for (final label in labels)
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
                    decoration: BoxDecoration(
                      color: Color(label.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label.name)),
                  const Icon(Icons.drag_indicator_rounded, color: AppColors.textDim),
                ],
              ),
            ),
        const SizedBox(height: 12),
        const HintBanner('الـ labels بتيجي من GitHub مع المزامنة.'),
      ],
    );
  }
}

/// Slack وDiscord
class IntegrationsPage extends ConsumerWidget {
  const IntegrationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrations = ref.watch(workspaceIntegrationsProvider);

    return AppScreen(
      title: 'قنوات الفريق',
      subtitle: 'أرسل أحداث المشروع إلى حيث يتحدث فريقك',
      children: [
        if (integrations.isEmpty)
          const AppEmptyState(
            icon: Icons.hub_outlined,
            title: 'لا توجد قنوات',
            message: 'اربط Slack أو Discord لمتابعة النشاط.',
          )
        else
          for (final integration in integrations)
            AppPanel(
              margin: const EdgeInsetsDirectional.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_icon(integration.kind), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(integration.name,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),

                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    integration.connected
                        ? 'متصل${integration.workspace == null ? '' : ' · ${integration.workspace}'}'
                        : integration.comingSoon
                            ? 'قريبًا'
                            : 'غير متصل',
                    style: TextStyle(
                      color: integration.connected
                          ? AppColors.success
                          : integration.comingSoon
                              ? AppColors.info
                              : AppColors.textDim,
                      fontSize: 12,
                    ),
                  ),
                  if (integration.channels.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('القناة:', style: TextStyle(fontSize: 12)),
                    for (final channel in integration.channels)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tag_rounded, size: 16),
                        title: Text(
                          channel,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontFamily: 'JetBrainsMono'),
                        ),
                        trailing: const Icon(Icons.check_circle_rounded,
                            color: AppColors.accent, size: 18),
                      ),
                    const Text('أرسل عند:', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final event in integration.events)
                          Chip(label: Text(event)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }

  static IconData _icon(String kind) => switch (kind) {
        'discord' => Icons.sports_esports_outlined,
        'teams' => Icons.groups_outlined,
        _ => Icons.chat_bubble_outline_rounded,
      };
}

/// سجل النشاط
class ActivityLogPage extends ConsumerWidget {
  const ActivityLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(workspaceActivityProvider);

    return AppScreen(
      title: 'سجل النشاط',
      subtitle: 'يُحفظ 12 شهرًا',
      children: [
        if (events.isEmpty)
          const AppEmptyState(
            icon: Icons.history_rounded,
            title: 'لا يوجد نشاط',
            message: 'ستظهر هنا كل أحداث المشروع.',
          )
        else
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _color(event.type).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon(event.type), size: 15, color: _color(event.type)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.text,
                            style: Theme.of(context).textTheme.bodyMedium),
                        if (event.actor != null)
                          Text(event.actor!,
                              style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static IconData _icon(String type) => switch (type) {
        'merged' => Icons.merge_rounded,
        'comment' => Icons.comment_outlined,
        'sync' => Icons.sync_rounded,
        'member_joined' => Icons.person_add_alt_1_outlined,
        'deleted' => Icons.delete_outline_rounded,
        _ => Icons.edit_outlined,
      };

  static Color _color(String type) => switch (type) {
        'merged' => AppColors.success,
        'comment' => AppColors.info,
        'sync' => AppColors.textMuted,
        'member_joined' => AppColors.purple,
        'deleted' => AppColors.danger,
        _ => AppColors.warning,
      };
}

/// أرشفة أو حذف المشروع
class ArchivePage extends ConsumerWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = (ref.watch(projectsNotifierProvider).value ?? const [])
        .where((p) => !p.isArchived)
        .toList();
    return AppScreen(
      title: 'أرشفة مشروع',
      children: [
        const HintBanner(
          'المشروع بيختفي من قايمة المشاريع النشطة. المهام والسجل بيفضلوا محفوظين، وبيظهر تحت «المؤرشفة».',
        ),
        const SizedBox(height: 12),
        if (projects.isEmpty) const AppEmptyState(icon: Icons.folder_off_outlined, title: 'مفيش مشاريع نشطة'),
        for (final project in projects)
          SettingsTile(
            icon: Icons.folder_outlined,
            title: project.name,
            trailing: TextButton(
              onPressed: () => _archive(context, ref, project.id, project.name),
              child: const Text('أرشفة'),
            ),
          ),
      ],
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref, String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text('أرشفة «$name»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('أرشفة')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result = await ref.read(archiveProjectProvider).call(id);
    if (!context.mounted) return;
    if (result.failureOrNull case final failure?) {
      showSnack(context, failure.message);
      return;
    }
    ref.invalidate(projectsNotifierProvider);
    showSnack(context, 'المشروع اتأرشف');
  }
}
