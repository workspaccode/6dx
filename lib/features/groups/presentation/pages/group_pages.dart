import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/group_models.dart';
import '../../domain/workflow_models.dart';
import 'hardware_pages.dart';
import '../providers/group_providers.dart';
import '../widgets/group_widgets.dart';
import '../providers/active_group.dart';

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
    // This group becomes the active one: the classic screens (board,
    // sprints, reviews) now show it, and the app reopens it next time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(activeGroupProvider.notifier).select(widget.gid);
    });
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
            _HomeSummary(gid: widget.gid),
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
                            icon: project.isPrivate
                                ? Icons.lock_outline_rounded
                                : access.type == GroupType.hardware
                                    ? Icons.memory_rounded
                                    : Icons.folder_outlined,
                            title: project.name,
                            subtitle: [
                              '${project.openTasks} مفتوحة · ${project.doneTasks} مكتملة',
                              if (project.isPrivate) 'خاص',
                              if (project.myAccess == 'read') 'قراءة بس',
                            ].join(' · '),
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
            if (access.type == GroupType.hardware && access.groupRole != GroupRole.guest)
              SettingsTile(
                icon: Icons.inventory_2_outlined,
                title: 'المخزن والمشتريات',
                subtitle: 'الرصيد المشترك والموردين',
                onTap: () => context.push('/g/${widget.gid}/inventory'),
              ),
            if (access.type == GroupType.software)
              SettingsTile(
                icon: Icons.dashboard_outlined,
                title: 'الشاشات الكاملة (الـ board، الـ sprints، المراجعات)',
                subtitle: 'بتعرض المجموعة دي',
                onTap: () {
                  ref.read(activeGroupProvider.notifier).select(widget.gid);
                  context.go(AppRoutes.projects);
                },
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
      ref.invalidate(groupHomeProvider(widget.gid));
      ref.invalidate(groupsOverviewProvider);
      if (context.mounted) context.push('/g/${widget.gid}/p/${project.id}');
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(error, fallback: 'تعذّر إنشاء المشروع.'));
    }
  }
}

