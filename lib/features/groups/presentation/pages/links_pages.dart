import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../data/links_api.dart';
import '../../domain/group_models.dart';
import '../../domain/hardware_models.dart';
import '../providers/group_providers.dart';
import '../widgets/group_widgets.dart';
import '../widgets/hardware_widgets.dart';

Future<bool> _linkRun(BuildContext context, WidgetRef ref, Future<void> Function(LinksApi api) action,
    {String? done}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final api = ref.read(linksApiProvider);
  try {
    await action(api);
    container.invalidate(projectLinksProvider);
    container.invalidate(linkSummaryProvider);
    if (done != null && context.mounted) showSnack(context, done);
    return true;
  } catch (error) {
    if (context.mounted) showSnack(context, describeError(error));
    return false;
  }
}

/// `/g/:gid/p/:pid/links` — this project's links with projects of other
/// groups (the exceptional case): requests, approvals, revokes.
class ProjectLinksPage extends ConsumerWidget {
  const ProjectLinksPage({super.key, required this.gid, required this.pid});
  final String gid;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupScope(
      gid: gid,
      builder: (context, access) {
        if (access.groupRole == GroupRole.guest) {
          return const AppScreen(
            title: 'المشاريع المرتبطة',
            children: [AppEmptyState(icon: Icons.lock_outline_rounded, title: 'مش متاحة لدورك')],
          );
        }
        final links = ref.watch(projectLinksProvider((gid: gid, pid: pid)));
        return links.when(
          skipLoadingOnReload: true,
          loading: () => const Scaffold(body: AppLoadingView()),
          error: (error, _) => AppScreen(title: 'المشاريع المرتبطة', children: [AppErrorView(message: describeError(error))]),
          data: (data) => AppScreen(
            title: 'المشاريع المرتبطة',
            subtitle: access.name,
            floatingActionButton: data.canManage
                ? FloatingActionButton.extended(
                    onPressed: () => _request(context, ref),
                    icon: const Icon(Icons.add_link_rounded),
                    label: const Text('طلب ربط'),
                  )
                : null,
            children: [
              const HintBanner(
                'الربط بيدّي ملخص بس: المرحلة، والـ BOM المعتمد، وتوافق الـ firmware، وتقدم المهام. '
                'مش عضوية: مهام وأسعار وأعضاء المشروع التاني بيفضلوا عنده.',
              ),
              const SizedBox(height: 12),
              if (data.links.isEmpty) const AppEmptyState(icon: Icons.link_off_rounded, title: 'مفيش مشاريع مرتبطة'),
              for (final l in data.links)
                SettingsTile(
                  icon: l.other.isHardware ? Icons.memory_rounded : Icons.code_rounded,
                  color: l.isActive ? AppColors.success : AppColors.warning,
                  title: '${l.other.projectName} · ${l.other.groupName}',
                  subtitle: [
                    if (l.isActive) 'مربوط',
                    if (l.isRequested) l.outgoing ? 'مستني موافقتهم' : 'طالبين الربط معاك',
                    if (l.note != null) l.note!,
                  ].join(' · '),
                  onTap: l.isActive ? () => context.push('/g/$gid/p/$pid/links/${l.id}') : null,
                  trailing: data.canManage
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          if (l.isRequested && !l.outgoing)
                            TextButton(
                              onPressed: () => _linkRun(context, ref, (api) => api.approve(gid, pid, l.id), done: 'اتربطوا'),
                              child: const Text('موافقة'),
                            ),
                          IconButton(
                            tooltip: l.isActive ? 'إلغاء الربط' : 'رفض / سحب الطلب',
                            icon: const Icon(Icons.link_off_rounded),
                            onPressed: () => _linkRun(context, ref, (api) => api.revoke(gid, pid, l.id), done: 'اتلغى'),
                          ),
                        ])
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    List<LinkedProjectRef> candidates;
    try {
      candidates = await ref.read(linksApiProvider).candidates(gid, pid);
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(error));
      return;
    }
    if (!context.mounted) return;
    final target = await pickOne<LinkedProjectRef>(context,
        title: 'المشروع اللي عايز تربط بيه',
        options: candidates,
        label: (p) => p.projectName,
        subtitle: (p) => '${p.groupName} · ${p.isHardware ? 'Hardware' : 'Software'}');
    if (target == null || !context.mounted) return;
    final values = await askForm(context, title: 'طلب ربط مع ${target.projectName}', submit: 'إرسال الطلب', fields: const [
      FormFieldSpec('note', 'ليه؟ (هيظهر للمجموعة التانية)', maxLength: 500),
    ]);
    if (values == null || !context.mounted) return;
    await _linkRun(context, ref, (api) => api.request(gid, pid, toProjectId: target.projectId, note: values['note']),
        done: 'الطلب اتبعت. مستني موافقة المجموعة التانية.');
  }
}

/// `/g/:gid/p/:pid/links/:lid` — the other project's summary and the
/// dependencies between the two.
class LinkSummaryPage extends ConsumerWidget {
  const LinkSummaryPage({super.key, required this.gid, required this.pid, required this.lid});
  final String gid;
  final String pid;
  final String lid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(linkSummaryProvider((gid: gid, pid: pid, id: lid)));
    return summary.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: AppLoadingView()),
      error: (error, _) => AppScreen(title: 'مشروع مرتبط', children: [AppErrorView(message: describeError(error))]),
      data: (s) => AppScreen(
        title: s.projectName,
        subtitle: '${s.groupName} · ${s.groupType == 'hardware' ? 'Hardware' : 'Software'}',
        children: [
          Row(children: [
            StatTile(value: '${s.openTasks}', label: 'مفتوحة'),
            const SizedBox(width: 8),
            StatTile(value: '${s.doneTasks}', label: 'تمت', color: AppColors.success),
            if (s.releasedBom != null) ...[
              const SizedBox(width: 8),
              StatTile(value: s.releasedBom!, label: 'آخر BOM', color: AppColors.info),
            ],
          ]),
          if (s.phases.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionLabel('المراحل'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in s.phases)
                StatusChip('${p.name} · ${phaseStatusLabels[p.status] ?? p.status}', color: phaseColor(p.status)),
            ]),
          ],
          if (s.firmware.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionLabel('توافق الـ Firmware'),
            for (final f in s.firmware)
              SettingsTile(icon: Icons.memory_rounded, title: '${f.tag} ↔ BOM rev ${f.bomRev}'),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: SectionLabel('الاعتماديات بين المشروعين')),
            if (s.canEdit)
              TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('اعتماد'),
                onPressed: () => _addDependency(context, ref),
              ),
          ]),
          if (s.dependencies.isEmpty) const HintBanner('مفيش مهام مستنية مهام من المشروع التاني.'),
          for (final d in s.dependencies)
            SettingsTile(
              icon: d.dependsOn.done ? Icons.check_circle_outline : Icons.hourglass_top_rounded,
              color: d.dependsOn.done ? AppColors.success : AppColors.warning,
              title: '${d.waiting.title} ← ${d.dependsOn.title}',
              subtitle: [
                d.waiting.mine ? 'مهمتنا مستنية' : 'مهمتهم مستنية',
                d.dependsOn.done ? 'اللي مستنيينها خلصت' : 'لسه',
              ].join(' · '),
              trailing: s.canEdit && d.waiting.mine
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _linkRun(context, ref, (api) => api.removeDependency(gid, pid, lid, d.id)),
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _addDependency(BuildContext context, WidgetRef ref) async {
    final mine = await ref.read(groupTasksProvider((gid: gid, pid: pid)).future);
    if (!context.mounted) return;
    final waiting = await pickOne<GroupTask>(context,
        title: 'مهمتنا اللي مستنية', options: mine.where((t) => t.status != 'done').toList(), label: (t) => t.title);
    if (waiting == null || !context.mounted) return;
    List<LinkTaskRef> theirs;
    try {
      theirs = await ref.read(linksApiProvider).otherTasks(gid, pid, lid);
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(error));
      return;
    }
    if (!context.mounted) return;
    final dependsOn = await pickOne<LinkTaskRef>(context,
        title: 'مستنية أنهي مهمة عندهم؟', options: theirs, label: (t) => t.title);
    if (dependsOn == null || !context.mounted) return;
    await _linkRun(context, ref,
        (api) => api.addDependency(gid, pid, lid, taskId: waiting.id, dependsOn: dependsOn.taskId),
        done: 'اتسجل');
  }
}
