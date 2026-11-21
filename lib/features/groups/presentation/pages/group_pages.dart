import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/group_models.dart';
import '../providers/group_providers.dart';
import '../widgets/group_widgets.dart';

/// `/g/:gid/home` — the group's home, shaped by the caller's role.
class GroupHomePage extends ConsumerStatefulWidget {
  const GroupHomePage({super.key, required this.gid});
  final String gid;

  @override
  ConsumerState<GroupHomePage> createState() => _GroupHomePageState();
}

class _GroupHomePageState extends ConsumerState<GroupHomePage> {
  @override
  void initState() {
    super.initState();
    // Reopen this group next time.
    ref.read(lastGroupIdProvider).set(widget.gid);
  }

  @override
  Widget build(BuildContext context) {
    return GroupScope(
      gid: widget.gid,
      builder: (context, access) {
        final projects = ref.watch(groupProjectsProvider(widget.gid));
        return AppScreen(
          title: access.name,
          subtitle: '${access.type.label} · ${access.roleLabel}',
          trailing: GroupSwitcherButton(currentGroupId: access.id),
          floatingActionButton: access.can(Caps.manageProjects)
              ? FloatingActionButton.extended(
                  onPressed: () => _createProject(context, access),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('مشروع'),
                )
              : null,
          children: [
            if (access.isArchived)
              const HintBanner('المجموعة مؤرشفة — للقراءة بس.', color: AppColors.warning),
            if (!access.isMember)
              const HintBanner(
                'انت بتشوف المجموعة كمدير لمساحة العمل. تقدر تدير الأعضاء والإعدادات بس.',
              ),
            _RoleFocus(access: access),
            const SizedBox(height: 16),
            SectionLabel('المشاريع'),
            const SizedBox(height: 8),
            projects.when(
              loading: () => const AppLoadingView(),
              error: (error, _) => AppErrorView(
                message: describeError(error),
                onRetry: () => ref.invalidate(groupProjectsProvider(widget.gid)),
              ),
              data: (list) => list.isEmpty
                  ? AppEmptyState(
                      icon: access.type == GroupType.hardware
                          ? Icons.memory_rounded
                          : Icons.folder_open_rounded,
                      title: 'مفيش مشاريع في المجموعة',
                      message: access.can(Caps.manageProjects)
                          ? 'اعمل أول مشروع (منتج أو نسخة من منتج).'
                          : 'لما قائد المجموعة يعمل مشروع هيظهر هنا.',
                    )
                  : Column(
                      children: [
                        for (final project in list)
                          SettingsTile(
                            icon: access.type == GroupType.hardware
                                ? Icons.memory_rounded
                                : Icons.folder_outlined,
                            title: project.name,
                            subtitle:
                                '${project.openTasks} مفتوحة · ${project.doneTasks} مكتملة',
                            onTap: () => context.push('/g/${widget.gid}/p/${project.id}'),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            SectionLabel('المجموعة'),
            const SizedBox(height: 8),
            SettingsTile(
              icon: Icons.people_outline_rounded,
              title: 'الأعضاء',
              onTap: () => context.push('/g/${widget.gid}/members'),
            ),
            if (access.can(Caps.manageGroup))
              SettingsTile(
                icon: Icons.tune_rounded,
                title: 'إعدادات المجموعة',
                onTap: () => context.push('/g/${widget.gid}/settings'),
              ),
            if (access.isDefault)
              SettingsTile(
                icon: Icons.dashboard_outlined,
                title: 'الشاشات الكاملة (المهام، الـ sprints، المراجعات)',
                subtitle: 'المجموعة الافتراضية متوصلة بكل شاشات التطبيق',
                onTap: () => context.go(AppRoutes.projects),
              ),
          ],
        );
      },
    );
  }

  Future<void> _createProject(BuildContext context, GroupAccess access) async {
    final name = await _askText(
      context,
      title: access.type == GroupType.hardware ? 'منتج / مشروع Hardware جديد' : 'مشروع جديد',
      label: 'اسم المشروع',
      maxLength: 80,
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    try {
      final project = await ref.read(groupsApiProvider).createProject(widget.gid, name: name);
      ref.invalidate(groupProjectsProvider(widget.gid));
      ref.invalidate(groupsOverviewProvider);
      if (context.mounted) context.push('/g/${widget.gid}/p/${project.id}');
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(error, fallback: 'تعذّر إنشاء المشروع.'));
    }
  }
}

/// What this role should look at first (§5.4). The full role dashboards come
/// with the hardware screens; until then each role gets its checklist.
class _RoleFocus extends StatelessWidget {
  const _RoleFocus({required this.access});
  final GroupAccess access;

  static const _focus = <String, List<String>>{
    'tech_lead': ['الـ sprint الحالي', 'PRs محتاجة مراجعة', 'CI فاشل'],
    'developer': ['مهامي', 'PRs مستنية مراجعتي'],
    'reviewer': ['طابور المراجعة', 'الـ SLA'],
    'qa': ['مهام محتاجة اختبار', 'الـ bugs المفتوحة'],
    'designer': ['مهام التصميم', 'المراجعات المطلوبة'],
    'devops': ['الـ pipelines', 'الـ releases'],
    'pm': ['تقدم الـ sprint', 'الـ backlog'],
    'hw_lead': ['اعتمادات ECO المستنياك', 'جاهزية الـ gate الجاية', 'المخاطر'],
    'electrical': ['مهام التصميم', 'الـ ECOs بتاعتي', 'الـ BOM المسودة'],
    'mechanical': ['مهام التصميم', 'الـ ECOs بتاعتي'],
    'firmware': ['مهامي و PRs', 'توافق الـ firmware مع الـ HW'],
    'test': ['اختبارات مطلوبة', 'الوحدات الفاشلة', 'خطط الاختبار'],
    'technician': ['طابور الـ builds', 'الوحدات المتعيّنة عليّا', 'تسجيل نتيجة'],
    'manufacturing': ['الـ builds الجاية', 'DFM'],
    'procurement': ['قطع طويلة التوريد', 'أوامر الشراء المفتوحة'],
    'client': ['تقدم المراحل', 'التقارير', 'القرار المطلوب منك'],
  };

  @override
  Widget build(BuildContext context) {
    final items = _focus[access.functionalRole] ??
        (access.isMember ? const <String>[] : const ['الأعضاء', 'الإعدادات']);
    if (items.isEmpty) return const SizedBox.shrink();
    return AppPanel(
      accent: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('أول حاجة ليك', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.arrow_left_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// `/g/:gid/p/:pid` — a project's tasks inside its group.
class GroupProjectPage extends ConsumerStatefulWidget {
  const GroupProjectPage({super.key, required this.gid, required this.pid});
  final String gid;
  final String pid;

  @override
  ConsumerState<GroupProjectPage> createState() => _GroupProjectPageState();
}

class _GroupProjectPageState extends ConsumerState<GroupProjectPage> {
  final _newTask = TextEditingController();
  bool _adding = false;

  static const _statuses = <String, String>{
    'todo': 'للتنفيذ',
    'in_progress': 'جاري',
    'review': 'مراجعة',
    'done': 'مكتملة',
  };

  ProjectKey get _key => (gid: widget.gid, pid: widget.pid);

  @override
  void dispose() {
    _newTask.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _newTask.text.trim();
    if (title.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ref.read(groupsApiProvider).createTask(projectId: widget.pid, title: title);
      _newTask.clear();
      ref.invalidate(groupTasksProvider(_key));
      ref.invalidate(groupProjectsProvider(widget.gid));
    } catch (error) {
      if (mounted) showSnack(context, describeError(error, fallback: 'تعذّر إضافة المهمة.'));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _move(GroupTask task, String status) async {
    try {
      await ref.read(groupsApiProvider).setTaskStatus(task.id, status);
      ref.invalidate(groupTasksProvider(_key));
      ref.invalidate(groupProjectsProvider(widget.gid));
    } catch (error) {
      if (mounted) showSnack(context, describeError(error, fallback: 'تعذّر تحديث المهمة.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GroupScope(
      gid: widget.gid,
      builder: (context, access) {
        final projects = ref.watch(groupProjectsProvider(widget.gid)).value ?? const [];
        GroupProject? project;
        for (final p in projects) {
          if (p.id == widget.pid) project = p;
        }
        final tasks = ref.watch(groupTasksProvider(_key));
        final canEdit = access.canEditTasks;

        return AppScreen(
          title: project?.name ?? 'المشروع',
          subtitle: access.name,
          children: [
            if (canEdit)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTask,
                      maxLength: 200,
                      enabled: !_adding,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(
                        hintText: 'مهمة جديدة',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _adding ? null : _add,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            tasks.when(
              loading: () => const AppLoadingView(),
              error: (error, _) => AppErrorView(
                message: describeError(error),
                onRetry: () => ref.invalidate(groupTasksProvider(_key)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.checklist_rounded,
                    title: 'مفيش مهام في المشروع ده',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final status in _statuses.keys)
                      if (list.any((t) => t.status == status)) ...[
                        SectionLabel(
                          '${_statuses[status]} (${list.where((t) => t.status == status).length})',
                        ),
                        const SizedBox(height: 6),
                        for (final task in list.where((t) => t.status == status))
                          SettingsTile(
                            icon: status == 'done'
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: status == 'done' ? AppColors.success : AppColors.textMuted,
                            title: task.title,
                            trailing: canEdit
                                ? PopupMenuButton<String>(
                                    tooltip: 'نقل',
                                    onSelected: (next) => _move(task, next),
                                    itemBuilder: (_) => [
                                      for (final entry in _statuses.entries)
                                        if (entry.key != task.status)
                                          PopupMenuItem(value: entry.key, child: Text(entry.value)),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        const SizedBox(height: 8),
                      ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// `/g/:gid/settings` — rename, archive, transfer the lead, delete.
class GroupSettingsPage extends ConsumerWidget {
  const GroupSettingsPage({super.key, required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupScope(
      gid: gid,
      requires: Caps.manageGroup,
      builder: (context, access) {
        final api = ref.read(groupsApiProvider);

        Future<void> run(Future<void> Function() action, String done) async {
          try {
            await action();
            ref.invalidate(groupAccessProvider(gid));
            ref.invalidate(groupsOverviewProvider);
            if (context.mounted) showSnack(context, done);
          } catch (error) {
            if (context.mounted) showSnack(context, describeError(error));
          }
        }

        return AppScreen(
          title: 'إعدادات المجموعة',
          subtitle: access.name,
          children: [
            SettingsTile(
              icon: Icons.edit_outlined,
              title: 'تغيير الاسم',
              subtitle: access.name,
              onTap: access.isArchived
                  ? null
                  : () async {
                      final name = await _askText(context,
                          title: 'اسم المجموعة', label: 'الاسم', initial: access.name, maxLength: 80);
                      if (name == null || name.isEmpty) return;
                      await run(() => api.update(gid, name: name), 'اتغيّر الاسم');
                    },
            ),
            SettingsTile(
              icon: Icons.category_outlined,
              title: 'النوع',
              subtitle: '${access.type.label} — مش بيتغير بعد الإنشاء',
              trailing: GroupTypeBadge(access.type),
            ),
            if (!access.isDefault)
              SettingsTile(
                icon: access.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                title: access.isArchived ? 'فك الأرشفة' : 'أرشفة المجموعة',
                subtitle: access.isArchived
                    ? 'هتاخد مكان في حد الخطة تاني'
                    : 'هتبقى للقراءة بس، ومش هتتحسب في حد الخطة',
                color: AppColors.warning,
                onTap: () async {
                  final ok = await _confirm(
                    context,
                    access.isArchived ? 'فك أرشفة المجموعة؟' : 'أرشفة المجموعة؟',
                  );
                  if (ok) {
                    await run(() => api.update(gid, archived: !access.isArchived),
                        access.isArchived ? 'المجموعة رجعت' : 'المجموعة اتأرشفت');
                  }
                },
              ),
            if (access.groupRole == GroupRole.lead)
              SettingsTile(
                icon: Icons.swap_horiz_rounded,
                title: 'نقل القيادة',
                subtitle: 'هتبقى مساعد بعدها',
                onTap: () async {
                  final members = await ref.read(groupMembersProvider(gid).future);
                  if (!context.mounted) return;
                  final candidates = members
                      .where((m) => m.groupRole != GroupRole.lead && m.groupRole != GroupRole.guest)
                      .toList();
                  if (candidates.isEmpty) {
                    showSnack(context, 'مفيش أعضاء ينفع ينقلوا القيادة ليهم');
                    return;
                  }
                  final uid = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    builder: (sheet) => SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final m in candidates)
                            ListTile(
                              leading: InitialsAvatar(name: m.name),
                              title: Text(m.name),
                              subtitle: Text(functionalRoleLabel(access.type, m.functionalRole)),
                              onTap: () => Navigator.of(sheet).pop(m.uid),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (uid == null || !context.mounted) return;
                  final ok = await _confirm(context, 'نقل قيادة المجموعة؟ العملية دي مش بترجع غير لو القائد الجديد رجّعها.');
                  if (ok) {
                    await run(() => api.transferLead(gid, uid), 'القيادة اتنقلت');
                    ref.invalidate(groupMembersProvider(gid));
                  }
                },
              ),
            if (access.can(Caps.deleteGroup) && !access.isDefault)
              SettingsTile(
                icon: Icons.delete_outline_rounded,
                title: 'حذف المجموعة',
                subtitle: 'للمجموعة الفاضية بس — غير كده أرشفها',
                color: AppColors.danger,
                onTap: () async {
                  final ok = await _confirm(context, 'حذف المجموعة نهائيًا؟');
                  if (!ok) return;
                  try {
                    await api.delete(gid);
                    await ref.read(lastGroupIdProvider).set(null);
                    ref.invalidate(groupsOverviewProvider);
                    if (context.mounted) context.go('/groups');
                  } catch (error) {
                    if (context.mounted) showSnack(context, describeError(error));
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

/// `/g/:gid/welcome` — first screen after accepting an invite.
class GroupWelcomePage extends ConsumerWidget {
  const GroupWelcomePage({super.key, required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupScope(
      gid: gid,
      builder: (context, access) => AppScreen(
        children: [
          const SizedBox(height: 24),
          AppEmptyState(
            icon: access.type == GroupType.hardware ? Icons.memory_rounded : Icons.code_rounded,
            title: 'أهلًا في ${access.name}',
            message: 'دورك: ${access.roleLabel}',
          ),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('3 خطوات تبدأ بيهم', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                const _Step(n: 1, text: 'راجع بياناتك في الحساب'),
                const _Step(n: 2, text: 'شغّل الإشعارات علشان توصلك المهام والاعتمادات'),
                _Step(
                  n: 3,
                  text: access.groupRole == GroupRole.guest
                      ? 'تابع تقدم المشاريع اللي اتشاركت معاك'
                      : 'افتح أول مشروع في المجموعة',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/g/$gid/home'),
            child: const Text('يلا نبدأ'),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            CircleAvatar(radius: 11, child: Text('$n', style: const TextStyle(fontSize: 11))),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String label,
  String? initial,
  int? maxLength,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: maxLength,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (value) => Navigator.of(dialog).pop(value.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  // The controller is left to the GC: disposing it here would race the
  // dialog's exit animation, which still reads it.
}

Future<bool> _confirm(BuildContext context, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: const Text('تأكيد')),
      ],
    ),
  );
  return ok ?? false;
}
