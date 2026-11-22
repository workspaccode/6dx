import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/hardware_models.dart';
import '../providers/hardware_providers.dart';
import '../widgets/group_widgets.dart';
import '../widgets/hardware_widgets.dart';
import 'hardware_pages.dart';

/// `/g/:gid/p/:pid/parts/:partid` — a part: its children when it is an
/// assembly, and where it is used (assemblies, BOM revisions, builds).
class PartPage extends ConsumerWidget {
  const PartPage({super.key, required this.gid, required this.pid, required this.partId});
  final String gid;
  final String pid;
  final String partId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (gid: gid, pid: pid);
    final item = (gid: gid, pid: pid, id: partId);
    final overview = ref.watch(hwOverviewProvider(key)).value;
    final parts = ref.watch(hwPartsProvider(key)).value ?? const <HwPart>[];
    final children = ref.watch(hwPartChildrenProvider(item));
    final used = ref.watch(hwWhereUsedProvider(item));
    HwPart? part;
    for (final p in parts) {
      if (p.id == partId) part = p;
    }
    final canEdit = overview?.can(HwCaps.editBom) ?? false;
    return AppScreen(
      title: part?.label ?? 'القطعة',
      subtitle: part?.description,
      children: [
        children.when(
          skipLoadingOnReload: true,
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(message: describeError(error)),
          data: (c) {
            final editable = canEdit && !c.frozen && part?.lifecycle != 'production' && part?.lifecycle != 'obsolete';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: SectionLabel(c.children.isEmpty ? 'المكونات' : 'المكونات (assembly)')),
                  if (editable)
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('مكوّن'),
                      onPressed: () => _addChild(context, ref, parts),
                    ),
                ]),
                if (c.frozen)
                  const HintBanner(
                    'القطعة دي جوه BOM اتعمله release، فمكوناتها ثابتة. علشان تغيّرها اعمل revision جديد للقطعة.',
                    color: AppColors.warning,
                  ),
                if (c.children.isEmpty)
                  const HintBanner('قطعة بتتشتري (مالهاش مكونات). ضيف مكونات علشان تبقى assembly.'),
                for (final child in c.children)
                  SettingsTile(
                    icon: child.isAssembly ? Icons.account_tree_outlined : Icons.developer_board_outlined,
                    title: '${child.partNumber} rev ${child.revision} × ${child.quantity}',
                    subtitle: [child.description, if (child.refDesignators != null) child.refDesignators!].join(' · '),
                    onTap: () => context.push('/g/$gid/p/$pid/parts/${child.partId}'),
                    trailing: editable
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => hwRun(context, ref, key,
                                (api) => api.removePartChild(gid, pid, partId, child.partId)),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SectionLabel('مستخدمة فين'),
        const SizedBox(height: 8),
        used.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(message: describeError(error)),
          data: (u) => u.isUnused
              ? const HintBanner('القطعة دي مش مستخدمة في أي BOM.')
              : Column(children: [
                  for (final a in u.assemblies)
                    SettingsTile(
                      icon: Icons.account_tree_outlined,
                      title: a.label,
                      subtitle: a.level == 1 ? 'جوه الـ assembly ده مباشرة' : 'على بُعد ${a.level} مستويات',
                      onTap: () => context.push('/g/$gid/p/$pid/parts/${a.partId}'),
                    ),
                  for (final r in u.revisions)
                    SettingsTile(
                      icon: r.status == 'draft' ? Icons.edit_note_rounded : Icons.lock_outline_rounded,
                      title: 'BOM rev ${r.rev}${r.status == 'draft' ? ' (draft)' : ''}',
                      onTap: () => context.push('/g/$gid/p/$pid/bom/${r.id}'),
                    ),
                  for (final b in u.builds)
                    SettingsTile(
                      icon: Icons.precision_manufacturing_outlined,
                      title: '${b.name} · BOM rev ${b.bomRev}',
                      subtitle: buildStatusLabels[b.status] ?? b.status,
                      onTap: () => context.push('/g/$gid/p/$pid/builds/${b.id}'),
                    ),
                ]),
        ),
      ],
    );
  }

  Future<void> _addChild(BuildContext context, WidgetRef ref, List<HwPart> parts) async {
    final child = await pickOne<HwPart>(context,
        title: 'المكوّن',
        options: parts.where((p) => p.id != partId).toList(),
        label: (p) => p.label,
        subtitle: (p) => p.description);
    if (child == null || !context.mounted) return;
    final values = await askForm(context, title: child.label, fields: const [
      FormFieldSpec('quantity', 'الكمية في الـ assembly', required: true, number: true, initial: '1'),
      FormFieldSpec('refs', 'Reference designators', maxLength: 500),
    ]);
    if (values == null || !context.mounted) return;
    await hwRun(context, ref, (gid: gid, pid: pid),
        (api) => api.setPartChild(gid, pid, partId, child.id,
            quantity: int.tryParse(values['quantity']!) ?? 1, refDesignators: values['refs']));
  }
}

/// `/g/:gid/p/:pid/bom/:rid/tree` — the exploded revision and the flat list
/// of what is bought per unit.
class BomTreePage extends ConsumerWidget {
  const BomTreePage({super.key, required this.gid, required this.pid, required this.rid});
  final String gid;
  final String pid;
  final String rid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(hwBomTreeProvider((gid: gid, pid: pid, id: rid)));
    return tree.when(
      loading: () => const Scaffold(body: AppLoadingView()),
      error: (error, _) => AppScreen(title: 'شجرة الـ BOM', children: [AppErrorView(message: describeError(error))]),
      data: (t) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('شجرة الـ BOM'),
            bottom: const TabBar(tabs: [Tab(text: 'الشجرة'), Tab(text: 'اللي بيتشتري')]),
          ),
          body: TabBarView(children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final n in t.nodes)
                  Padding(
                    padding: EdgeInsetsDirectional.only(start: 20.0 * n.level),
                    child: SettingsTile(
                      icon: n.isAssembly ? Icons.account_tree_outlined : Icons.developer_board_outlined,
                      color: n.isAssembly ? AppColors.info : AppColors.textMuted,
                      title: '${n.partNumber} rev ${n.revision} × ${n.quantity}',
                      subtitle: n.description,
                    ),
                  ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (t.totalCostCents != null)
                  Row(children: [StatTile(value: formatCents(t.totalCostCents), label: 'تكلفة الوحدة')]),
                const SizedBox(height: 8),
                for (final l in t.leaves)
                  SettingsTile(
                    icon: Icons.shopping_cart_outlined,
                    title: '${l.partNumber} rev ${l.revision} × ${l.quantity}',
                    subtitle: [l.description, if (l.unitCostCents != null) formatCents(l.unitCostCents)].join(' · '),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
