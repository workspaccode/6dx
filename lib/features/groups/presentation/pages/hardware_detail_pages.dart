import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../data/hardware_api.dart';
import '../../domain/group_models.dart';
import '../../domain/hardware_models.dart';
import '../providers/group_providers.dart';
import '../providers/hardware_providers.dart';
import '../widgets/group_widgets.dart';
import '../widgets/hardware_widgets.dart';
import 'hardware_pages.dart';
import 'inventory_pages.dart';

/// Loads the project's capabilities (from the overview) for a detail page.
class _HwScope extends ConsumerWidget {
  const _HwScope({required this.gid, required this.pid, required this.builder});
  final String gid;
  final String pid;
  final Widget Function(BuildContext context, HwOverview overview) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(hwOverviewProvider((gid: gid, pid: pid)));
    return overview.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: AppLoadingView()),
      error: (error, _) => AppScreen(
        title: 'Hardware',
        children: [AppErrorView(message: describeError(error))],
      ),
      data: (data) => builder(context, data),
    );
  }
}

// --- BOM revision ------------------------------------------------------------

/// `/g/:gid/p/:pid/bom/:rid` — the lines of one revision; a draft is
/// editable, a released one is a fixed snapshot.
class BomRevisionPage extends ConsumerWidget {
  const BomRevisionPage({super.key, required this.gid, required this.pid, required this.rid});
  final String gid;
  final String pid;
  final String rid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (gid: gid, pid: pid);
    return _HwScope(
      gid: gid,
      pid: pid,
      builder: (context, overview) {
        final bom = ref.watch(hwBomProvider((gid: gid, pid: pid, id: rid)));
        return bom.when(
          skipLoadingOnReload: true,
          loading: () => const Scaffold(body: AppLoadingView()),
          error: (error, _) => AppScreen(title: 'BOM', children: [AppErrorView(message: describeError(error))]),
          data: (b) {
            final editable = b.isDraft && overview.can(HwCaps.editBom);
            return AppScreen(
              title: 'BOM rev ${b.rev}',
              subtitle: b.isDraft ? 'Draft — بيتعدّل' : 'Released — ثابت',
              floatingActionButton: editable
                  ? FloatingActionButton.extended(
                      onPressed: () => _addLine(context, ref, key),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('قطعة'),
                    )
                  : null,
              children: [
                if (b.note != null) HintBanner(b.note!),
                if (b.totalCostCents != null)
                  Row(children: [
                    StatTile(value: '${b.lines.length}', label: 'قطعة'),
                    const SizedBox(width: 8),
                    StatTile(value: formatCents(b.totalCostCents), label: 'التكلفة للوحدة'),
                  ]),
                const SizedBox(height: 12),
                if (b.lines.isEmpty) const HintBanner('الـ BOM فاضي.'),
                for (final line in b.lines)
                  SettingsTile(
                    icon: Icons.developer_board_outlined,
                    title: '${line.partNumber} rev ${line.revision} × ${line.quantity}',
                    subtitle: [
                      line.description,
                      if (line.refDesignators != null) line.refDesignators!,
                      if (line.unitCostCents != null) formatCents(line.unitCostCents),
                    ].join(' · '),
                    trailing: editable
                        ? IconButton(
                            tooltip: 'إزالة',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => hwRun(context, ref, key,
                                (api) => api.removeBomLine(gid, pid, rid, line.partId)),
                          )
                        : null,
                  ),
                if (b.isDraft) ...[
                  const SizedBox(height: 16),
                  if (overview.can(HwCaps.releaseBom))
                    FilledButton.icon(
                      icon: const Icon(Icons.lock_rounded),
                      label: const Text('Release'),
                      onPressed: () async {
                        final values = await askForm(context,
                            title: 'Release rev ${b.rev}؟ مش هيتعدّل بعدها.',
                            submit: 'Release',
                            fields: const [FormFieldSpec('note', 'ملاحظة', maxLength: 2000)]);
                        if (values == null || !context.mounted) return;
                        await hwRun(context, ref, key,
                            (api) => api.releaseBom(gid, pid, rid, note: values['note']),
                            done: 'rev ${b.rev} اتعمله release');
                      },
                    ),
                  if (editable)
                    TextButton(
                      onPressed: () async {
                        final container = ProviderScope.containerOf(context, listen: false);
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref.read(hardwareApiProvider).deleteBomDraft(gid, pid, rid);
                          await navigator.maybePop();
                          refreshHardwareIn(container, key);
                          messenger.showSnackBar(const SnackBar(content: Text('الـ draft اتحذف')));
                        } catch (error) {
                          if (context.mounted) showSnack(context, describeError(error));
                        }
                      },
                      child: const Text('حذف الـ draft', style: TextStyle(color: AppColors.danger)),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addLine(BuildContext context, WidgetRef ref, ProjectKey key) async {
    final parts = await ref.read(hwPartsProvider(key).future);
    if (!context.mounted) return;
    final part = await pickOne<HwPart>(context,
        title: 'القطعة', options: parts, label: (p) => p.label, subtitle: (p) => p.description);
    if (part == null || !context.mounted) return;
    final values = await askForm(context, title: part.label, fields: const [
      FormFieldSpec('quantity', 'الكمية', required: true, number: true, initial: '1'),
      FormFieldSpec('refs', 'Reference designators', maxLength: 500, hint: 'R1-R12'),
    ]);
    if (values == null || !context.mounted) return;
    await hwRun(context, ref, key,
        (api) => api.setBomLine(gid, pid, rid, part.id,
            quantity: int.tryParse(values['quantity']!) ?? 1, refDesignators: values['refs']));
  }
}

// --- ECO ---------------------------------------------------------------------

/// `/g/:gid/p/:pid/eco/:eid` — items, the two reviews and the release.
class EcoPage extends ConsumerWidget {
  const EcoPage({super.key, required this.gid, required this.pid, required this.eid});
  final String gid;
  final String pid;
  final String eid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (gid: gid, pid: pid);
    return GroupScope(
      gid: gid,
      builder: (context, access) => _HwScope(
        gid: gid,
        pid: pid,
        builder: (context, overview) {
          final eco = ref.watch(hwEcoProvider((gid: gid, pid: pid, id: eid)));
          return eco.when(
            skipLoadingOnReload: true,
            loading: () => const Scaffold(body: AppLoadingView()),
            error: (error, _) =>
                AppScreen(title: 'ECO', children: [AppErrorView(message: describeError(error))]),
            data: (e) => _body(context, ref, key, access, overview, e),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, ProjectKey key, GroupAccess access,
      HwOverview overview, HwEco e) {
    final mine = e.createdBy == access.uid;
    final canSubmit = overview.can(HwCaps.submitEco) || overview.can(HwCaps.submitEcr);
    // Only the author edits and submits (whoever writes a change never
    // approves it); cancelling is also open to whoever releases BOMs.
    final canEdit = e.isDraft && mine && canSubmit;
    final canCancel = canSubmit && (mine || overview.can(HwCaps.releaseBom));
    Future<void> act(String action, String done) =>
        hwRun(context, ref, key, (api) => api.ecoAction(gid, pid, eid, action), done: done);

    return AppScreen(
      title: '${e.code} — ${e.title}',
      subtitle: e.statusLabel,
      children: [
        Row(children: [
          StatusChip(e.statusLabel, color: ecoColor(e.status)),
          const SizedBox(width: 8),
          if (e.isEcr) const StatusChip('ECR — طلب بس'),
        ]),
        if (e.reason != null) ...[
          const SizedBox(height: 12),
          SectionLabel('السبب'),
          Text(e.reason!),
        ],
        if (e.impact != null) ...[
          const SizedBox(height: 12),
          SectionLabel('الأثر'),
          Text(e.impact!),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: SectionLabel('التغييرات')),
          if (canEdit && !e.isEcr)
            TextButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('تغيير'),
              onPressed: () => _addItem(context, ref, key),
            ),
        ]),
        if (e.items.isEmpty) HintBanner(e.isEcr ? 'الـ ECR مالوش قطع؛ الـ ECO هو اللي بيغيّر الـ BOM.' : 'مفيش تغييرات لسه.'),
        for (final item in e.items)
          SettingsTile(
            icon: switch (item.action) {
              'add' => Icons.add_circle_outline,
              'remove' => Icons.remove_circle_outline,
              _ => Icons.swap_horiz_rounded,
            },
            title: item.label,
            trailing: canEdit
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () =>
                        hwRun(context, ref, key, (api) => api.removeEcoItem(gid, pid, eid, item.id)),
                  )
                : null,
          ),
        if (e.approvals.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionLabel('المراجعات'),
          for (final a in e.approvals)
            SettingsTile(
              icon: a.decision == 'approve' ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: a.decision == 'approve' ? AppColors.success : AppColors.danger,
              title: '${a.stage == 'design' ? 'التصميم' : 'الإنتاج'} · ${a.by ?? ''}',
              subtitle: a.comment,
            ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (canEdit)
              FilledButton(onPressed: () => act('submit', 'اتقدّم للمراجعة'), child: const Text('تقديم للمراجعة')),
            if (e.canReview) ...[
              FilledButton(
                onPressed: () => _review(context, ref, key, approve: true),
                child: Text(e.status == 'design_review' ? 'اعتماد التصميم' : 'اعتماد الإنتاج'),
              ),
              OutlinedButton(
                onPressed: () => _review(context, ref, key, approve: false),
                child: const Text('رفض'),
              ),
            ],
            if (!e.canReview && (e.status == 'design_review' || e.status == 'production_review') && mine)
              const HintBanner('اللي كتب التغيير مايعتمدوش. مستني المراجعين.'),
            if (e.status == 'approved' && !e.isEcr && overview.can(HwCaps.releaseBom))
              FilledButton.icon(
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('Release (BOM revision جديد)'),
                onPressed: () => act('release', 'اتعمل BOM revision جديد'),
              ),
            if (e.status == 'rejected' && mine && canSubmit)
              OutlinedButton(onPressed: () => act('reopen', 'رجع draft'), child: const Text('تعديل وإعادة تقديم')),
            if (!const {'released', 'cancelled'}.contains(e.status) && canCancel)
              TextButton(
                onPressed: () => act('cancel', 'اتلغى'),
                child: const Text('إلغاء', style: TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref, ProjectKey key, {required bool approve}) async {
    final values = await askForm(context, title: approve ? 'اعتماد' : 'رفض', submit: 'تأكيد', fields: [
      FormFieldSpec('comment', approve ? 'تعليق' : 'سبب الرفض', required: !approve, maxLength: 2000, multiline: true),
    ]);
    if (values == null || !context.mounted) return;
    await hwRun(context, ref, key,
        (api) => api.reviewEco(gid, pid, eid, approve: approve, comment: values['comment']),
        done: approve ? 'اتعتمد' : 'اترفض');
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref, ProjectKey key) async {
    const actions = {'add': 'إضافة قطعة', 'change': 'تغيير قطعة بقطعة (revision جديد)', 'remove': 'إزالة قطعة'};
    final action = await pickOne<String>(context,
        title: 'نوع التغيير', options: actions.keys.toList(), label: (a) => actions[a]!);
    if (action == null || !context.mounted) return;
    final parts = await ref.read(hwPartsProvider(key).future);
    if (!context.mounted) return;
    HwPart? from;
    HwPart? to;
    if (action != 'add') {
      from = await pickOne<HwPart>(context,
          title: 'القطعة الحالية', options: parts, label: (p) => p.label, subtitle: (p) => p.description);
      if (from == null || !context.mounted) return;
    }
    if (action != 'remove') {
      to = await pickOne<HwPart>(context,
          title: action == 'add' ? 'القطعة' : 'القطعة الجديدة',
          options: parts.where((p) => p.id != from?.id).toList(),
          label: (p) => p.label,
          subtitle: (p) => p.description);
      if (to == null || !context.mounted) return;
    }
    int? quantity;
    if (action == 'add') {
      final values = await askForm(context, title: to!.label, fields: const [
        FormFieldSpec('quantity', 'الكمية', required: true, number: true, initial: '1'),
      ]);
      if (values == null || !context.mounted) return;
      quantity = int.tryParse(values['quantity']!);
    }
    await hwRun(context, ref, key,
        (api) => api.addEcoItem(gid, pid, eid,
            action: action, fromPartId: from?.id, toPartId: to?.id, quantity: quantity));
  }
}

// --- build -------------------------------------------------------------------

/// `/g/:gid/p/:pid/builds/:bid` — status, units, results per unit.
class BuildPage extends ConsumerWidget {
  const BuildPage({super.key, required this.gid, required this.pid, required this.bid});
  final String gid;
  final String pid;
  final String bid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (gid: gid, pid: pid);
    return _HwScope(
      gid: gid,
      pid: pid,
      builder: (context, overview) {
        final builds = ref.watch(hwBuildsProvider(key));
        final units = ref.watch(hwUnitsProvider((gid: gid, pid: pid, id: bid)));
        HwBuild? build;
        for (final b in builds.value ?? const <HwBuild>[]) {
          if (b.id == bid) build = b;
        }
        final canManage = overview.can(HwCaps.manageBuilds);
        return AppScreen(
          title: build?.name ?? 'Build',
          subtitle: build == null ? null : 'BOM rev ${build.bomRev ?? '?'} · ${build.quantity} وحدة',
          floatingActionButton: canManage && build != null && build.units < build.quantity
              ? FloatingActionButton.extended(
                  onPressed: () => _addUnits(context, ref, key, build!),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('وحدات'),
                )
              : null,
          children: [
            if (build != null &&
                const {'planned', 'parts_ordered'}.contains(build.status) &&
                (overview.can(HwCaps.manageBuilds) || overview.can('inventory.move'))) ...[
              FilledButton.icon(
                icon: const Icon(Icons.outbox_outlined),
                label: const Text('صرف القطع المحجوزة وبدء التجميع'),
                onPressed: () => invRun(context, ref, gid,
                    (api) => api.issueBuild(gid, pid, bid),
                    done: 'القطع اتصرفت والـ build بقى بيتجمّع'),
              ),
              const SizedBox(height: 12),
            ],
            if (build != null) ...[
              Row(children: [
                Expanded(child: Text('الحالة', style: Theme.of(context).textTheme.titleSmall)),
                if (canManage)
                  DropdownButton<String>(
                    value: build.status,
                    items: [
                      for (final e in buildStatusLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => v == null
                        ? null
                        : hwRun(context, ref, key, (api) => api.setBuildStatus(gid, pid, bid, v)),
                  )
                else
                  StatusChip(build.statusLabel),
              ]),
              const SizedBox(height: 12),
            ],
            units.when(
              loading: () => const AppLoadingView(),
              error: (error, _) => AppErrorView(message: describeError(error)),
              data: (list) => list.isEmpty
                  ? const AppEmptyState(icon: Icons.qr_code_2_rounded, title: 'مفيش وحدات متسجلة')
                  : Column(
                      children: [
                        for (final u in list)
                          SettingsTile(
                            icon: Icons.circle,
                            color: unitColor(u.status),
                            title: u.serial,
                            subtitle: [
                              u.statusLabel,
                              if (u.firmwareVersion != null) 'FW ${u.firmwareVersion}',
                              if (u.location != null) u.location!,
                              '${u.results} نتيجة',
                            ].join(' · '),
                            onTap: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (_) => _UnitSheet(gid: gid, pid: pid, unit: u, overview: overview),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addUnits(BuildContext context, WidgetRef ref, ProjectKey key, HwBuild build) async {
    final left = build.quantity - build.units;
    final values = await askForm(context, title: 'تسجيل وحدات (فاضل $left)', fields: [
      FormFieldSpec('count', 'العدد', required: true, number: true, initial: '$left'),
      FormFieldSpec('prefix', 'بادئة السيريال', required: true, maxLength: 40, initial: build.name),
    ]);
    if (values == null || !context.mounted) return;
    await hwRun(context, ref, key,
        (api) => api.addUnits(gid, pid, bid,
            count: int.tryParse(values['count']!) ?? 0, prefix: values['prefix']!),
        done: 'الوحدات اتسجلت');
  }
}

class _UnitSheet extends ConsumerWidget {
  const _UnitSheet({required this.gid, required this.pid, required this.unit, required this.overview});
  final String gid;
  final String pid;
  final HwUnit unit;
  final HwOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (gid: gid, pid: pid);
    final results = ref.watch(hwUnitResultsProvider((gid: gid, pid: pid, id: unit.id)));
    final canRecord = overview.can(HwCaps.recordTests);
    final canEdit = canRecord || overview.can(HwCaps.manageBuilds);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(unit.serial, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${unit.statusLabel}${unit.firmwareVersion == null ? '' : ' · FW ${unit.firmwareVersion}'}'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (canRecord)
                FilledButton.icon(
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('تسجيل نتيجة'),
                  onPressed: () => _record(context, ref, key),
                ),
              if (canEdit)
                OutlinedButton(
                  onPressed: () async {
                    final values = await askForm(context, title: unit.serial, fields: [
                      FormFieldSpec('fw', 'إصدار الـ firmware', maxLength: 64, initial: unit.firmwareVersion),
                      FormFieldSpec('location', 'المكان', maxLength: 80, initial: unit.location),
                    ]);
                    if (values == null || !context.mounted) return;
                    final ok = await hwRun(context, ref, key,
                        (api) => api.updateUnit(gid, pid, unit.id,
                            firmwareVersion: values['fw'], location: values['location']));
                    if (ok && context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('تعديل'),
                ),
            ]),
            const SizedBox(height: 16),
            SectionLabel('النتايج'),
            results.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => AppErrorView(message: describeError(error)),
              data: (list) => list.isEmpty
                  ? const HintBanner('مفيش نتايج لسه.')
                  : Column(children: [
                      for (final r in list)
                        SettingsTile(
                          icon: r.passed ? Icons.check_circle_outline : Icons.cancel_outlined,
                          color: r.passed ? AppColors.success : AppColors.danger,
                          title: r.planTitle,
                          subtitle: [
                            if (r.firmwareVersion != null) 'FW ${r.firmwareVersion}',
                            if (r.recordedBy != null) r.recordedBy!,
                            if (r.notes != null) r.notes!,
                          ].join(' · '),
                        ),
                    ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _record(BuildContext context, WidgetRef ref, ProjectKey key) async {
    final plans = await ref.read(hwTestPlansProvider(key).future);
    if (!context.mounted) return;
    final plan = await pickOne<HwTestPlan>(context,
        title: 'خطة الاختبار', options: plans, label: (p) => p.title, subtitle: (p) => p.criteria ?? '');
    if (plan == null || !context.mounted) return;
    final passed = await pickOne<bool>(context,
        title: plan.title, options: const [true, false], label: (v) => v ? 'نجحت (pass)' : 'فشلت (fail)');
    if (passed == null || !context.mounted) return;
    final values = await askForm(context, title: passed ? 'نجاح' : 'فشل', fields: [
      FormFieldSpec('notes', passed ? 'ملاحظات' : 'إيه اللي فشل؟', required: !passed, maxLength: 2000, multiline: true),
    ]);
    if (values == null || !context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final ok = await hwRun(context, ref, key,
        (api) => api.recordResult(gid, pid, unit.id, planId: plan.id, passed: passed, notes: values['notes']),
        done: 'النتيجة اتسجلت');
    if (ok) {
      container.invalidate(hwUnitResultsProvider((gid: gid, pid: pid, id: unit.id)));
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

// --- phase template ----------------------------------------------------------

/// `/g/:gid/settings/phases` — the group's phase template. Edits reach the
/// phases projects have not started yet.
class PhaseTemplatesPage extends ConsumerStatefulWidget {
  const PhaseTemplatesPage({super.key, required this.gid});
  final String gid;

  @override
  ConsumerState<PhaseTemplatesPage> createState() => _PhaseTemplatesPageState();
}

class _PhaseTemplatesPageState extends ConsumerState<PhaseTemplatesPage> {
  bool _busy = false;

  Future<void> _run(Future<PhaseTemplates> Function(HardwareApi api) action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await action(ref.read(hardwareApiProvider));
      container.invalidate(phaseTemplatesProvider(widget.gid));
      container.invalidate(hwOverviewProvider);
      if (done != null && mounted) showSnack(context, done);
    } catch (error) {
      if (mounted) showSnack(context, describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<({String name, List<String> checklist})?> _edit({PhaseTemplate? initial}) async {
    final values = await askForm(context, title: initial == null ? 'مرحلة جديدة' : 'تعديل ${initial.name}', fields: [
      FormFieldSpec('name', 'الاسم', required: true, maxLength: 40, initial: initial?.name),
      FormFieldSpec('checklist', 'الـ checklist (بند في كل سطر)',
          multiline: true, initial: initial?.checklist.join('\n')),
    ]);
    if (values == null) return null;
    final items = values['checklist']!.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return (name: values['name']!, checklist: items);
  }

  @override
  Widget build(BuildContext context) {
    return GroupScope(
      gid: widget.gid,
      requires: Caps.manageWorkflow,
      builder: (context, access) {
        final templates = ref.watch(phaseTemplatesProvider(widget.gid));
        return AppScreen(
          title: 'مراحل المشاريع',
          subtitle: access.name,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _busy
                ? null
                : () async {
                    final draft = await _edit();
                    if (draft == null) return;
                    await _run((api) => api.addPhaseTemplate(widget.gid, name: draft.name, checklist: draft.checklist),
                        done: 'المرحلة اتضافت لكل المشاريع');
                  },
            icon: const Icon(Icons.add_rounded),
            label: const Text('مرحلة'),
          ),
          children: [
            const HintBanner(
              'كل مشروع بياخد نسخة من القالب ده. التعديل بيوصل للمراحل اللي لسه مابدأتش بس؛ '
              'اللي بدأت أو اتعملها gate بتفضل زي ما هي.',
            ),
            const SizedBox(height: 12),
            templates.when(
              loading: () => const AppLoadingView(),
              error: (error, _) => AppErrorView(message: describeError(error)),
              data: (t) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (from, to) {
                      final ids = [for (final p in t.live) p.id];
                      ids.insert(to, ids.removeAt(from));
                      _run((api) => api.reorderPhaseTemplates(widget.gid, ids));
                    },
                    children: [
                      for (final (i, p) in t.live.indexed)
                        SettingsTile(
                          key: ValueKey(p.id),
                          icon: Icons.flag_outlined,
                          title: p.name,
                          subtitle: p.checklist.isEmpty ? 'من غير checklist' : p.checklist.join(' · '),
                          onTap: _busy
                              ? null
                              : () async {
                                  final draft = await _edit(initial: p);
                                  if (draft == null) return;
                                  await _run((api) => api.updatePhaseTemplate(widget.gid, p.id,
                                      name: draft.name, checklist: draft.checklist));
                                },
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: 'أرشفة',
                              icon: const Icon(Icons.archive_outlined),
                              onPressed: _busy
                                  ? null
                                  : () => _run((api) => api.updatePhaseTemplate(widget.gid, p.id, archived: true),
                                      done: 'اتأرشفت'),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded)),
                            ),
                          ]),
                        ),
                    ],
                  ),
                  if (t.archived.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionLabel('مؤرشفة'),
                    for (final p in t.archived)
                      SettingsTile(
                        icon: Icons.flag_outlined,
                        title: p.name,
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run((api) => api.updatePhaseTemplate(widget.gid, p.id, archived: false)),
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
}
