import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/hardware_api.dart';
import '../../domain/hardware_models.dart';
import 'group_providers.dart';

/// One item of a project: a BOM revision, an ECO, a build, a unit.
typedef HwItemKey = ({String gid, String pid, String id});

void _bind(Ref ref) => ref.watch(authNotifierProvider.select((state) => state.value?.id));

final hwOverviewProvider = FutureProvider.family<HwOverview, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).overview(key.gid, key.pid);
});

final hwPartsProvider = FutureProvider.family<List<HwPart>, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).parts(key.gid, key.pid);
});

final hwBomRevisionsProvider =
    FutureProvider.family<List<HwBomSummary>, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).bomRevisions(key.gid, key.pid);
});

final hwBomProvider = FutureProvider.family<HwBom, HwItemKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).bom(key.gid, key.pid, key.id);
});

final hwEcosProvider = FutureProvider.family<List<HwEcoSummary>, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).ecos(key.gid, key.pid);
});

final hwEcoProvider = FutureProvider.family<HwEco, HwItemKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).eco(key.gid, key.pid, key.id);
});

final hwBuildsProvider = FutureProvider.family<List<HwBuild>, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).builds(key.gid, key.pid);
});

final hwUnitsProvider = FutureProvider.family<List<HwUnit>, HwItemKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).units(key.gid, key.pid, key.id);
});

final hwUnitResultsProvider =
    FutureProvider.autoDispose.family<List<HwTestResult>, HwItemKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).unitResults(key.gid, key.pid, key.id);
});

final hwTestPlansProvider = FutureProvider.family<List<HwTestPlan>, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).testPlans(key.gid, key.pid);
});

final hwFirmwareProvider = FutureProvider.family<List<HwFirmwareLink>, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).firmware(key.gid, key.pid);
});

final phaseTemplatesProvider = FutureProvider.family<PhaseTemplates, String>((ref, gid) {
  _bind(ref);
  return ref.watch(hardwareApiProvider).phaseTemplates(gid);
});

/// After any write: refresh the project's hardware data. Cheap (one project)
/// and avoids stale counters on the overview.
void refreshHardware(WidgetRef ref, ProjectKey key) =>
    refreshHardwareIn(ref.read(_containerProvider), key);

/// The same through the container: safe after an await, when the widget
/// that started the write may be gone (its `ref` is then unusable, and the
/// providers here are kept alive, so a skipped refresh would stay stale).
void refreshHardwareIn(ProviderContainer container, ProjectKey key) {
  container.invalidate(hwOverviewProvider(key));
  container.invalidate(hwPartsProvider(key));
  container.invalidate(hwBomRevisionsProvider(key));
  container.invalidate(hwEcosProvider(key));
  container.invalidate(hwBuildsProvider(key));
  container.invalidate(hwTestPlansProvider(key));
  container.invalidate(hwFirmwareProvider(key));
  container.invalidate(hwBomProvider);
  container.invalidate(hwEcoProvider);
  container.invalidate(hwUnitsProvider);
}

final _containerProvider = Provider<ProviderContainer>((ref) => ref.container);