/// The real home numbers (`GET /v1/groups/{gid}/home`), shaped by role:
/// the lead and admins see the team, a member their own tasks, a guest the
/// progress only. The API decides what each role gets.
class _HomeSummary extends ConsumerWidget {
  const _HomeSummary({required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(groupHomeProvider(gid));
    return home.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (error, _) => AppErrorView(
        message: describeError(error),
        onRetry: () => ref.invalidate(groupHomeProvider(gid)),
      ),
      data: (data) {
        final team = data.team;
        final mine = data.myTasks;
        final now = DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StatTile(value: '${data.openTasks}', label: 'مفتوحة'),
                const SizedBox(width: 8),
                StatTile(
                  value: '${data.count(StateCategory.blocked)}',
                  label: 'متوقفة',
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                StatTile(
                  value: '${data.count(StateCategory.done)}',
                  label: 'تمت',
                  color: AppColors.success,
                ),
              ],
            ),
            if (team != null) ...[
              const SizedBox(height: 16),
              SectionLabel('الفريق'),
              const SizedBox(height: 8),
              Row(
                children: [
                  StatTile(value: '${team.members}', label: 'عضو', color: AppColors.info),
                  const SizedBox(width: 8),
                  StatTile(
                    value: '${team.unassigned}',
                    label: 'مهام من غير مسؤول',
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  StatTile(
                    value: '${team.overdue}',
                    label: 'متأخرة',
                    color: team.overdue > 0 ? AppColors.danger : AppColors.textMuted,
                  ),
                ],
              ),
              if (team.pendingInvites > 0) ...[
                const SizedBox(height: 8),
                HintBanner('${team.pendingInvites} دعوة لسه ماتقبلتش.'),
              ],
            ],
            if (mine != null) ...[
              const SizedBox(height: 16),
              SectionLabel(data.myOverdue > 0
                  ? 'مهامي (${mine.length}) · ${data.myOverdue} متأخرة'
                  : 'مهامي (${mine.length})'),
              const SizedBox(height: 8),
              if (mine.isEmpty)
                const HintBanner('مفيش مهام مفتوحة متعيّنة عليك.')
              else
                for (final task in mine)
                  SettingsTile(
                    icon: Icons.circle,
                    color: Color(parseHexColor(task.stateColor)),
                    title: task.title,
                    subtitle: [
                      task.stateName ?? task.category.label,
                      if (task.projectName != null) task.projectName!,
                      if (task.isOverdue(now)) 'متأخرة',
                    ].join(' · '),
                    onTap: task.projectId == null
                        ? null
                        : () => context.push('/g/$gid/p/${task.projectId}'),
                  ),
            ],
            if (mine == null && data.projects.isNotEmpty) ...[
              // A guest's view: how far each project got, no names.
              const SizedBox(height: 16),
              SectionLabel('التقدم'),
              const SizedBox(height: 8),
              for (final project in data.projects)
                AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: project.progress),
                      const SizedBox(height: 4),
                      Text(
                        '${project.doneTasks} من ${project.openTasks + project.doneTasks} مهمة تمت',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// `/g/:gid/p/:pid` — a project's tasks, grouped by the group's states.
class GroupProjectPage extends ConsumerStatefulWidget {
  const GroupProjectPage({super.key, required this.gid, required this.pid, this.tasksOnly = false});
  final String gid;
  final String pid;

  /// A hardware project opens on its phases / BOM / builds screen; its task
  /// list lives at `/g/:gid/p/:pid/tasks`.
  final bool tasksOnly;

  @override
  ConsumerState<GroupProjectPage> createState() => _GroupProjectPageState();
}

class _GroupProjectPageState extends ConsumerState<GroupProjectPage> {
  final _newTask = TextEditingController();
  bool _adding = false;

  ProjectKey get _key => (gid: widget.gid, pid: widget.pid);

  @override
  void dispose() {
    _newTask.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(groupTasksProvider(_key));
    ref.invalidate(groupProjectsProvider(widget.gid));
    ref.invalidate(groupHomeProvider(widget.gid));
    ref.invalidate(groupWorkflowProvider(widget.gid));
  }

  Future<void> _add() async {
    final title = _newTask.text.trim();
    if (title.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ref.read(groupsApiProvider).createTask(projectId: widget.pid, title: title);
      if (!mounted) return;
      _newTask.clear();
      _refresh();
    } catch (error) {
      if (mounted) showSnack(context, describeError(error, fallback: 'تعذّر إضافة المهمة.'));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _move(GroupTask task, WorkflowState state) async {
    try {
      await ref.read(groupsApiProvider).setTaskState(task.id, state.id);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) showSnack(context, describeError(error, fallback: 'تعذّر تحديث المهمة.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GroupScope(
      gid: widget.gid,
      builder: (context, access) {
        if (access.type == GroupType.hardware && !widget.tasksOnly) {
          return HardwareProjectPage(access: access, pid: widget.pid);
        }
        final projects = ref.watch(groupProjectsProvider(widget.gid)).value ?? const [];
        GroupProject? project;
        for (final p in projects) {
          if (p.id == widget.pid) project = p;
        }
        final projectAccess = ref.watch(projectAccessProvider(_key));
        // The project override decides (a read-only member); until it loads,
        // nothing is editable.
        final canEdit = projectAccess.value?.canEditTasks ?? false;
        final tasks = ref.watch(groupTasksProvider(_key));
        final workflow = ref.watch(groupWorkflowProvider(widget.gid));

        if (projectAccess.hasError) {
          return AppScreen(
            title: 'المشروع',
            children: [
              AppEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'المشروع ده مش متاح',
                message: describeError(projectAccess.error!),
              ),
            ],
          );
        }

        return AppScreen(
          title: project?.name ?? 'المشروع',
          subtitle: [
            access.name,
            if (project?.isPrivate ?? false) 'خاص',
            if (projectAccess.value?.override == 'read') 'قراءة بس',
          ].join(' · '),
          // Visibility and per-project roles are the lead's / admins' call.
          trailing: access.can(Caps.manageGroup)
              ? IconButton(
                  tooltip: 'إعدادات المشروع',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => context.push('/g/${widget.gid}/p/${widget.pid}/settings'),
                )
              : null,
          children: [
            if (access.groupRole != GroupRole.guest)
              SettingsTile(
                icon: Icons.link_rounded,
                title: 'المشاريع المرتبطة',
                subtitle: 'مشاريع في مجموعات تانية (ملخص واعتماديات)',
                onTap: () => context.push('/g/${widget.gid}/p/${widget.pid}/links'),
              ),
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
            switch ((tasks, workflow)) {
              (AsyncValue(:final error?), _) || (_, AsyncValue(:final error?)) => AppErrorView(
                  message: describeError(error),
                  onRetry: _refresh,
                ),
              (AsyncData(value: final list), AsyncData(value: final flow)) =>
                _TasksByState(
                  tasks: list,
                  workflow: flow,
                  canEdit: canEdit,
                  onMove: _move,
                ),
              _ => const AppLoadingView(),
            },
          ],
        );
      },
    );
  }
}

class _TasksByState extends StatelessWidget {
  const _TasksByState({
    required this.tasks,
    required this.workflow,
    required this.canEdit,
    required this.onMove,
  });

  final List<GroupTask> tasks;
  final GroupWorkflow workflow;
  final bool canEdit;
  final void Function(GroupTask task, WorkflowState state) onMove;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const AppEmptyState(
        icon: Icons.checklist_rounded,
        title: 'مفيش مهام في المشروع ده',
      );
    }
    final byState = <String, List<GroupTask>>{};
    final unmapped = <GroupTask>[];
    for (final task in tasks) {
      final state = workflow.forTask(task);
      if (state == null) {
        unmapped.add(task);
      } else {
        byState.putIfAbsent(state.id, () => []).add(task);
      }
    }
    // Live states in order, then archived ones still holding old tasks.
    final sections = [
      ...workflow.live,
      ...workflow.archived.where((s) => byState.containsKey(s.id)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final state in sections)
          if (byState[state.id] case final list?) ...[
            SectionLabel('${state.name} (${list.length})'),
            const SizedBox(height: 6),
            for (final task in list) _tile(task, state),
            const SizedBox(height: 8),
          ],
        if (unmapped.isNotEmpty) ...[
          SectionLabel('من غير حالة (${unmapped.length})'),
          const SizedBox(height: 6),
          for (final task in unmapped) _tile(task, null),
        ],
      ],
    );
  }

  Widget _tile(GroupTask task, WorkflowState? state) {
    final closed = state?.category.isClosed ?? false;
    return SettingsTile(
      icon: closed ? Icons.check_circle_rounded : Icons.circle,
      color: state == null ? AppColors.textMuted : Color(state.argb),
      title: task.title,
      trailing: canEdit
          ? PopupMenuButton<WorkflowState>(
              tooltip: 'نقل',
              onSelected: (next) => onMove(task, next),
              itemBuilder: (_) => [
                for (final next in workflow.live)
                  if (next.id != state?.id)
                    PopupMenuItem(
                      value: next,
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 12, color: Color(next.argb)),
                          const SizedBox(width: 8),
                          Text(next.name),
                        ],
                      ),
                    ),
              ],
            )
          : const SizedBox.shrink(),
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
            if (access.can(Caps.manageWorkflow) && access.type == GroupType.hardware)
              SettingsTile(
                icon: Icons.flag_outlined,
                title: 'مراحل المشاريع',
                subtitle: 'القالب: Proto، EVT، DVT، PVT، MP وشروط الخروج',
                onTap: () => context.push('/g/$gid/settings/phases'),
              ),
            if (access.can(Caps.manageWorkflow))
              SettingsTile(
                icon: Icons.view_column_outlined,
                title: 'حالات المهام',
                subtitle: 'الأسماء والألوان والترتيب',
                onTap: () => context.push('/g/$gid/settings/workflow'),
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
                    ref.read(activeGroupProvider.notifier).clear();
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
