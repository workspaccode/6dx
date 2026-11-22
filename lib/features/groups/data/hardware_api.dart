import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/current_workspace.dart';
import '../domain/bom_tree_models.dart';
import '../domain/hardware_models.dart';

/// `/v1/groups/{gid}/projects/{pid}/hw/...` and the group's phase template.
///
/// The API checks the group type, the project access and every capability;
/// the app only hides buttons it already knows would be refused.
class HardwareApi {
  HardwareApi(this._api, this._workspace);

  final ApiClient _api;
  final CurrentWorkspace _workspace;

  static String _seg(String value) => Uri.encodeComponent(value);

  String _base(String gid, String pid) => '/v1/groups/${_seg(gid)}/projects/${_seg(pid)}/hw';

  Future<Map<String, dynamic>> _get(String op, String path, {Map<String, dynamic>? query}) =>
      _api.run(op, () async {
        await _workspace.resolve();
        return _api.get(path, query: query);
      });

  Future<Map<String, dynamic>> _send(String op, String method, String path, [Object? body]) =>
      _api.run(op, () async {
        await _workspace.resolve();
        return switch (method) {
          'POST' => _api.post(path, body: body ?? const <String, dynamic>{}),
          'PATCH' => _api.patch(path, body: body),
          'PUT' => _api.put(path, body: body),
          _ => _api.delete(path),
        };
      });

  // --- overview and phases ---------------------------------------------------

  Future<HwOverview> overview(String gid, String pid) async =>
      HwOverview.fromJson(await _get('hw.overview', '${_base(gid, pid)}/overview'));

  Future<void> updatePhase(String gid, String pid, String phaseId,
          {String? status, int? checkIndex, bool? checkDone}) =>
      _send('hw.phase', 'PATCH', '${_base(gid, pid)}/phases/${_seg(phaseId)}', {
        if (status != null) 'status': status,
        if (checkIndex != null) 'check': {'index': checkIndex, 'done': checkDone ?? true},
      });

