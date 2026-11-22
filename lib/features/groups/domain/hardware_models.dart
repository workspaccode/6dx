/// Hardware projects — docs/design/groups-and-roles.md §7 (phase 4a).
///
/// The API decides every capability (`HwOverview.capabilities`); these
/// classes only read what it returns. Prices are absent for roles that may
/// not see them, so every cost is nullable.
library;

abstract final class HwCaps {
  static const editBom = 'bom.edit';
  static const releaseBom = 'bom.release';
  static const submitEco = 'eco.submit';
  static const submitEcr = 'ecr.submit';
  static const manageBuilds = 'builds.manage';
  static const recordTests = 'tests.record';
  static const approveTests = 'tests.approve';
  static const gateDecision = 'gate.decide';
  static const firmwareLink = 'firmware.link';
  static const viewPrices = 'prices.view';
  static const editTasks = 'tasks.edit';
}

const phaseStatusLabels = <String, String>{
  'not_started': 'لسه مابدأتش',
  'in_progress': 'شغّالة',
  'ready_for_review': 'جاهزة للـ gate',
  'on_hold': 'متوقفة',
  'passed': 'عدّت',
  'killed': 'اتلغت',
};

const gateDecisionLabels = <String, String>{
  'go': 'Go — عدّت للمرحلة الجاية',
  'recycle': 'Recycle — جولة تانية في نفس المرحلة',
  'hold': 'Hold — وقف مؤقت',
  'kill': 'Kill — إيقاف المشروع',
};

const ecoStatusLabels = <String, String>{
  'draft': 'مسودة',
  'design_review': 'مراجعة التصميم',
  'production_review': 'مراجعة الإنتاج',
  'approved': 'معتمد',
  'released': 'اتعمله release',
  'rejected': 'مرفوض',
  'cancelled': 'ملغي',
};

const buildStatusLabels = <String, String>{
  'planned': 'مخطط',
  'parts_ordered': 'القطع اتطلبت',
  'assembling': 'بيتجمّع',
  'received': 'اتستلم',
  'testing': 'تحت الاختبار',
  'complete': 'خلص',
  'cancelled': 'ملغي',
};

const unitStatusLabels = <String, String>{
  'untested': 'لسه ماتختبرتش',
  'passed': 'نجحت',
  'failed': 'فشلت',
  'rework': 'Rework',
  'scrapped': 'اتشالت',
};

const partLifecycleLabels = <String, String>{
  'draft': 'مسودة',
  'prototype': 'نموذج',
  'production': 'إنتاج',
  'obsolete': 'متوقفة',
};

