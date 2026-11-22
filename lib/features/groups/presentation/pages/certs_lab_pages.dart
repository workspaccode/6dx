import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../data/certs_lab_api.dart';
import '../../domain/group_models.dart';
import '../../domain/hardware_models.dart';
import '../providers/group_providers.dart';
import '../providers/hardware_providers.dart';
import '../widgets/group_widgets.dart';
import '../widgets/hardware_widgets.dart';

Future<bool> _run(BuildContext context, WidgetRef ref, Future<void> Function(CertsLabApi api) action,
    {String? done}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final api = ref.read(certsLabApiProvider);
  try {
    await action(api);
    container.invalidate(certsProvider);
    container.invalidate(labAssetsProvider);
    container.invalidate(labBookingsProvider);
    if (done != null && context.mounted) showSnack(context, done);
    return true;
  } catch (error) {
    if (context.mounted) showSnack(context, describeError(error));
    return false;
  }
}

Color _certColor(Certification c) => switch (c.status) {
      'passed' => c.expiring ? AppColors.warning : AppColors.success,
      'failed' || 'expired' => AppColors.danger,
      _ => c.overdue ? AppColors.danger : AppColors.info,
    };

/// The "الشهادات" tab of a hardware project. The client reads it too
/// (status and dates only — the API leaves the rest out).
class CertificationsTab extends ConsumerWidget {
  const CertificationsTab({super.key, required this.projectKey});
  final ProjectKey projectKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certs = ref.watch(certsProvider(projectKey));
    return certs.when(
      skipLoadingOnReload: true,
      loading: () => const AppLoadingView(),
      error: (error, _) => AppErrorView(message: describeError(error)),
      data: (data) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (data.canManage)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('شهادة'),
                onPressed: () => _create(context, ref),
              ),
            ),
          const SizedBox(height: 12),
          const HintBanner('الشهادات بتاخد من 2 لـ 12 أسبوع والمعامل بتتحجز بدري: حط ميعاد التسليم بدري.'),
          const SizedBox(height: 8),
          if (data.certs.isEmpty) const AppEmptyState(icon: Icons.verified_outlined, title: 'مفيش شهادات'),
          for (final c in data.certs)
            SettingsTile(
              icon: c.status == 'passed' ? Icons.verified_rounded : Icons.verified_outlined,
              color: _certColor(c),
              title: '${c.standard}${c.region == null ? '' : ' (${c.region})'} — ${c.statusLabel}',
              subtitle: [
                if (c.lab != null) c.lab!,
                if (c.bomRev != null) 'BOM rev ${c.bomRev}',
                if (c.dueAt != null) 'التسليم ${c.dueAt}',
                if (c.overdue) 'متأخرة',
                if (c.certificateNumber != null) c.certificateNumber!,
                if (c.expiresAt != null) 'تنتهي ${c.expiresAt}',
                if (c.expiring) 'قربت تنتهي',
              ].join(' · '),
              onTap: data.canManage ? () => _update(context, ref, c) : null,
            ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final revisions =
        (await ref.read(hwBomRevisionsProvider(projectKey).future)).where((r) => !r.isDraft).toList();
    if (!context.mounted) return;
    final rev = revisions.isEmpty
        ? null
        : await pickOne<HwBomSummary>(context,
            title: 'هتتختبر على أنهي BOM revision؟', options: revisions, label: (r) => 'rev ${r.rev}');
    if (!context.mounted) return;
    final values = await askForm(context, title: 'شهادة جديدة', fields: const [
      FormFieldSpec('standard', 'الشهادة', required: true, maxLength: 40, hint: 'FCC / CE / UL'),
      FormFieldSpec('region', 'المنطقة', maxLength: 40, hint: 'US / EU'),
      FormFieldSpec('lab', 'المعمل', maxLength: 80),
      FormFieldSpec('due', 'ميعاد التسليم (YYYY-MM-DD)', maxLength: 10),
    ]);
    if (values == null || !context.mounted) return;
    await _run(context, ref,
        (api) => api.createCert(projectKey.gid, projectKey.pid, {
              'standard': values['standard'],
              if (values['region']!.isNotEmpty) 'region': values['region'],
              if (values['lab']!.isNotEmpty) 'lab': values['lab'],
              if (values['due']!.isNotEmpty) 'due_at': values['due'],
              if (rev != null) 'bom_rev_id': rev.id,
            }),
        done: 'الشهادة اتضافت');
  }

  Future<void> _update(BuildContext context, WidgetRef ref, Certification c) async {
    final status = await pickOne<String>(context,
        title: '${c.standard} — الحالة', options: certStatusLabels.keys.toList(), label: (s) => certStatusLabels[s]!);
    if (status == null || !context.mounted) return;
    final values = await askForm(context, title: certStatusLabels[status]!, fields: [
      if (status == 'passed') ...[
        FormFieldSpec('certified', 'تاريخ الاعتماد (YYYY-MM-DD)', required: true,
            maxLength: 10, initial: c.certifiedAt),
        FormFieldSpec('expires', 'تنتهي في (YYYY-MM-DD)', maxLength: 10, initial: c.expiresAt),
        FormFieldSpec('number', 'رقم الشهادة', maxLength: 80, initial: c.certificateNumber),
      ] else
        FormFieldSpec('due', 'ميعاد التسليم (YYYY-MM-DD)', maxLength: 10, initial: c.dueAt),
      FormFieldSpec('note', 'ملاحظة', maxLength: 2000, initial: c.note),
    ]);
    if (values == null || !context.mounted) return;
    await _run(context, ref,
        (api) => api.updateCert(projectKey.gid, projectKey.pid, c.id, {
              'status': status,
              if (values.containsKey('certified')) 'certified_at': values['certified'],
              if (values.containsKey('expires')) 'expires_at': values['expires'],
              if (values.containsKey('number')) 'certificate_number': values['number'],
              if (values.containsKey('due')) 'due_at': values['due'],
              'note': values['note'],
            }),
        done: 'اتحفظ');
  }
}

