import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/group_models.dart';
import '../../domain/workflow_models.dart';
import '../providers/group_providers.dart';
import '../widgets/group_widgets.dart';

/// The colours a state can take. A fixed palette keeps the board readable
/// in both themes; the API accepts any '#RRGGBB'.
const stateColors = <String>[
  '#64748B', '#2563EB', '#0891B2', '#7C3AED', '#D97706', '#DC2626', '#16A34A', '#DB2777',
];

/// `/g/:gid/settings/workflow` — the group's task states.
class WorkflowSettingsPage extends ConsumerStatefulWidget {
  const WorkflowSettingsPage({super.key, required this.gid});
  final String gid;

  @override
  ConsumerState<WorkflowSettingsPage> createState() => _WorkflowSettingsPageState();
}

class _WorkflowSettingsPageState extends ConsumerState<WorkflowSettingsPage> {
  bool _busy = false;

  Future<void> _run(Future<GroupWorkflow> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(groupWorkflowProvider(widget.gid));
      // Task lists show the new names and colours.
      ref.invalidate(groupHomeProvider(widget.gid));
      if (done != null && mounted) showSnack(context, done);
    } catch (error) {
      if (mounted) showSnack(context, describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GroupScope(
      gid: widget.gid,
      requires: Caps.manageWorkflow,
      builder: (context, access) {
        final workflow = ref.watch(groupWorkflowProvider(widget.gid));
        final api = ref.read(groupsApiProvider);
        return AppScreen(
          title: 'حالات المهام',
          subtitle: access.name,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _busy
                ? null
                : () async {
                    final draft = await showStateEditor(context);
                    if (draft == null) return;
                    await _run(
                      () => api.addState(widget.gid,
                          name: draft.name, category: draft.category, color: draft.color),
                      done: 'الحالة اتضافت',
                    );
                  },
            icon: const Icon(Icons.add_rounded),
            label: const Text('حالة'),
          ),
          children: [
            const HintBanner(
              'كل حالة ليها فئة: الفئة هي اللي بتتحسب في التقارير والرئيسية، '
              'والاسم واللون بتوعك. اسحب الحالات علشان ترتبها.',
            ),
            const SizedBox(height: 12),
            workflow.when(
              loading: () => const AppLoadingView(),
              error: (error, _) => AppErrorView(
                message: describeError(error),
                onRetry: () => ref.invalidate(groupWorkflowProvider(widget.gid)),
              ),
              data: (flow) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (from, to) {
                      final ids = [for (final s in flow.live) s.id];
                      ids.insert(to, ids.removeAt(from));
                      _run(() => api.reorderStates(widget.gid, ids));
                    },
                    children: [
                      for (final (i, state) in flow.live.indexed)
                        _StateTile(
                          key: ValueKey(state.id),
                          state: state,
                          index: i,
                          onEdit: _busy
                              ? null
                              : () async {
                                  final draft = await showStateEditor(context, initial: state);
                                  if (draft == null) return;
                                  await _run(() => api.updateState(
                                        widget.gid,
                                        state.id,
                                        name: draft.name == state.name ? null : draft.name,
                                        category: draft.category == state.category
                                            ? null
                                            : draft.category,
                                        color: draft.color == state.color ? null : draft.color,
                                      ));
                                },
                          onArchive: _busy || state.isLocked
                              ? null
                              : () => _archive(flow, state),
                        ),
                    ],
                  ),
                  if (flow.archived.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionLabel('مؤرشفة'),
                    const SizedBox(height: 8),
                    for (final state in flow.archived)
                      SettingsTile(
                        icon: Icons.circle,
                        color: Color(state.argb),
                        title: state.name,
                        subtitle: state.category.label,
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                    () => api.updateState(widget.gid, state.id, archived: false),
                                    done: 'الحالة رجعت',
                                  ),
                          child: const Text('استرجاع'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 72),
          ],
        );
      },
    );
  }

  Future<void> _archive(GroupWorkflow flow, WorkflowState state) async {
    // Say why before the API refuses.
    if (state.taskCount > 0) {
      showSnack(context, 'الحالة فيها ${state.taskCount} مهمة. انقلهم لحالة تانية الأول.');
      return;
    }
    if ((state.category == StateCategory.backlog || state.category == StateCategory.done) &&
        flow.liveIn(state.category) == 1) {
      showSnack(context, 'دي آخر حالة من فئة «${state.category.label}» ولازم تفضل.');
      return;
    }
    await _run(
      () => ref.read(groupsApiProvider).updateState(widget.gid, state.id, archived: true),
      done: 'الحالة اتأرشفت',
    );
  }
}

class _StateTile extends StatelessWidget {
  const _StateTile({
    super.key,
    required this.state,
    required this.index,
    required this.onEdit,
    required this.onArchive,
  });

