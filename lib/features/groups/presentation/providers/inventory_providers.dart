import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/inventory_api.dart';
import '../../domain/inventory_models.dart';
import 'group_providers.dart';
import 'hardware_providers.dart';

void _bind(Ref ref) => ref.watch(authNotifierProvider.select((state) => state.value?.id));

final invSettingsProvider = FutureProvider.family<InvSettings, String>((ref, gid) {
  _bind(ref);
  return ref.watch(inventoryApiProvider).settings(gid);
});

final vendorsProvider = FutureProvider.family<Vendors, String>((ref, gid) {
  _bind(ref);
  return ref.watch(inventoryApiProvider).vendors(gid);
});

final stockProvider = FutureProvider.family<StockView, String>((ref, gid) {
  _bind(ref);
  return ref.watch(inventoryApiProvider).stock(gid);
});

final movementsProvider = FutureProvider.family<List<StockMovement>, String>((ref, gid) {
  _bind(ref);
  return ref.watch(inventoryApiProvider).movements(gid);
});

final demandProvider = FutureProvider.family<List<DemandLine>, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(inventoryApiProvider).demand(key.gid, key.pid);
});

final posProvider = FutureProvider.family<List<PoSummary>, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(inventoryApiProvider).pos(key.gid, key.pid);
});

final poProvider = FutureProvider.family<PurchaseOrder, HwItemKey>((ref, key) {
  _bind(ref);
  return ref.watch(inventoryApiProvider).po(key.gid, key.pid, key.id);
});

final reservationsProvider = FutureProvider.family<List<Reservation>, ProjectKey>((ref, key) {
  _bind(ref);
  return ref.watch(inventoryApiProvider).reservations(key.gid, key.pid);
});

/// After a stock-changing write: the group's stock and every project view
/// built on it (another project's demand shares the same shelf).
void refreshInventoryIn(ProviderContainer container, String gid) {
  container.invalidate(stockProvider(gid));
  container.invalidate(movementsProvider(gid));
  container.invalidate(vendorsProvider(gid));
  container.invalidate(invSettingsProvider(gid));
  container.invalidate(demandProvider);
  container.invalidate(posProvider);
  container.invalidate(poProvider);
  container.invalidate(reservationsProvider);
  container.invalidate(hwBuildsProvider);
  container.invalidate(hwOverviewProvider);
}
