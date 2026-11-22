import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../data/inventory_api.dart';
import '../../domain/group_models.dart';
import '../../domain/hardware_models.dart';
import '../../domain/inventory_models.dart';
import '../providers/group_providers.dart';
import '../providers/hardware_providers.dart';
import '../providers/inventory_providers.dart';
import '../widgets/group_widgets.dart';
import '../widgets/hardware_widgets.dart';

/// Runs an inventory write and refreshes every view on the group's stock.
Future<bool> invRun(BuildContext context, WidgetRef ref, String gid,
    Future<void> Function(InventoryApi api) action,
    {String? done}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final api = ref.read(inventoryApiProvider);
  try {
    await action(api);
    refreshInventoryIn(container, gid);
    if (done != null && context.mounted) showSnack(context, done);
    return true;
  } catch (error) {
    if (context.mounted) showSnack(context, describeError(error));
    return false;
  }
}

String money(int? cents, String currency) => cents == null ? '—' : '${formatCents(cents)} $currency';

// --- group: stock, vendors, movements ------------------------------------------

/// `/g/:gid/inventory` — the group's shared shelf: stock per part and
/// location, vendors, the movement log, and the PO approval threshold.
class GroupInventoryPage extends ConsumerWidget {
  const GroupInventoryPage({super.key, required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupScope(
      gid: gid,
      builder: (context, access) {
        if (access.type != GroupType.hardware || access.groupRole == GroupRole.guest) {
          return const AppScreen(
            title: 'المخزن',
            children: [AppEmptyState(icon: Icons.lock_outline_rounded, title: 'المخزن مش متاح هنا')],
          );
        }
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text('المخزن والمشتريات · ${access.name}'),
              actions: [
                if (access.can(Caps.manageGroup))
                  IconButton(
                    tooltip: 'حد اعتماد أوامر الشراء',
                    icon: const Icon(Icons.rule_rounded),
                    onPressed: () => _settings(context, ref),
                  ),
              ],
              bottom: const TabBar(tabs: [Tab(text: 'الرصيد'), Tab(text: 'الموردين'), Tab(text: 'الحركات')]),
            ),
            body: TabBarView(children: [
              _StockTab(gid: gid),
              _VendorsTab(gid: gid),
              _MovementsTab(gid: gid),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _settings(BuildContext context, WidgetRef ref) async {
    final current = await ref.read(invSettingsProvider(gid).future);
    if (!context.mounted) return;
    final values = await askForm(context, title: 'اعتماد أوامر الشراء', fields: [
      FormFieldSpec('threshold', 'أمر الشراء من المبلغ ده وأكتر محتاج اعتماد',
          required: true, number: true, decimal: true, initial: formatCents(current.thresholdCents),
          hint: '0 = كل الأوامر محتاجة اعتماد'),
      FormFieldSpec('currency', 'العملة', required: true, maxLength: 3, initial: current.currency),
    ]);
    if (values == null || !context.mounted) return;
    await invRun(context, ref, gid,
        (api) => api.updateSettings(gid,
            thresholdCents: parseCents(values['threshold']), currency: values['currency']),
        done: 'اتحفظ');
  }
}

class _StockTab extends ConsumerWidget {
  const _StockTab({required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(stockProvider(gid));
    return stock.when(
      skipLoadingOnReload: true,
      loading: () => const AppLoadingView(),
      error: (error, _) => AppErrorView(message: describeError(error), onRetry: () => ref.invalidate(stockProvider(gid))),
      data: (view) => Scaffold(
        floatingActionButton: view.canMove
            ? FloatingActionButton.extended(
                onPressed: () => _move(context, ref, view),
                icon: const Icon(Icons.swap_vert_rounded),
                label: const Text('حركة'),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (view.entries.isEmpty)
              const AppEmptyState(icon: Icons.inventory_2_outlined, title: 'المخزن فاضي'),
            for (final e in view.entries)
              SettingsTile(
                icon: Icons.inventory_2_outlined,
                color: e.isShort ? AppColors.danger : AppColors.textMuted,
                title: e.partNumber,
                subtitle: [
                  'الرصيد ${e.onHand}',
                  'محجوز ${e.reserved}',
                  'متاح ${e.available}',
                  if (e.locations.isNotEmpty) e.locations.entries.map((l) => '${l.key}: ${l.value}').join('، '),
                ].join(' · '),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _move(BuildContext context, WidgetRef ref, StockView view) async {
    final kinds = {
      'receive': 'استلام (من غير أمر شراء)',
      'issue': 'صرف',
      'transfer': 'نقل بين مكانين',
      if (view.canAdjust) 'adjust': 'تسوية جرد (+ أو −)',
    };
    final kind = await pickOne<String>(context, title: 'نوع الحركة', options: kinds.keys.toList(), label: (k) => kinds[k]!);
    if (kind == null || !context.mounted) return;
    final values = await askForm(context, title: kinds[kind]!, fields: [
      const FormFieldSpec('part', 'رقم القطعة', required: true, maxLength: 64),
      FormFieldSpec('qty', kind == 'adjust' ? 'الكمية (سالب للنقص)' : 'الكمية',
          required: true, number: true, signed: kind == 'adjust'),
      FormFieldSpec('location', kind == 'transfer' ? 'من مكان' : 'المكان', maxLength: 40, hint: 'main'),
      if (kind == 'transfer') const FormFieldSpec('to', 'إلى مكان', required: true, maxLength: 40),
      FormFieldSpec('note', kind == 'adjust' ? 'السبب' : 'ملاحظة', required: kind == 'adjust', maxLength: 500),
    ]);
    if (values == null || !context.mounted) return;
    await invRun(context, ref, gid,
        (api) => api.move(gid,
            partNumber: values['part']!,
            kind: kind,
            qty: int.tryParse(values['qty']!) ?? 0,
            location: values['location'],
            toLocation: values['to'],
            note: values['note']),
        done: 'الحركة اتسجلت');
  }
}

class _VendorsTab extends ConsumerWidget {
  const _VendorsTab({required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(vendorsProvider(gid));
    return vendors.when(
      skipLoadingOnReload: true,
      loading: () => const AppLoadingView(),
      error: (error, _) => AppErrorView(message: describeError(error)),
      data: (v) => Scaffold(
        floatingActionButton: v.canManage
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final values = await askForm(context, title: 'مورّد جديد', fields: const [
                    FormFieldSpec('name', 'الاسم', required: true, maxLength: 80),
                    FormFieldSpec('lead', 'مدة التوريد (يوم)', number: true, initial: '14'),
                    FormFieldSpec('contact', 'بيانات التواصل', maxLength: 500),
                  ]);
                  if (values == null || !context.mounted) return;
                  await invRun(context, ref, gid,
                      (api) => api.addVendor(gid,
                          name: values['name']!,
                          leadDays: int.tryParse(values['lead'] ?? ''),
                          contact: values['contact']),
                      done: 'المورّد اتضاف');
                },
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('مورّد'),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const HintBanner('مدة التوريد بتتحسب لكل قطعة اسم المورّد بتاعها زي اسم المورّد هنا.'),
            const SizedBox(height: 8),
            if (v.vendors.isEmpty) const AppEmptyState(icon: Icons.store_outlined, title: 'مفيش موردين'),
            for (final vendor in v.vendors)
              SettingsTile(
                icon: Icons.store_outlined,
                color: vendor.archived ? AppColors.textDim : AppColors.textMuted,
                title: vendor.name,
                subtitle: [
                  '${vendor.leadDays} يوم توريد',
                  if (vendor.contact != null) vendor.contact!,
                  if (vendor.archived) 'متأرشف',
                ].join(' · '),
                trailing: v.canManage
                    ? TextButton(
                        onPressed: () => invRun(context, ref, gid,
                            (api) => api.archiveVendor(gid, vendor.id, archived: !vendor.archived)),
                        child: Text(vendor.archived ? 'استرجاع' : 'أرشفة'),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _MovementsTab extends ConsumerWidget {
  const _MovementsTab({required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(movementsProvider(gid));
    return movements.when(
      skipLoadingOnReload: true,
      loading: () => const AppLoadingView(),
      error: (error, _) => AppErrorView(message: describeError(error)),
      data: (list) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (list.isEmpty) const AppEmptyState(icon: Icons.history_rounded, title: 'مفيش حركات'),
          for (final m in list)
            SettingsTile(
              icon: m.qty > 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: m.qty > 0 ? AppColors.success : AppColors.warning,
              title: '${m.kindLabel} ${m.qty > 0 ? '+' : ''}${m.qty} · ${m.partNumber}',
              subtitle: [m.location, if (m.by != null) m.by!, if (m.note != null) m.note!].join(' · '),
            ),
        ],
      ),
    );
  }
}

// --- project: demand, POs, reservations ------------------------------------------

/// The "المشتريات" tab of a hardware project.
class ProjectPurchasingTab extends ConsumerWidget {
  const ProjectPurchasingTab({super.key, required this.projectKey, required this.overview});
  final ProjectKey projectKey;
  final HwOverview overview;

  String get gid => projectKey.gid;
  String get pid => projectKey.pid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demand = ref.watch(demandProvider(projectKey));
    final pos = ref.watch(posProvider(projectKey));
    final reservations = ref.watch(reservationsProvider(projectKey));
    final canPo = overview.can(InvCaps.createPo) || overview.can(InvCaps.requestPo);
    final canReserve = overview.can(HwCaps.manageBuilds);
    final prices = overview.can(HwCaps.viewPrices);
    return RefreshIndicator(
      onRefresh: () async => refreshInventoryIn(ProviderScope.containerOf(context, listen: false), gid),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(children: [
            Expanded(child: SectionLabel('الاحتياج (الـ builds المفتوحة × الـ BOM)')),
            TextButton.icon(
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('المخزن'),
              onPressed: () => context.push('/g/$gid/inventory'),
            ),
          ]),
          demand.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => AppErrorView(message: describeError(error)),
            data: (list) => list.isEmpty
                ? const HintBanner('مفيش builds مخططة محتاجة قطع.')
                : Column(children: [
                    for (final d in list)
                      SettingsTile(
                        icon: d.orderNow
                            ? Icons.warning_amber_rounded
                            : d.shortage > 0
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                        color: d.orderNow
                            ? AppColors.danger
                            : d.shortage > 0
                                ? AppColors.warning
                                : AppColors.success,
                        title: '${d.partNumber} — محتاج ${d.needed}',
                        subtitle: [
                          'محجوز ${d.reserved}',
                          'في الطريق ${d.onOrder}',
                          'متاح ${d.available}',
                          if (d.shortage > 0) 'عجز ${d.shortage}',
                          if (d.orderNow) 'اطلب دلوقتي',
                          if (!d.orderNow && d.orderBy != null && d.shortage > 0) 'اطلب قبل ${d.orderBy}',
                        ].join(' · '),
                      ),
                  ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: SectionLabel('أوامر الشراء')),
            if (canPo)
              TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('أمر شراء'),
                onPressed: () => _newPo(context, ref),
              ),
          ]),
          pos.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => AppErrorView(message: describeError(error)),
            data: (list) => list.isEmpty
                ? const HintBanner('مفيش أوامر شراء.')
                : Column(children: [
                    for (final p in list)
                      SettingsTile(
                        icon: Icons.receipt_long_outlined,
                        title: '${p.code} — ${p.vendor}',
                        subtitle: [
                          p.statusLabel,
                          '${p.lines} سطر',
                          if (prices && p.totalCents != null) money(p.totalCents, p.currency),
                          if (p.buildName != null) p.buildName!,
                        ].join(' · '),
                        onTap: () => context.push('/g/$gid/p/$pid/po/${p.id}'),
                      ),
                  ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: SectionLabel('الحجوزات')),
            if (canReserve)
              TextButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('حجز'),
                onPressed: () => _reserve(context, ref),
              ),
          ]),
          reservations.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => AppErrorView(message: describeError(error)),
            data: (list) => list.where((r) => r.isActive).isEmpty
                ? const HintBanner('مفيش قطع محجوزة.')
                : Column(children: [
                    for (final r in list.where((r) => r.isActive))
                      SettingsTile(
                        icon: Icons.bookmark_outline,
                        title: '${r.partNumber} × ${r.qty}',
                        subtitle: r.buildName ?? 'للمشروع (من غير build)',
                        trailing: canReserve
                            ? TextButton(
                                onPressed: () => invRun(context, ref, gid,
                                    (api) => api.releaseReservation(gid, pid, r.id),
                                    done: 'الحجز اتلغى'),
                                child: const Text('إلغاء'),
                              )
                            : null,
                      ),
                  ]),
          ),
        ],
      ),
    );
  }

  Future<void> _newPo(BuildContext context, WidgetRef ref) async {
    final vendors = (await ref.read(vendorsProvider(gid).future)).live;
    if (!context.mounted) return;
    if (vendors.isEmpty) {
      showSnack(context, 'ضيف مورّد الأول من شاشة المخزن.');
      return;
    }
    final vendor = await pickOne<Vendor>(context,
        title: 'المورّد', options: vendors, label: (v) => v.name, subtitle: (v) => '${v.leadDays} يوم توريد');
    if (vendor == null || !context.mounted) return;
    final builds = (await ref.read(hwBuildsProvider(projectKey).future))
        .where((b) => b.status != 'complete' && b.status != 'cancelled')
        .toList();
    if (!context.mounted) return;
    String? buildId;
    if (builds.isNotEmpty) {
      final picked = await pickOne<HwBuild?>(context,
          title: 'لأي build؟ (القطع بتتحجز ليه لما توصل)',
          options: [null, ...builds],
          label: (b) => b?.name ?? 'للمشروع عمومًا');
      if (!context.mounted) return;
      buildId = picked?.id;
    }
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final po = await ref.read(inventoryApiProvider).createPo(gid, pid, vendorId: vendor.id, buildId: buildId);
      refreshInventoryIn(container, gid);
      if (context.mounted) context.push('/g/$gid/p/$pid/po/${po.id}');
    } catch (error) {
      if (context.mounted) showSnack(context, describeError(error));
    }
  }

  Future<void> _reserve(BuildContext context, WidgetRef ref) async {
    final builds = (await ref.read(hwBuildsProvider(projectKey).future))
        .where((b) => b.status != 'complete' && b.status != 'cancelled')
        .toList();
    if (!context.mounted) return;
    final build = await pickOne<HwBuild>(context, title: 'الـ build', options: builds, label: (b) => b.name);
    if (build == null || !context.mounted) return;
    final values = await askForm(context, title: 'حجز لـ ${build.name}', fields: const [
      FormFieldSpec('part', 'رقم القطعة', required: true, maxLength: 64),
      FormFieldSpec('qty', 'الكمية', required: true, number: true),
    ]);
    if (values == null || !context.mounted) return;
    await invRun(context, ref, gid,
        (api) => api.reserve(gid, pid,
            partNumber: values['part']!, qty: int.tryParse(values['qty']!) ?? 0, buildId: build.id),
        done: 'اتحجز');
  }
}

/// `/g/:gid/p/:pid/po/:poid`
class PurchaseOrderPage extends ConsumerWidget {
  const PurchaseOrderPage({super.key, required this.gid, required this.pid, required this.poid});
  final String gid;
  final String pid;
  final String poid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupScope(
      gid: gid,
      builder: (context, access) {
        final overview = ref.watch(hwOverviewProvider((gid: gid, pid: pid)));
        final po = ref.watch(poProvider((gid: gid, pid: pid, id: poid)));
        final caps = overview.value;
        return po.when(
          skipLoadingOnReload: true,
          loading: () => const Scaffold(body: AppLoadingView()),
          error: (error, _) => AppScreen(title: 'أمر شراء', children: [AppErrorView(message: describeError(error))]),
          data: (p) {
            final can = caps?.can ?? (_) => false;
            final mine = p.createdBy == access.uid;
            final canEdit = p.isDraft && (can(InvCaps.createPo) || (mine && can(InvCaps.requestPo)));
            final prices = can(HwCaps.viewPrices);
            Future<void> act(String action, String done) =>
                invRun(context, ref, gid, (api) => api.poAction(gid, pid, poid, action), done: done);
            return AppScreen(
              title: '${p.code} — ${p.vendor}',
              subtitle: [p.statusLabel, if (p.buildName != null) p.buildName!].join(' · '),
              floatingActionButton: canEdit
                  ? FloatingActionButton.extended(
                      onPressed: () => _line(context, ref, prices),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('سطر'),
                    )
                  : null,
              children: [
                if (prices && p.totalCents != null)
                  Row(children: [StatTile(value: money(p.totalCents, p.currency), label: 'الإجمالي')]),
                const SizedBox(height: 12),
                if (p.lines.isEmpty) const HintBanner('أمر الشراء فاضي.'),
                for (final l in p.lines)
                  SettingsTile(
                    icon: Icons.developer_board_outlined,
                    color: l.open == 0 ? AppColors.success : AppColors.textMuted,
                    title: '${l.partNumber} × ${l.qty}',
                    subtitle: [
                      'وصل ${l.receivedQty}',
                      if (prices && l.unitCostCents != null) '${money(l.unitCostCents, p.currency)} للوحدة',
                    ].join(' · '),
                    trailing: canEdit
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => invRun(context, ref, gid,
                                (api) => api.removePoLine(gid, pid, poid, l.partNumber)),
                          )
                        : null,
                  ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (p.isDraft && can(InvCaps.createPo))
                    FilledButton(onPressed: () => act('submit', 'اتقدّم'), child: const Text('تقديم')),
                  if (p.isDraft && !can(InvCaps.createPo))
                    const HintBanner('المشتريات هي اللي بتكمّل أمر الشراء وتقدّمه.'),
                  if (p.canApprove)
                    FilledButton(onPressed: () => act('approve', 'اتعتمد واتطلب'), child: const Text('اعتماد')),
                  if (p.status == 'pending_approval' && !p.canApprove)
                    const HintBanner('مستني اعتماد من حد معاه صلاحية، غير اللي كتبه أو قدّمه.'),
                  if (p.canReceive && can(InvCaps.moveInventory))
                    FilledButton.icon(
                      icon: const Icon(Icons.move_to_inbox_outlined),
                      label: const Text('استلام'),
                      onPressed: () => _receive(context, ref, p),
                    ),
                  if ((p.status == 'partially_received' || p.status == 'received') && can(InvCaps.createPo))
                    OutlinedButton(onPressed: () => act('close', 'اتقفل'), child: const Text('قفل')),
                  if (const {'draft', 'pending_approval', 'ordered'}.contains(p.status) && can(InvCaps.createPo))
                    TextButton(
                      onPressed: () => act('cancel', 'اتلغى'),
                      child: const Text('إلغاء', style: TextStyle(color: AppColors.danger)),
                    ),
                ]),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _line(BuildContext context, WidgetRef ref, bool prices) async {
    final values = await askForm(context, title: 'سطر في أمر الشراء', fields: [
      const FormFieldSpec('part', 'رقم القطعة', required: true, maxLength: 64),
      const FormFieldSpec('qty', 'الكمية', required: true, number: true),
      if (prices) const FormFieldSpec('cost', 'سعر الوحدة', number: true, decimal: true),
    ]);
    if (values == null || !context.mounted) return;
    await invRun(context, ref, gid,
        (api) => api.setPoLine(gid, pid, poid, values['part']!,
            qty: int.tryParse(values['qty']!) ?? 0, unitCostCents: parseCents(values['cost'])));
  }

  Future<void> _receive(BuildContext context, WidgetRef ref, PurchaseOrder p) async {
    final open = p.lines.where((l) => l.open > 0).toList();
    final values = await askForm(context, title: 'اللي وصل', submit: 'استلام', fields: [
      const FormFieldSpec('location', 'المكان', maxLength: 40, hint: 'main'),
      for (final l in open)
        FormFieldSpec('qty:${l.partNumber}', '${l.partNumber} (فاضل ${l.open})',
            number: true, initial: '${l.open}'),
    ]);
    if (values == null || !context.mounted) return;
    final lines = <String, int>{
      for (final l in open) l.partNumber: int.tryParse(values['qty:${l.partNumber}'] ?? '') ?? 0,
    };
    await invRun(context, ref, gid,
        (api) => api.receive(gid, pid, poid, lines: lines, location: values['location']),
        done: 'الاستلام اتسجل');
  }
}