  final WorkflowState state;
  final int index;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: Icons.circle,
      color: Color(state.argb),
      title: state.name,
      subtitle: [
        state.category.label,
        if (state.taskCount > 0) '${state.taskCount} مهمة',
        if (state.isLocked) 'أساسية',
      ].join(' · '),
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'أرشفة',
            icon: const Icon(Icons.archive_outlined),
            onPressed: onArchive,
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

typedef StateDraft = ({String name, StateCategory category, String color});

/// Add / edit a state: name, category, colour.
Future<StateDraft?> showStateEditor(BuildContext context, {WorkflowState? initial}) {
  return showModalBottomSheet<StateDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _StateEditor(initial: initial),
  );
}

class _StateEditor extends StatefulWidget {
  const _StateEditor({this.initial});
  final WorkflowState? initial;

  @override
  State<_StateEditor> createState() => _StateEditorState();
}

class _StateEditorState extends State<_StateEditor> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late StateCategory _category = widget.initial?.category ?? StateCategory.active;
  late String _color = widget.initial?.color.toUpperCase() ?? stateColors[1];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.initial?.isLocked ?? false;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.initial == null ? 'حالة جديدة' : 'تعديل الحالة',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: widget.initial == null,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          const SizedBox(height: 8),
          Text('الفئة', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in StateCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _category == c,
                  onSelected: locked ? null : (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('اللون', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in stateColors)
                Semantics(
                  button: true,
                  selected: _color == hex,
                  label: hex,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(parseHexColor(hex)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == hex ? AppColors.accent : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final name = _name.text.trim();
              if (name.isEmpty) return;
              Navigator.of(context).pop((name: name, category: _category, color: _color));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

/// `/g/:gid/p/:pid/settings` — make a project private and set per-project
/// roles (read-only, or a different functional role on this project).
class GroupProjectSettingsPage extends ConsumerWidget {
  const GroupProjectSettingsPage({super.key, required this.gid, required this.pid});
  final String gid;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (gid: gid, pid: pid);
    return GroupScope(
      gid: gid,
      requires: Caps.manageGroup,
      builder: (context, access) {
        final project = ref.watch(projectAccessProvider(key));
        final overrides = ref.watch(projectMembersProvider(key));
        final api = ref.read(groupsApiProvider);

        Future<void> run(Future<void> Function() action, [String? done]) async {
          try {
            await action();
            ref.invalidate(projectAccessProvider(key));
            ref.invalidate(projectMembersProvider(key));
            ref.invalidate(groupProjectsProvider(gid));
            ref.invalidate(groupHomeProvider(gid));
            if (done != null && context.mounted) showSnack(context, done);
          } catch (error) {
            if (context.mounted) showSnack(context, describeError(error));
          }
        }

        return AppScreen(
          title: 'إعدادات المشروع',
          subtitle: access.name,
          children: [
            project.when(
              loading: () => const AppLoadingView(),
              error: (error, _) => AppErrorView(message: describeError(error)),
              data: (p) => ToggleRow(
                title: 'مشروع خاص',
                subtitle: 'يظهر لقائد المجموعة والمساعدين وأعضاء المشروع بس',
                value: p.isPrivate,
                onChanged: (value) => run(
                  () => api.setProjectPrivate(gid, pid, private: value),
                  value ? 'المشروع بقى خاص' : 'المشروع بقى ظاهر للمجموعة',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('صلاحيات خاصة بالمشروع'),
            const SizedBox(height: 4),
            Text(
              'أعضاء المشروع (للمشروع الخاص)، أو حد دوره هنا غير دوره في المجموعة.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            overrides.when(
              loading: () => const AppLoadingView(),
              error: (error, _) => AppErrorView(
                message: describeError(error),
                onRetry: () => ref.invalidate(projectMembersProvider(key)),
              ),
              data: (list) => Column(
                children: [
                  if (list.isEmpty)
                    const HintBanner('كل الأعضاء بأدوارهم في المجموعة.'),
                  for (final o in list)
                    SettingsTile(
                      icon: o.readOnly ? Icons.visibility_outlined : Icons.edit_outlined,
                      title: o.name,
                      subtitle: [
                        o.readOnly ? 'قراءة بس' : 'تعديل',
                        if (o.functionalRole != null)
                          functionalRoleLabel(access.type, o.functionalRole),
                      ].join(' · '),
                      trailing: IconButton(
                        tooltip: 'إزالة',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => run(() => api.removeProjectMember(gid, pid, o.uid)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_alt_outlined),
              label: const Text('إضافة عضو للمشروع'),
              onPressed: () async {
                final members = await ref.read(groupMembersProvider(gid).future);
                if (!context.mounted) return;
                final candidates =
                    members.where((m) => m.groupRole != GroupRole.lead).toList(growable: false);
                final choice = await showModalBottomSheet<_OverrideChoice>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => _OverrideSheet(type: access.type, members: candidates),
                );
                if (choice == null) return;
                await run(
                  () => api.setProjectMember(gid, pid, choice.uid,
                      readOnly: choice.readOnly, functionalRole: choice.functionalRole),
                  'اتحفظ',
                );
              },
            ),
          ],
        );
      },
    );
  }
}

typedef _OverrideChoice = ({String uid, bool readOnly, String? functionalRole});

class _OverrideSheet extends StatefulWidget {
  const _OverrideSheet({required this.type, required this.members});
  final GroupType type;
  final List<GroupMember> members;

  @override
  State<_OverrideSheet> createState() => _OverrideSheetState();
}

class _OverrideSheetState extends State<_OverrideSheet> {
  GroupMember? _member;
  bool _readOnly = false;
  String? _role;

  @override
  Widget build(BuildContext context) {
    final member = _member;
    final guest = member?.groupRole == GroupRole.guest;
    final roles = functionalRoles[widget.type]!.entries.where((e) => e.key != 'client');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('عضو المشروع', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (widget.members.isEmpty) const HintBanner('مفيش أعضاء في المجموعة غير القائد.'),
            for (final m in widget.members)
              ListTile(
                leading: InitialsAvatar(name: m.name),
                title: Text(m.name),
                subtitle: Text(m.groupRole == GroupRole.guest
                    ? m.groupRole.label
                    : functionalRoleLabel(widget.type, m.functionalRole)),
                selected: m.uid == member?.uid,
                onTap: () => setState(() {
                  _member = m;
                  if (m.groupRole == GroupRole.guest) {
                    _readOnly = true;
                    _role = null;
                  }
                }),
              ),
            if (member != null) ...[
              const Divider(),
              SwitchListTile(
                title: const Text('قراءة بس'),
                value: _readOnly,
                onChanged: guest ? null : (v) => setState(() => _readOnly = v),
              ),
              if (!guest) ...[
                const SizedBox(height: 4),
                Text('دوره في المشروع ده', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('زي المجموعة'),
                      selected: _role == null,
                      onSelected: (_) => setState(() => _role = null),
                    ),
                    for (final e in roles)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: _role == e.key,
                        onSelected: (_) => setState(() => _role = e.key),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context)
                    .pop((uid: member.uid, readOnly: _readOnly, functionalRole: _role)),
                child: const Text('حفظ'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
