import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/current_workspace.dart';
import '../domain/hardware_models.dart';
import '../domain/inventory_models.dart';

/// Group stock / vendors (`/v1/groups/{gid}/...`) and a project's POs,
/// reservations and demand (`.../projects/{pid}/hw/...`).
class InventoryApi {
  InventoryApi(this._api, this._workspace);

  final ApiClient _api;
  final CurrentWorkspace _workspace;

  static String _seg(String v) => Uri.encodeComponent(v);
  String _group(String gid) => '/v1/groups/${_seg(gid)}';
  String _hw(String gid, String pid) => '${_group(gid)}/projects/${_seg(pid)}/hw';

  Future<Map<String, dynamic>> _call(String op, String method, String path,
          {Object? body, Map<String, dynamic>? query}) =>
      _api.run(op, () async {
        await _workspace.resolve();
        return switch (method) {
          'GET' => _api.get(path, query: query),
          'POST' => _api.post(path, body: body ?? const <String, dynamic>{}),
          'PATCH' => _api.patch(path, body: body),
          'PUT' => _api.put(path, body: body),
          _ => _api.delete(path),
        };
      });

  // --- group ---------------------------------------------------------------

  Future<InvSettings> settings(String gid) async =>
      InvSettings.fromJson(await _call('inv.settings', 'GET', '${_group(gid)}/inventory/settings'));

  Future<InvSettings> updateSettings(String gid, {int? thresholdCents, String? currency}) async =>
      InvSettings.fromJson(await _call('inv.settings_update', 'PATCH', '${_group(gid)}/inventory/settings',
          body: {
            if (thresholdCents != null) 'po_approval_threshold_cents': thresholdCents,
            if (currency != null) 'currency': currency,
          }));

  Future<Vendors> vendors(String gid) async =>
      _vendors(await _call('inv.vendors', 'GET', '${_group(gid)}/vendors'));

  Future<Vendors> addVendor(String gid, {required String name, int? leadDays, String? contact}) async =>
      _vendors(await _call('inv.vendor_add', 'POST', '${_group(gid)}/vendors', body: {
        'name': name,
        if (leadDays != null) 'default_lead_days': leadDays,
        if (contact != null && contact.isNotEmpty) 'contact': contact,
      }));

  Future<Vendors> archiveVendor(String gid, String vid, {required bool archived}) async =>
      _vendors(await _call('inv.vendor_update', 'PATCH', '${_group(gid)}/vendors/${_seg(vid)}',
          body: {'archived': archived}));

  static Vendors _vendors(Map<String, dynamic> p) => Vendors(
        vendors: hwList(p['vendors']).map(Vendor.fromJson).toList(),
        canManage: p['can_manage'] == true,
      );

  Future<StockView> stock(String gid) async {
    final p = await _call('inv.stock', 'GET', '${_group(gid)}/stock');
    return StockView(
      entries: hwList(p['stock']).map(StockEntry.fromJson).toList(),
      canMove: p['can_move'] == true,
      canAdjust: p['can_adjust'] == true,
    );
  }

  Future<List<StockMovement>> movements(String gid, {String? part}) async =>
      hwList((await _call('inv.movements', 'GET', '${_group(gid)}/stock/movements',
              query: {if (part != null) 'part': part}))['movements'])
          .map(StockMovement.fromJson)
          .toList();

  Future<void> move(String gid,
          {required String partNumber,
          required String kind,
          required int qty,
          String? location,
          String? toLocation,
          String? note}) =>
      _call('inv.move', 'POST', '${_group(gid)}/stock/movements', body: {
        'part_number': partNumber,
        'kind': kind,
        'qty': qty,
        if (location != null && location.isNotEmpty) 'location': location,
        if (toLocation != null && toLocation.isNotEmpty) 'to_location': toLocation,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  // --- project -------------------------------------------------------------

  Future<List<DemandLine>> demand(String gid, String pid) async =>
      hwList((await _call('inv.demand', 'GET', '${_hw(gid, pid)}/demand'))['demand'])
          .map(DemandLine.fromJson)
          .toList();

  Future<List<PoSummary>> pos(String gid, String pid) async =>
      hwList((await _call('inv.pos', 'GET', '${_hw(gid, pid)}/pos'))['pos']).map(PoSummary.fromJson).toList();

  Future<PurchaseOrder> po(String gid, String pid, String poid) async =>
      PurchaseOrder.fromJson(hwMap((await _call('inv.po', 'GET', '${_hw(gid, pid)}/pos/${_seg(poid)}'))['po']));

  Future<PurchaseOrder> createPo(String gid, String pid, {required String vendorId, String? buildId}) async =>
      PurchaseOrder.fromJson(hwMap((await _call('inv.po_create', 'POST', '${_hw(gid, pid)}/pos', body: {
        'vendor_id': vendorId,
        if (buildId != null) 'build_id': buildId,
      }))['po']));

  Future<void> setPoLine(String gid, String pid, String poid, String part, {required int qty, int? unitCostCents}) =>
      _call('inv.po_line', 'PUT', '${_hw(gid, pid)}/pos/${_seg(poid)}/lines/${_seg(part)}', body: {
        'qty': qty,
        if (unitCostCents != null) 'unit_cost_cents': unitCostCents,
      });

  Future<void> removePoLine(String gid, String pid, String poid, String part) =>
      _call('inv.po_line_remove', 'DELETE', '${_hw(gid, pid)}/pos/${_seg(poid)}/lines/${_seg(part)}');

  /// submit | approve | close | cancel
  Future<void> poAction(String gid, String pid, String poid, String action) =>
      _call('inv.po_$action', 'POST', '${_hw(gid, pid)}/pos/${_seg(poid)}/$action');

  Future<void> receive(String gid, String pid, String poid,
          {required Map<String, int> lines, String? location}) =>
      _call('inv.po_receive', 'POST', '${_hw(gid, pid)}/pos/${_seg(poid)}/receive', body: {
        if (location != null && location.isNotEmpty) 'location': location,
        'lines': [
          for (final e in lines.entries)
            if (e.value > 0) {'part_number': e.key, 'qty': e.value},
        ],
      });

  Future<List<Reservation>> reservations(String gid, String pid) async =>
      hwList((await _call('inv.reservations', 'GET', '${_hw(gid, pid)}/reservations'))['reservations'])
          .map(Reservation.fromJson)
          .toList();

  Future<void> reserve(String gid, String pid, {required String partNumber, required int qty, String? buildId}) =>
      _call('inv.reserve', 'POST', '${_hw(gid, pid)}/reservations', body: {
        'part_number': partNumber,
        'qty': qty,
        if (buildId != null) 'build_id': buildId,
      });

  Future<void> releaseReservation(String gid, String pid, String id) =>
      _call('inv.reservation_release', 'DELETE', '${_hw(gid, pid)}/reservations/${_seg(id)}');

  Future<int> issueBuild(String gid, String pid, String bid) async =>
      hwInt((await _call('inv.issue', 'POST', '${_hw(gid, pid)}/builds/${_seg(bid)}/issue'))['issued']);
}

final inventoryApiProvider = Provider<InventoryApi>(
  (ref) => InventoryApi(ref.watch(apiClientProvider), ref.watch(currentWorkspaceProvider)),
);