  Future<void> decideGate(String gid, String pid, String phaseId,
          {required String decision, String? note}) =>
      _send('hw.gate', 'POST', '${_base(gid, pid)}/phases/${_seg(phaseId)}/gate', {
        'decision': decision,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  // --- parts and BOM ---------------------------------------------------------

  Future<List<HwPart>> parts(String gid, String pid) async =>
      hwList((await _get('hw.parts', '${_base(gid, pid)}/parts'))['parts'])
          .map(HwPart.fromJson)
          .toList();

  Future<void> createPart(String gid, String pid,
          {required String partNumber,
          required String description,
          String? revision,
          String? mpn,
          String? vendor,
          int? unitCostCents}) =>
      _send('hw.part_create', 'POST', '${_base(gid, pid)}/parts', {
        'part_number': partNumber,
        'description': description,
        if (revision != null && revision.isNotEmpty) 'revision': revision,
        if (mpn != null && mpn.isNotEmpty) 'mpn': mpn,
        if (vendor != null && vendor.isNotEmpty) 'vendor': vendor,
        if (unitCostCents != null) 'unit_cost_cents': unitCostCents,
      });

  Future<List<HwBomSummary>> bomRevisions(String gid, String pid) async =>
      hwList((await _get('hw.bom_list', '${_base(gid, pid)}/bom'))['revisions'])
          .map(HwBomSummary.fromJson)
          .toList();

  Future<HwBom> bom(String gid, String pid, String rid) async =>
      HwBom.fromJson(hwMap((await _get('hw.bom', '${_base(gid, pid)}/bom/${_seg(rid)}'))['bom']));

  Future<HwBom> newBomDraft(String gid, String pid) async => HwBom.fromJson(
      hwMap((await _send('hw.bom_new', 'POST', '${_base(gid, pid)}/bom'))['bom']));

  Future<void> deleteBomDraft(String gid, String pid, String rid) =>
      _send('hw.bom_delete', 'DELETE', '${_base(gid, pid)}/bom/${_seg(rid)}');

  Future<void> setBomLine(String gid, String pid, String rid, String partId,
          {required int quantity, String? refDesignators}) =>
      _send('hw.bom_line', 'PUT', '${_base(gid, pid)}/bom/${_seg(rid)}/lines/${_seg(partId)}', {
        'quantity': quantity,
        if (refDesignators != null && refDesignators.isNotEmpty) 'ref_designators': refDesignators,
      });

  Future<void> removeBomLine(String gid, String pid, String rid, String partId) =>
      _send('hw.bom_line_remove', 'DELETE',
          '${_base(gid, pid)}/bom/${_seg(rid)}/lines/${_seg(partId)}');

  Future<void> releaseBom(String gid, String pid, String rid, {String? note}) =>
      _send('hw.bom_release', 'POST', '${_base(gid, pid)}/bom/${_seg(rid)}/release', {
        if (note != null && note.isNotEmpty) 'note': note,
      });

  // --- assemblies (multi-level BOM) ------------------------------------------

  Future<HwPartChildren> partChildren(String gid, String pid, String partId) async =>
      HwPartChildren.fromJson(await _get('hw.part_children', '${_base(gid, pid)}/parts/${_seg(partId)}/children'));

  Future<void> setPartChild(String gid, String pid, String partId, String childId,
          {required int quantity, String? refDesignators}) =>
      _send('hw.part_child', 'PUT', '${_base(gid, pid)}/parts/${_seg(partId)}/children/${_seg(childId)}', {
        'quantity': quantity,
        if (refDesignators != null && refDesignators.isNotEmpty) 'ref_designators': refDesignators,
      });

  Future<void> removePartChild(String gid, String pid, String partId, String childId) =>
      _send('hw.part_child_remove', 'DELETE',
          '${_base(gid, pid)}/parts/${_seg(partId)}/children/${_seg(childId)}');

  Future<HwWhereUsed> whereUsed(String gid, String pid, String partId) async =>
      HwWhereUsed.fromJson(await _get('hw.where_used', '${_base(gid, pid)}/parts/${_seg(partId)}/where-used'));

  Future<HwBomTree> bomTree(String gid, String pid, String rid) async =>
      HwBomTree.fromJson(await _get('hw.bom_tree', '${_base(gid, pid)}/bom/${_seg(rid)}/tree'));

  // --- ECO -------------------------------------------------------------------

  Future<List<HwEcoSummary>> ecos(String gid, String pid) async =>
      hwList((await _get('hw.ecos', '${_base(gid, pid)}/ecos'))['ecos'])
          .map(HwEcoSummary.fromJson)
          .toList();

  Future<HwEco> eco(String gid, String pid, String eid) async =>
      HwEco.fromJson(hwMap((await _get('hw.eco', '${_base(gid, pid)}/ecos/${_seg(eid)}'))['eco']));

  Future<HwEco> createEco(String gid, String pid,
          {required String title, required String kind, String? reason, String? impact}) async =>
      HwEco.fromJson(hwMap((await _send('hw.eco_create', 'POST', '${_base(gid, pid)}/ecos', {
        'title': title,
        'kind': kind,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (impact != null && impact.isNotEmpty) 'impact': impact,
      }))['eco']));

  Future<void> addEcoItem(String gid, String pid, String eid,
          {required String action, String? fromPartId, String? toPartId, int? quantity}) =>
      _send('hw.eco_item', 'POST', '${_base(gid, pid)}/ecos/${_seg(eid)}/items', {
        'action': action,
        if (fromPartId != null) 'from_part_id': fromPartId,
        if (toPartId != null) 'to_part_id': toPartId,
        if (quantity != null) 'quantity': quantity,
      });

  Future<void> removeEcoItem(String gid, String pid, String eid, String itemId) =>
      _send('hw.eco_item_remove', 'DELETE',
          '${_base(gid, pid)}/ecos/${_seg(eid)}/items/${_seg(itemId)}');

  /// submit | reopen | cancel | release
  Future<void> ecoAction(String gid, String pid, String eid, String action) =>
      _send('hw.eco_$action', 'POST', '${_base(gid, pid)}/ecos/${_seg(eid)}/$action');

  Future<void> reviewEco(String gid, String pid, String eid,
          {required bool approve, String? comment}) =>
      _send('hw.eco_review', 'POST', '${_base(gid, pid)}/ecos/${_seg(eid)}/review', {
        'decision': approve ? 'approve' : 'reject',
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });

  // --- builds, units, tests --------------------------------------------------

  Future<List<HwBuild>> builds(String gid, String pid) async =>
      hwList((await _get('hw.builds', '${_base(gid, pid)}/builds'))['builds'])
          .map(HwBuild.fromJson)
          .toList();

  Future<void> createBuild(String gid, String pid,
          {required String name,
          required String bomRevId,
          required int quantity,
          String? phaseId,
          String? cm}) =>
      _send('hw.build_create', 'POST', '${_base(gid, pid)}/builds', {
        'name': name,
        'bom_rev_id': bomRevId,
        'quantity': quantity,
        if (phaseId != null) 'phase_id': phaseId,
        if (cm != null && cm.isNotEmpty) 'cm': cm,
      });

  Future<void> setBuildStatus(String gid, String pid, String bid, String status) =>
      _send('hw.build_status', 'PATCH', '${_base(gid, pid)}/builds/${_seg(bid)}', {'status': status});

  Future<List<HwUnit>> units(String gid, String pid, String bid) async =>
      hwList((await _get('hw.units', '${_base(gid, pid)}/builds/${_seg(bid)}/units'))['units'])
          .map(HwUnit.fromJson)
          .toList();

  Future<void> addUnits(String gid, String pid, String bid,
          {required int count, required String prefix}) =>
      _send('hw.units_add', 'POST', '${_base(gid, pid)}/builds/${_seg(bid)}/units',
          {'count': count, 'prefix': prefix});

  Future<void> updateUnit(String gid, String pid, String unitId,
          {String? firmwareVersion, String? location, String? status}) =>
      _send('hw.unit_update', 'PATCH', '${_base(gid, pid)}/units/${_seg(unitId)}', {
        if (firmwareVersion != null) 'firmware_version': firmwareVersion,
        if (location != null) 'location': location,
        if (status != null) 'status': status,
      });

  Future<List<HwTestResult>> unitResults(String gid, String pid, String unitId) async =>
      hwList((await _get('hw.unit_results', '${_base(gid, pid)}/units/${_seg(unitId)}/results'))['results'])
          .map(HwTestResult.fromJson)
          .toList();

  Future<void> recordResult(String gid, String pid, String unitId,
          {required String planId, required bool passed, String? notes}) =>
      _send('hw.result', 'POST', '${_base(gid, pid)}/units/${_seg(unitId)}/results', {
        'plan_id': planId,
        'result': passed ? 'pass' : 'fail',
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

  Future<List<HwTestPlan>> testPlans(String gid, String pid) async =>
      hwList((await _get('hw.tests', '${_base(gid, pid)}/tests'))['plans'])
          .map(HwTestPlan.fromJson)
          .toList();

  Future<void> createTestPlan(String gid, String pid, {required String title, String? criteria}) =>
      _send('hw.test_create', 'POST', '${_base(gid, pid)}/tests', {
        'title': title,
        if (criteria != null && criteria.isNotEmpty) 'criteria': criteria,
      });

  Future<void> approveTestPlan(String gid, String pid, String planId) =>
      _send('hw.test_approve', 'POST', '${_base(gid, pid)}/tests/${_seg(planId)}/approve');

  // --- firmware --------------------------------------------------------------

  Future<List<HwFirmwareLink>> firmware(String gid, String pid) async =>
      hwList((await _get('hw.firmware', '${_base(gid, pid)}/firmware'))['links'])
          .map(HwFirmwareLink.fromJson)
          .toList();

  Future<void> linkFirmware(String gid, String pid, {required String tag, required String bomRevId}) =>
      _send('hw.firmware_link', 'POST', '${_base(gid, pid)}/firmware',
          {'firmware_tag': tag, 'bom_rev_id': bomRevId});

  // --- phase template (group) ------------------------------------------------

  Future<PhaseTemplates> phaseTemplates(String gid) async =>
      _templates(await _get('hw.templates', '/v1/groups/${_seg(gid)}/phases'));

  Future<PhaseTemplates> addPhaseTemplate(String gid, {required String name, List<String>? checklist}) async =>
      _templates(await _send('hw.template_add', 'POST', '/v1/groups/${_seg(gid)}/phases', {
        'name': name,
        if (checklist != null) 'checklist': checklist,
      }));

  Future<PhaseTemplates> updatePhaseTemplate(String gid, String id,
          {String? name, List<String>? checklist, bool? archived}) async =>
      _templates(await _send('hw.template_update', 'PATCH', '/v1/groups/${_seg(gid)}/phases/${_seg(id)}', {
        if (name != null) 'name': name,
        if (checklist != null) 'checklist': checklist,
        if (archived != null) 'archived': archived,
      }));

  Future<PhaseTemplates> reorderPhaseTemplates(String gid, List<String> ids) async =>
      _templates(await _send('hw.template_order', 'PUT', '/v1/groups/${_seg(gid)}/phases/order',
          {'ids': ids}));

  static PhaseTemplates _templates(Map<String, dynamic> payload) => PhaseTemplates(
        phases: hwList(payload['phases']).map(PhaseTemplate.fromJson).toList(),
        canManage: payload['can_manage'] == true,
      );
}

final hardwareApiProvider = Provider<HardwareApi>(
  (ref) => HardwareApi(ref.watch(apiClientProvider), ref.watch(currentWorkspaceProvider)),
);
