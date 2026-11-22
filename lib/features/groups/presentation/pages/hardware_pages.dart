import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// `/g/:gid/p/:pid` in a hardware group: phases and gates, BOM, ECO, builds
/// and tests. The overview carries the caller's project capabilities; every
/// button below is shown from them (the API checks again).
class HardwareProjectPage extends ConsumerWidget {
  const HardwareProjectPage({super.key, required this.access, required this.pid});
  final GroupAccess access;
  final String pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (gid: access.id, pid: pid);
    final overview = ref.watch(hwOverviewProvider(key));
    final projects = ref.watch(groupProjectsProvider(access.id)).value ?? const [];
    var name = 'المشروع';
    var isPrivate = false;
    for (final p in projects) {
      if (p.id == pid) {
        name = p.name;
        isPrivate = p.isPrivate;
      }
    }
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name),
              Text(
                [access.name, if (isPrivate) 'خاص'].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'المهام',
              icon: const Icon(Icons.checklist_rounded),
              onPressed: () => context.push('/g/${access.id}/p/$pid/tasks'),
            ),
            if (access.can(Caps.manageGroup))
              IconButton(
                tooltip: 'إعدادات المشروع',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => context.push('/g/${access.id}/p/$pid/settings'),
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'المراحل'),
              Tab(text: 'BOM'),
              Tab(text: 'ECO'),
              Tab(text: 'Builds'),
              Tab(text: 'الاختبارات'),
            ],
          ),
        ),
        body: overview.when(
          skipLoadingOnReload: true,
          loading: () => const AppLoadingView(),
          error: (error, _) => AppErrorView(
            message: describeError(error),
            onRetry: () => ref.invalidate(hwOverviewProvider(key)),
          ),
          data: (data) => TabBarView(
            children: [
              _PhasesTab(projectKey: key, overview: data),
              _BomTab(projectKey: key, overview: data),
              _EcoTab(projectKey: key, overview: data),
              _BuildsTab(projectKey: key, overview: data),
              _TestsTab(projectKey: key, overview: data),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runs a write, refreshes the project, and reports failures.
Future<bool> hwRun(BuildContext context, WidgetRef ref, ProjectKey key,
    Future<void> Function(HardwareApi api) action,
    {String? done}) async {
  // Read before the await: the screen may be closed when the write ends.
  final container = ProviderScope.containerOf(context, listen: false);
  final api = ref.read(hardwareApiProvider);
  try {
    await action(api);
    refreshHardwareIn(container, key);
    if (done != null && context.mounted) showSnack(context, done);
    return true;
  } catch (error) {
    if (context.mounted) showSnack(context, describeError(error));
    return false;
  }
}

class _TabList extends StatelessWidget {
  const _TabList({required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: children,
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

// --- phases ------------------------------------------------------------------

class _PhasesTab extends ConsumerWidget {
  const _PhasesTab({required this.projectKey, required this.overview});
  final ProjectKey projectKey;
  final HwOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firmware = ref.watch(hwFirmwareProvider(projectKey));
    return _TabList(
      onRefresh: () async => refreshHardware(ref, projectKey),
      children: [
        Row(
          children: [
            StatTile(value: overview.releasedBom ?? '—', label: 'آخر BOM'),
            const SizedBox(width: 8),
            StatTile(value: '${overview.ecosInReview}', label: 'ECO في المراجعة', color: AppColors.warning),
            const SizedBox(width: 8),
            StatTile(
              value: '${overview.passedUnits}/${overview.units}',
              label: 'وحدات نجحت',
              color: overview.failedUnits > 0 ? AppColors.danger : AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionLabel('المراحل'),
        const SizedBox(height: 8),
        for (final phase in overview.phases)
          _PhaseCard(projectKey: projectKey, overview: overview, phase: phase),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SectionLabel('توافق الـ Firmware')),
            if (overview.can(HwCaps.firmwareLink))
              TextButton.icon(
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('ربط'),
                onPressed: () => _linkFirmware(context, ref),
              ),
          ],
        ),
        firmware.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(message: describeError(error)),
          data: (links) => links.isEmpty
              ? const HintBanner('مفيش firmware متسجل إنه اتختبر على revision معين.')
              : Column(
                  children: [
                    for (final l in links)
                      SettingsTile(
                        icon: Icons.memory_rounded,
                        title: '${l.firmwareTag} ↔ BOM rev ${l.bomRev}',
                        subtitle: [if (l.verifiedBy != null) l.verifiedBy!, if (l.note != null) l.note!]
                            .join(' · '),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _linkFirmware(BuildContext context, WidgetRef ref) async {
    final revisions = (await ref.read(hwBomRevisionsProvider(projectKey).future))
        .where((r) => !r.isDraft)
        .toList();
    if (!context.mounted) return;
    final rev = await pickOne<HwBomSummary>(context,
        title: 'اتختبر على أنهي BOM revision؟', options: revisions, label: (r) => 'rev ${r.rev}');
    if (rev == null || !context.mounted) return;
    final values = await askForm(context, title: 'Firmware ↔ rev ${rev.rev}', fields: const [
      FormFieldSpec('tag', 'الـ tag في GitHub', required: true, maxLength: 64, hint: 'v1.2.0'),
    ]);
    if (values == null || !context.mounted) return;
    await hwRun(context, ref, projectKey,
        (api) => api.linkFirmware(projectKey.gid, projectKey.pid, tag: values['tag']!, bomRevId: rev.id),
        done: 'اتسجل');
  }
}

class _PhaseCard extends ConsumerWidget {
  const _PhaseCard({required this.projectKey, required this.overview, required this.phase});
  final ProjectKey projectKey;
  final HwOverview overview;
  final HwPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canGate = overview.can(HwCaps.gateDecision);
    final canMove = canGate || overview.can(HwCaps.manageBuilds);
    final canTick = canMove || overview.can(HwCaps.editTasks);
    final current = phase.id == overview.currentPhaseId;
    return AppPanel(
      margin: const EdgeInsets.only(bottom: 10),
      accent: current ? AppColors.accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  phase.isActive && phase.round > 1 ? '${phase.name} (جولة ${phase.round})' : phase.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              StatusChip(phase.statusLabel, color: phaseColor(phase.status)),
            ],
          ),
          if (phase.checklist.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final (i, item) in phase.checklist.indexed)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: item.done,
                title: Text(item.text),
                onChanged: canTick && !phase.isClosed && phase.status != 'not_started'
                    ? (v) => hwRun(context, ref, projectKey,
                        (api) => api.updatePhase(projectKey.gid, projectKey.pid, phase.id,
                            checkIndex: i, checkDone: v ?? false))
                    : null,
              ),
          ],
          if (phase.decisions.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final d in phase.decisions)
              Text(
                '• ${gateDecisionLabels[d.decision]?.split(' — ').first ?? d.decision}'
                '${d.by == null ? '' : ' · ${d.by}'}${d.note == null ? '' : ' — ${d.note}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          if (!phase.isClosed && (canMove || canGate)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canMove && phase.status == 'not_started')
                  OutlinedButton(
                    onPressed: () => hwRun(context, ref, projectKey,
                        (api) => api.updatePhase(projectKey.gid, projectKey.pid, phase.id, status: 'in_progress')),
                    child: const Text('ابدأ المرحلة'),
                  ),
                if (canMove && phase.status == 'in_progress')
                  OutlinedButton(
                    onPressed: () => hwRun(context, ref, projectKey,
                        (api) => api.updatePhase(projectKey.gid, projectKey.pid, phase.id,
                            status: 'ready_for_review'),
                        done: 'المرحلة جاهزة للـ gate'),
                    child: const Text('جاهزة للـ gate'),
                  ),
                if (canMove && (phase.status == 'on_hold' || phase.status == 'ready_for_review'))
                  OutlinedButton(
                    onPressed: () => hwRun(context, ref, projectKey,
                        (api) => api.updatePhase(projectKey.gid, projectKey.pid, phase.id, status: 'in_progress')),
                    child: Text(phase.status == 'on_hold' ? 'استكمال' : 'رجوع للشغل'),
                  ),
                if (canGate && phase.isActive)
                  FilledButton(
                    onPressed: () => _gate(context, ref),
                    child: const Text('قرار الـ gate'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _gate(BuildContext context, WidgetRef ref) async {
    final open = phase.checklist.length - phase.doneItems;
    final decision = await pickOne<String>(
      context,
      title: open > 0 ? 'قرار ${phase.name} — فاضل $open بند في الـ checklist' : 'قرار ${phase.name}',
      options: gateDecisionLabels.keys.toList(),
      label: (d) => gateDecisionLabels[d]!,
    );
    if (decision == null || !context.mounted) return;
    final values = await askForm(context, title: gateDecisionLabels[decision]!, submit: 'تأكيد', fields: const [
      FormFieldSpec('note', 'ملاحظة', maxLength: 2000, multiline: true),
    ]);
    if (values == null || !context.mounted) return;
    await hwRun(context, ref, projectKey,
        (api) => api.decideGate(projectKey.gid, projectKey.pid, phase.id,
            decision: decision, note: values['note']),
        done: 'القرار اتسجل');
  }
}

// --- BOM ---------------------------------------------------------------------

class _BomTab extends ConsumerWidget {
  const _BomTab({required this.projectKey, required this.overview});
  final ProjectKey projectKey;
  final HwOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revisions = ref.watch(hwBomRevisionsProvider(projectKey));
    final parts = ref.watch(hwPartsProvider(projectKey));
    final canEdit = overview.can(HwCaps.editBom);
    final prices = overview.can(HwCaps.viewPrices);
    return _TabList(
      onRefresh: () async => refreshHardware(ref, projectKey),
      children: [
        Row(
          children: [
            Expanded(child: SectionLabel('الـ revisions')),
            if (canEdit && overview.draftBom == null)
              TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Draft جديد'),
                onPressed: () async {
                  final container = ProviderScope.containerOf(context, listen: false);
                  try {
                    final bom = await ref.read(hardwareApiProvider).newBomDraft(projectKey.gid, projectKey.pid);
                    refreshHardwareIn(container, projectKey);
                    if (context.mounted) {
                      context.push('/g/${projectKey.gid}/p/${projectKey.pid}/bom/${bom.id}');
                    }
                  } catch (error) {
                    if (context.mounted) showSnack(context, describeError(error));
                  }
                },
              ),
          ],
        ),
        revisions.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(message: describeError(error)),
          data: (list) => list.isEmpty
              ? const HintBanner('مفيش BOM لسه. ضيف القطع واعمل draft.')
              : Column(
                  children: [
                    for (final r in list)
                      SettingsTile(
                        icon: r.isDraft ? Icons.edit_note_rounded : Icons.lock_outline_rounded,
                        color: r.isDraft ? AppColors.warning : AppColors.success,
                        title: 'rev ${r.rev}${r.isDraft ? ' (draft)' : ''}',
                        subtitle: '${r.lines} قطعة · ${r.quantity} إجمالي${r.note == null ? '' : ' · ${r.note}'}',
                        onTap: () => context.push('/g/${projectKey.gid}/p/${projectKey.pid}/bom/${r.id}'),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SectionLabel('القطع')),
            if (canEdit)
              TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('قطعة'),
                onPressed: () => _addPart(context, ref, prices),
              ),
          ],
        ),
        parts.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(message: describeError(error)),
          data: (list) => list.isEmpty
              ? const HintBanner('مفيش قطع.')
              : Column(
                  children: [
                    for (final p in list)
                      SettingsTile(
                        icon: Icons.developer_board_outlined,
                        title: '${p.label} — ${p.description}',
                        subtitle: [
                          partLifecycleLabels[p.lifecycle] ?? p.lifecycle,
                          if (p.mpn != null) p.mpn!,
                          if (p.vendor != null) p.vendor!,
                          if (prices && p.unitCostCents != null) formatCents(p.unitCostCents),
                        ].join(' · '),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _addPart(BuildContext context, WidgetRef ref, bool prices) async {
    final values = await askForm(context, title: 'قطعة جديدة', fields: [
      const FormFieldSpec('number', 'رقم القطعة', required: true, maxLength: 64),
      const FormFieldSpec('revision', 'الـ revision', maxLength: 8, hint: 'A'),
      const FormFieldSpec('description', 'الوصف', required: true, maxLength: 200),
      const FormFieldSpec('mpn', 'MPN', maxLength: 80),
      const FormFieldSpec('vendor', 'المورّد', maxLength: 80),
      if (prices) const FormFieldSpec('cost', 'تكلفة الوحدة', number: true),
    ]);
    if (values == null || !context.mounted) return;
    await hwRun(context, ref, projectKey,
        (api) => api.createPart(projectKey.gid, projectKey.pid,
            partNumber: values['number']!,
            revision: values['revision'],
            description: values['description']!,
            mpn: values['mpn'],
            vendor: values['vendor'],
            unitCostCents: parseCents(values['cost'])),
        done: 'القطعة اتضافت');
  }
}

// --- ECO ---------------------------------------------------------------------

class _EcoTab extends ConsumerWidget {
  const _EcoTab({required this.projectKey, required this.overview});
  final ProjectKey projectKey;
  final HwOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ecos = ref.watch(hwEcosProvider(projectKey));
    final canEco = overview.can(HwCaps.submitEco);
    final canEcr = canEco || overview.can(HwCaps.submitEcr);
    return _TabList(
      onRefresh: () async => refreshHardware(ref, projectKey),
      children: [
        if (canEcr)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text(canEco ? 'ECO جديد' : 'طلب تغيير (ECR)'),
              onPressed: () => _create(context, ref, canEco),
            ),
          ),
        const SizedBox(height: 12),
        ecos.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(message: describeError(error)),
          data: (list) => list.isEmpty
              ? const AppEmptyState(icon: Icons.change_circle_outlined, title: 'مفيش تغييرات هندسية')
              : Column(
                  children: [
                    for (final e in list)
                      SettingsTile(
                        icon: e.kind == 'ecr' ? Icons.report_outlined : Icons.change_circle_outlined,
                        color: ecoColor(e.status),
                        title: '${e.code} — ${e.title}',
                        subtitle: '${e.statusLabel} · ${e.items} تغيير',
                        onTap: () => context.push('/g/${projectKey.gid}/p/${projectKey.pid}/eco/${e.id}'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref, bool canEco) async {
    var kind = 'ecr';
    if (canEco) {
      final picked = await pickOne<String>(context,
          title: 'نوع التغيير',
          options: const ['eco', 'ecr'],
          label: (k) => k == 'eco' ? 'ECO — تغيير بقطع محددة' : 'ECR — طلب تغيير (من غير تعديل BOM)');
      if (picked == null || !context.mounted) return;
      kind = picked;
    }
    final values = await askForm(context, title: kind == 'eco' ? 'ECO جديد' : 'ECR جديد', fields: const [
      FormFieldSpec('title', 'العنوان', required: true, maxLength: 200),
      FormFieldSpec('reason', 'السبب', maxLength: 5000, multiline: true),
      FormFieldSpec('impact', 'الأثر (تكلفة، مخزون، firmware)', maxLength: 5000, multiline: true),
    ]);
    if (values == null || !context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final eco = await ref.read(hardwareApiProvider).createEco(projectKey.gid, projectKey.pid,
          title: values['title']!, kind: kind, reason: values['reason'], impact: values['impact']);
      refreshHardwareIn(container, projectKey);
      if (context.mounted) context.push('/g/${projectKey.gid}/p/${projectKey.pid}/eco/${eco.id}');
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(error));
    }
  }
}

// --- builds ------------------------------------------------------------------

class _BuildsTab extends ConsumerWidget {
  const _BuildsTab({required this.projectKey, required this.overview});
  final ProjectKey projectKey;
  final HwOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builds = ref.watch(hwBuildsProvider(projectKey));
    return _TabList(
      onRefresh: () async => refreshHardware(ref, projectKey),
      children: [
        if (overview.can(HwCaps.manageBuilds))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Build جديد'),
              onPressed: overview.releasedBom == null
                  ? () => showSnack(context, 'الـ build محتاج BOM اتعمله release الأول.')
                  : () => _create(context, ref),
            ),
          ),
        const SizedBox(height: 12),
        builds.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(message: describeError(error)),
          data: (list) => list.isEmpty
              ? const AppEmptyState(icon: Icons.precision_manufacturing_outlined, title: 'مفيش builds')
              : Column(
                  children: [
                    for (final b in list)
                      SettingsTile(
                        icon: Icons.precision_manufacturing_outlined,
                        title: '${b.name} — ${b.statusLabel}',
                        subtitle: [
                          'BOM rev ${b.bomRev ?? '?'}',
                          '${b.units}/${b.quantity} وحدة',
                          if (b.units > 0) '${b.passed} نجحت · ${b.failed} فشلت',
                          if (b.cm != null) b.cm!,
                        ].join(' · '),
                        onTap: () => context.push('/g/${projectKey.gid}/p/${projectKey.pid}/builds/${b.id}'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final revisions =
        (await ref.read(hwBomRevisionsProvider(projectKey).future)).where((r) => !r.isDraft).toList();
    if (!context.mounted) return;
    final rev = await pickOne<HwBomSummary>(context,
        title: 'من أنهي BOM؟', options: revisions, label: (r) => 'rev ${r.rev}');
    if (rev == null || !context.mounted) return;
    final current = overview.currentPhase;
    final values = await askForm(context, title: 'Build من rev ${rev.rev}', fields: [
      FormFieldSpec('name', 'الاسم', required: true, maxLength: 40,
          initial: current == null ? null : '${current.name}${current.round}'),
      const FormFieldSpec('quantity', 'الكمية', required: true, number: true),
      const FormFieldSpec('cm', 'المصنّع (CM)', maxLength: 80),
    ]);
    if (values == null || !context.mounted) return;
    await hwRun(context, ref, projectKey,
        (api) => api.createBuild(projectKey.gid, projectKey.pid,
            name: values['name']!,
            bomRevId: rev.id,
            quantity: int.tryParse(values['quantity']!) ?? 0,
            phaseId: current?.id,
            cm: values['cm']),
        done: 'الـ build اتعمل');
  }
}

// --- tests -------------------------------------------------------------------

class _TestsTab extends ConsumerWidget {
  const _TestsTab({required this.projectKey, required this.overview});
  final ProjectKey projectKey;
  final HwOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(hwTestPlansProvider(projectKey));
    final canCreate = overview.can(HwCaps.recordTests) || overview.can(HwCaps.approveTests);
    return _TabList(
      onRefresh: () async => refreshHardware(ref, projectKey),
      children: [
        if (canCreate)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('خطة اختبار'),
              onPressed: () async {
                final values = await askForm(context, title: 'خطة اختبار', fields: const [
                  FormFieldSpec('title', 'العنوان', required: true, maxLength: 200),
                  FormFieldSpec('criteria', 'معايير القبول', maxLength: 5000, multiline: true),
                ]);
                if (values == null || !context.mounted) return;
                await hwRun(context, ref, projectKey,
                    (api) => api.createTestPlan(projectKey.gid, projectKey.pid,
                        title: values['title']!, criteria: values['criteria']),
                    done: 'الخطة اتضافت');
              },
            ),
          ),
        const SizedBox(height: 12),
        const HintBanner('النتايج بتتسجل على كل وحدة من شاشة الـ build.'),
        const SizedBox(height: 8),
        plans.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(message: describeError(error)),
          data: (list) => list.isEmpty
              ? const AppEmptyState(icon: Icons.fact_check_outlined, title: 'مفيش خطط اختبار')
              : Column(
                  children: [
                    for (final p in list)
                      SettingsTile(
                        icon: p.approved ? Icons.verified_outlined : Icons.fact_check_outlined,
                        color: p.approved ? AppColors.success : AppColors.textMuted,
                        title: p.title,
                        subtitle: [
                          p.approved ? 'معتمدة' : 'مستنية اعتماد',
                          '${p.passed} نجاح · ${p.failed} فشل',
                          if (p.criteria != null) p.criteria!,
                        ].join(' · '),
                        trailing: !p.approved && overview.can(HwCaps.approveTests)
                            ? TextButton(
                                onPressed: () => hwRun(context, ref, projectKey,
                                    (api) => api.approveTestPlan(projectKey.gid, projectKey.pid, p.id),
                                    done: 'اتعتمدت'),
                                child: const Text('اعتماد'),
                              )
                            : null,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