/// '1234' cents → '12.34'.
String formatCents(int? cents) {
  if (cents == null) return '—';
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

class HwChecklistItem {
  const HwChecklistItem({required this.text, required this.done});
  final String text;
  final bool done;

  factory HwChecklistItem.fromJson(Map<String, dynamic> json) =>
      HwChecklistItem(text: '${json['text'] ?? ''}', done: json['done'] == true);
}

class HwGateDecision {
  const HwGateDecision({required this.decision, this.note, this.by, this.at});
  final String decision;
  final String? note;
  final String? by;
  final DateTime? at;

  factory HwGateDecision.fromJson(Map<String, dynamic> json) => HwGateDecision(
        decision: '${json['decision']}',
        note: json['note'] as String?,
        by: json['by'] as String?,
        at: DateTime.tryParse('${json['at'] ?? ''}'),
      );
}

class HwPhase {
  const HwPhase({
    required this.id,
    required this.name,
    required this.status,
    required this.checklist,
    required this.decisions,
    required this.builds,
    this.gateDueAt,
  });

  final String id;
  final String name;
  final String status;
  final List<HwChecklistItem> checklist;
  final List<HwGateDecision> decisions;
  final int builds;
  final String? gateDueAt;

  bool get isActive => const {'in_progress', 'ready_for_review', 'on_hold'}.contains(status);
  bool get isClosed => status == 'passed' || status == 'killed';
  String get statusLabel => phaseStatusLabels[status] ?? status;
  int get doneItems => checklist.where((c) => c.done).length;

  /// EVT1, EVT2…: one round per recycle.
  int get round => 1 + decisions.where((d) => d.decision == 'recycle').length;

  factory HwPhase.fromJson(Map<String, dynamic> json) => HwPhase(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        status: '${json['status'] ?? 'not_started'}',
        checklist: hwList(json['checklist']).map(HwChecklistItem.fromJson).toList(),
        decisions: hwList(json['decisions']).map(HwGateDecision.fromJson).toList(),
        builds: hwInt(json['builds']),
        gateDueAt: json['gate_due_at'] as String?,
      );
}

class HwOverview {
  const HwOverview({
    required this.phases,
    required this.currentPhaseId,
    required this.releasedBom,
    required this.draftBom,
    required this.openEcos,
    required this.ecosInReview,
    required this.builds,
    required this.units,
    required this.passedUnits,
    required this.failedUnits,
    required this.testPlans,
    required this.firmwareLinks,
    required this.capabilities,
  });

  final List<HwPhase> phases;
  final String? currentPhaseId;
  final String? releasedBom;
  final String? draftBom;
  final int openEcos;
  final int ecosInReview;
  final int builds;
  final int units;
  final int passedUnits;
  final int failedUnits;
  final int testPlans;
  final int firmwareLinks;
  final Set<String> capabilities;

  bool can(String capability) => capabilities.contains(capability);

  HwPhase? get currentPhase {
    for (final p in phases) {
      if (p.id == currentPhaseId) return p;
    }
    return null;
  }

  factory HwOverview.fromJson(Map<String, dynamic> json) {
    final bom = hwMap(json['bom']);
    final ecos = hwMap(json['ecos']);
    final builds = hwMap(json['builds']);
    final tests = hwMap(json['tests']);
    return HwOverview(
      phases: hwList(json['phases']).map(HwPhase.fromJson).toList(),
      currentPhaseId: json['current_phase_id'] as String?,
      releasedBom: bom['released'] as String?,
      draftBom: bom['draft'] as String?,
      openEcos: hwInt(ecos['open']),
      ecosInReview: hwInt(ecos['in_review']),
      builds: hwInt(builds['count']),
      units: hwInt(builds['units']),
      passedUnits: hwInt(builds['passed']),
      failedUnits: hwInt(builds['failed']),
      testPlans: hwInt(tests['plans']),
      firmwareLinks: hwInt(json['firmware_links']),
      capabilities: {for (final c in (json['capabilities'] as List? ?? const [])) '$c'},
    );
  }
}

class HwPart {
  const HwPart({
    required this.id,
    required this.partNumber,
    required this.revision,
    required this.description,
    required this.lifecycle,
    this.category,
    this.mpn,
    this.vendor,
    this.unitCostCents,
  });

  final String id;
  final String partNumber;
  final String revision;
  final String description;
  final String lifecycle;
  final String? category;
  final String? mpn;
  final String? vendor;
  final int? unitCostCents;

  String get label => '$partNumber rev $revision';

  factory HwPart.fromJson(Map<String, dynamic> json) => HwPart(
        id: '${json['id']}',
        partNumber: '${json['part_number'] ?? ''}',
        revision: '${json['revision'] ?? 'A'}',
        description: '${json['description'] ?? ''}',
        lifecycle: '${json['lifecycle'] ?? 'draft'}',
        category: json['category'] as String?,
        mpn: json['mpn'] as String?,
        vendor: json['vendor'] as String?,
        unitCostCents: hwIntOrNull(json['unit_cost_cents']),
      );
}

class HwBomSummary {
  const HwBomSummary({
    required this.id,
    required this.rev,
    required this.status,
    required this.lines,
    required this.quantity,
    this.ecoId,
    this.note,
  });

  final String id;
  final String rev;
  final String status;
  final int lines;
  final int quantity;
  final String? ecoId;
  final String? note;

  bool get isDraft => status == 'draft';

  factory HwBomSummary.fromJson(Map<String, dynamic> json) => HwBomSummary(
        id: '${json['id']}',
        rev: '${json['rev'] ?? ''}',
        status: '${json['status'] ?? 'draft'}',
        lines: hwInt(json['lines']),
        quantity: hwInt(json['quantity']),
        ecoId: json['eco_id'] as String?,
        note: json['note'] as String?,
      );
}

class HwBomLine {
  const HwBomLine({
    required this.partId,
    required this.partNumber,
    required this.revision,
    required this.description,
    required this.quantity,
    this.refDesignators,
    this.unitCostCents,
  });

  final String partId;
  final String partNumber;
  final String revision;
  final String description;
  final int quantity;
  final String? refDesignators;
  final int? unitCostCents;

  factory HwBomLine.fromJson(Map<String, dynamic> json) => HwBomLine(
        partId: '${json['part_id']}',
        partNumber: '${json['part_number'] ?? ''}',
        revision: '${json['revision'] ?? ''}',
        description: '${json['description'] ?? ''}',
        quantity: hwInt(json['quantity']),
        refDesignators: json['ref_designators'] as String?,
        unitCostCents: hwIntOrNull(json['unit_cost_cents']),
      );
}

class HwBom {
  const HwBom({
    required this.id,
    required this.rev,
    required this.status,
    required this.lines,
    this.note,
    this.ecoId,
    this.totalCostCents,
  });

  final String id;
  final String rev;
  final String status;
  final List<HwBomLine> lines;
  final String? note;
  final String? ecoId;
  final int? totalCostCents;

  bool get isDraft => status == 'draft';

  factory HwBom.fromJson(Map<String, dynamic> json) => HwBom(
        id: '${json['id']}',
        rev: '${json['rev'] ?? ''}',
        status: '${json['status'] ?? 'draft'}',
        lines: hwList(json['lines']).map(HwBomLine.fromJson).toList(),
        note: json['note'] as String?,
        ecoId: json['eco_id'] as String?,
        totalCostCents: hwIntOrNull(json['total_cost_cents']),
      );
}

class HwEcoSummary {
  const HwEcoSummary({
    required this.id,
    required this.code,
    required this.kind,
    required this.title,
    required this.status,
    required this.items,
  });

  final String id;
  final String code;
  final String kind;
  final String title;
  final String status;
  final int items;

  String get statusLabel => ecoStatusLabels[status] ?? status;

  factory HwEcoSummary.fromJson(Map<String, dynamic> json) => HwEcoSummary(
        id: '${json['id']}',
        code: '${json['code'] ?? ''}',
        kind: '${json['kind'] ?? 'eco'}',
        title: '${json['title'] ?? ''}',
        status: '${json['status'] ?? 'draft'}',
        items: hwInt(json['items']),
      );
}

class HwEcoItem {
  const HwEcoItem({
    required this.id,
    required this.action,
    this.fromPart,
    this.toPart,
    this.quantity,
  });

  final String id;
  final String action;
  final String? fromPart;
  final String? toPart;
  final int? quantity;

  String get label => switch (action) {
        'add' => 'إضافة ${toPart ?? ''}${quantity == null ? '' : ' × $quantity'}',
        'remove' => 'إزالة ${fromPart ?? ''}',
        _ => '${fromPart ?? ''} ← ${toPart ?? ''}',
      };

  factory HwEcoItem.fromJson(Map<String, dynamic> json) => HwEcoItem(
        id: '${json['id']}',
        action: '${json['action'] ?? 'change'}',
        fromPart: json['from_part'] as String?,
        toPart: json['to_part'] as String?,
        quantity: hwIntOrNull(json['quantity']),
      );
}

class HwEcoApproval {
  const HwEcoApproval({required this.stage, required this.decision, this.comment, this.by});
  final String stage;
  final String decision;
  final String? comment;
  final String? by;

  factory HwEcoApproval.fromJson(Map<String, dynamic> json) => HwEcoApproval(
        stage: '${json['stage']}',
        decision: '${json['decision']}',
        comment: json['comment'] as String?,
        by: json['by'] as String?,
      );
}

class HwEco {
  const HwEco({
    required this.id,
    required this.code,
    required this.kind,
    required this.title,
    required this.status,
    required this.items,
    required this.approvals,
    required this.canReview,
    this.reason,
    this.impact,
    this.createdBy,
    this.bomRevId,
  });

  final String id;
  final String code;
  final String kind;
  final String title;
  final String status;
  final List<HwEcoItem> items;
  final List<HwEcoApproval> approvals;
  final bool canReview;
  final String? reason;
  final String? impact;
  final String? createdBy;
  final String? bomRevId;

  bool get isDraft => status == 'draft';
  bool get isEcr => kind == 'ecr';
  String get statusLabel => ecoStatusLabels[status] ?? status;

  factory HwEco.fromJson(Map<String, dynamic> json) => HwEco(
        id: '${json['id']}',
        code: '${json['code'] ?? ''}',
        kind: '${json['kind'] ?? 'eco'}',
        title: '${json['title'] ?? ''}',
        status: '${json['status'] ?? 'draft'}',
        items: hwList(json['items']).map(HwEcoItem.fromJson).toList(),
        approvals: hwList(json['approvals']).map(HwEcoApproval.fromJson).toList(),
        canReview: json['can_review'] == true,
        reason: json['reason'] as String?,
        impact: json['impact'] as String?,
        createdBy: json['created_by'] as String?,
        bomRevId: json['bom_rev_id'] as String?,
      );
}

class HwBuild {
  const HwBuild({
    required this.id,
    required this.name,
    required this.status,
    required this.quantity,
    required this.bomRev,
    required this.units,
    required this.passed,
    required this.failed,
    this.cm,
    this.phaseName,
  });

  final String id;
  final String name;
  final String status;
  final int quantity;
  final String? bomRev;
  final int units;
  final int passed;
  final int failed;
  final String? cm;
  final String? phaseName;

  String get statusLabel => buildStatusLabels[status] ?? status;

  factory HwBuild.fromJson(Map<String, dynamic> json) => HwBuild(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        status: '${json['status'] ?? 'planned'}',
        quantity: hwInt(json['quantity']),
        bomRev: json['bom_rev'] as String?,
        units: hwInt(json['units']),
        passed: hwInt(json['passed']),
        failed: hwInt(json['failed']),
        cm: json['cm'] as String?,
        phaseName: json['phase_name'] as String?,
      );
}

class HwUnit {
  const HwUnit({
    required this.id,
    required this.serial,
    required this.status,
    required this.results,
    this.firmwareVersion,
    this.location,
  });

  final String id;
  final String serial;
  final String status;
  final int results;
  final String? firmwareVersion;
  final String? location;

  String get statusLabel => unitStatusLabels[status] ?? status;

  factory HwUnit.fromJson(Map<String, dynamic> json) => HwUnit(
        id: '${json['id']}',
        serial: '${json['serial'] ?? ''}',
        status: '${json['status'] ?? 'untested'}',
        results: hwInt(json['results']),
        firmwareVersion: json['firmware_version'] as String?,
        location: json['location'] as String?,
      );
}

class HwTestPlan {
  const HwTestPlan({
    required this.id,
    required this.title,
    required this.approved,
    required this.passed,
    required this.failed,
    this.criteria,
    this.phaseName,
  });

  final String id;
  final String title;
  final bool approved;
  final int passed;
  final int failed;
  final String? criteria;
  final String? phaseName;

  factory HwTestPlan.fromJson(Map<String, dynamic> json) => HwTestPlan(
        id: '${json['id']}',
        title: '${json['title'] ?? ''}',
        approved: json['approved'] == true,
        passed: hwInt(json['passed']),
        failed: hwInt(json['failed']),
        criteria: json['criteria'] as String?,
        phaseName: json['phase_name'] as String?,
      );
}

class HwTestResult {
  const HwTestResult({
    required this.planTitle,
    required this.result,
    this.notes,
    this.firmwareVersion,
    this.recordedBy,
    this.recordedAt,
  });

  final String planTitle;
  final String result;
  final String? notes;
  final String? firmwareVersion;
  final String? recordedBy;
  final DateTime? recordedAt;

  bool get passed => result == 'pass';

  factory HwTestResult.fromJson(Map<String, dynamic> json) => HwTestResult(
        planTitle: '${json['plan_title'] ?? ''}',
        result: '${json['result'] ?? 'fail'}',
        notes: json['notes'] as String?,
        firmwareVersion: json['firmware_version'] as String?,
        recordedBy: json['recorded_by'] as String?,
        recordedAt: DateTime.tryParse('${json['recorded_at'] ?? ''}'),
      );
}

class HwFirmwareLink {
  const HwFirmwareLink({
    required this.firmwareTag,
    required this.bomRevId,
    required this.bomRev,
    this.note,
    this.verifiedBy,
  });

  final String firmwareTag;
  final String bomRevId;
  final String bomRev;
  final String? note;
  final String? verifiedBy;

  factory HwFirmwareLink.fromJson(Map<String, dynamic> json) => HwFirmwareLink(
        firmwareTag: '${json['firmware_tag'] ?? ''}',
        bomRevId: '${json['bom_rev_id'] ?? ''}',
        bomRev: '${json['bom_rev'] ?? ''}',
        note: json['note'] as String?,
        verifiedBy: json['verified_by'] as String?,
      );
}

/// A template phase of the group (`/v1/groups/{gid}/phases`).
class PhaseTemplate {
  const PhaseTemplate({
    required this.id,
    required this.name,
    required this.checklist,
    required this.archived,
  });

  final String id;
  final String name;
  final List<String> checklist;
  final bool archived;

  factory PhaseTemplate.fromJson(Map<String, dynamic> json) => PhaseTemplate(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        checklist: [for (final c in (json['checklist'] as List? ?? const [])) '$c'],
        archived: json['archived'] == true,
      );
}

class PhaseTemplates {
  const PhaseTemplates({required this.phases, required this.canManage});
  final List<PhaseTemplate> phases;
  final bool canManage;

  List<PhaseTemplate> get live => phases.where((p) => !p.archived).toList(growable: false);
  List<PhaseTemplate> get archived => phases.where((p) => p.archived).toList(growable: false);
}

int hwInt(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

int? hwIntOrNull(Object? value) => value is num ? value.toInt() : null;

Map<String, dynamic> hwMap(Object? value) =>
    value is Map ? value.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};

List<Map<String, dynamic>> hwList(Object? value) => value is List
    ? value.whereType<Map>().map(hwMap).toList(growable: false)
    : const [];