/// `/g/:gid/lab` — the group's lab equipment and its bookings (31 days).
class LabPage extends ConsumerWidget {
  const LabPage({super.key, required this.gid});
  final String gid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GroupScope(
      gid: gid,
      builder: (context, access) {
        if (access.type != GroupType.hardware || access.groupRole == GroupRole.guest) {
          return const AppScreen(
            title: 'المعمل',
            children: [AppEmptyState(icon: Icons.lock_outline_rounded, title: 'المعمل مش متاح هنا')],
          );
        }
        final assets = ref.watch(labAssetsProvider(gid));
        final bookings = ref.watch(labBookingsProvider(gid));
        final a = assets.value;
        return AppScreen(
          title: 'المعمل',
          subtitle: access.name,
          floatingActionButton: (a?.canBook ?? false) && a!.live.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () => _book(context, ref, a.live),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('حجز'),
                )
              : null,
          children: [
            Row(children: [
              Expanded(child: SectionLabel('الأجهزة')),
              if (a?.canManage ?? false)
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('جهاز'),
                  onPressed: () => _addAsset(context, ref),
                ),
            ]),
            assets.when(
              skipLoadingOnReload: true,
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => AppErrorView(message: describeError(error)),
              data: (list) => list.live.isEmpty
                  ? const HintBanner('مفيش أجهزة مسجلة.')
                  : Column(children: [
                      for (final asset in list.live)
                        SettingsTile(
                          icon: Icons.science_outlined,
                          title: asset.name,
                          subtitle: [if (asset.kind != null) asset.kind!, if (asset.location != null) asset.location!]
                              .join(' · '),
                          trailing: list.canManage
                              ? IconButton(
                                  tooltip: 'أرشفة (بتلغي الحجوزات الجاية)',
                                  icon: const Icon(Icons.archive_outlined),
                                  onPressed: () => _run(context, ref, (api) => api.archiveAsset(gid, asset.id),
                                      done: 'الجهاز اتأرشف'),
                                )
                              : null,
                        ),
                    ]),
            ),
            const SizedBox(height: 16),
            SectionLabel('الحجوزات (الـ 90 يوم الجايين)'),
            const SizedBox(height: 8),
            bookings.when(
              skipLoadingOnReload: true,
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => AppErrorView(message: describeError(error)),
              data: (b) => b.bookings.isEmpty
                  ? const HintBanner('مفيش حجوزات.')
                  : Column(children: [
                      for (final booking in b.bookings)
                        SettingsTile(
                          icon: Icons.event_outlined,
                          color: booking.mine ? AppColors.accent : AppColors.textMuted,
                          title: '${booking.assetName} · ${_span(booking.startsAt, booking.endsAt)}',
                          subtitle: [
                            if (booking.private) 'محجوز',
                            if (booking.by != null) booking.by!,
                            if (booking.projectName != null) booking.projectName!,
                            if (booking.purpose != null) booking.purpose!,
                          ].join(' · '),
                          trailing: booking.mine || b.canManage
                              ? IconButton(
                                  tooltip: 'إلغاء',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () =>
                                      _run(context, ref, (api) => api.cancelBooking(gid, booking.id), done: 'اتلغى'),
                                )
                              : null,
                        ),
                    ]),
            ),
          ],
        );
      },
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _fmt(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';
  static String _span(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day ? '${_fmt(a)} → ${_two(b.hour)}:${_two(b.minute)}' : '${_fmt(a)} → ${_fmt(b)}';

  Future<void> _addAsset(BuildContext context, WidgetRef ref) async {
    final values = await askForm(context, title: 'جهاز معمل', fields: const [
      FormFieldSpec('name', 'الاسم', required: true, maxLength: 80, hint: 'Thermal chamber'),
      FormFieldSpec('kind', 'النوع', maxLength: 40),
      FormFieldSpec('location', 'المكان', maxLength: 80),
    ]);
    if (values == null || !context.mounted) return;
    await _run(context, ref,
        (api) => api.addAsset(gid, name: values['name']!, kind: values['kind'], location: values['location']),
        done: 'اتضاف');
  }

  Future<void> _book(BuildContext context, WidgetRef ref, List<LabAsset> assets) async {
    final asset = await pickOne<LabAsset>(context, title: 'الجهاز', options: assets, label: (a) => a.name);
    if (asset == null || !context.mounted) return;
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null || !context.mounted) return;
    final values = await askForm(context, title: '${asset.name} — المدة', fields: const [
      FormFieldSpec('hours', 'عدد الساعات', required: true, number: true, initial: '2'),
      FormFieldSpec('purpose', 'الغرض', maxLength: 200),
    ]);
    if (values == null || !context.mounted) return;
    final start = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    final end = start.add(Duration(hours: int.tryParse(values['hours']!) ?? 1));
    await _run(context, ref,
        (api) => api.book(gid, assetId: asset.id, start: start, end: end, purpose: values['purpose']),
        done: 'اتحجز');
  }
}
