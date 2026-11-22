/// Procurement and inventory (hardware) — docs/design/groups-and-roles.md §7.5.
library;

import 'hardware_models.dart';

abstract final class InvCaps {
  static const manageVendors = 'vendors.manage';
  static const createPo = 'po.create';
  static const requestPo = 'po.request';
  static const approvePo = 'po.approve';
  static const moveInventory = 'inventory.move';
}

const poStatusLabels = <String, String>{
  'draft': 'مسودة',
  'pending_approval': 'مستني اعتماد',
  'ordered': 'اتطلب',
  'partially_received': 'وصل جزء',
  'received': 'وصل كله',
  'closed': 'مقفول',
  'cancelled': 'ملغي',
};

class InvSettings {
  const InvSettings({required this.thresholdCents, required this.currency, required this.canManage});
  final int thresholdCents;
  final String currency;
  final bool canManage;

  factory InvSettings.fromJson(Map<String, dynamic> json) {
    final s = hwMap(json['settings']);
    return InvSettings(
      thresholdCents: hwInt(s['po_approval_threshold_cents']),
      currency: '${s['currency'] ?? 'USD'}',
      canManage: json['can_manage'] == true,
    );
  }
}

class Vendor {
  const Vendor({required this.id, required this.name, required this.leadDays, required this.archived, this.contact});
  final String id;
  final String name;
  final int leadDays;
  final bool archived;
  final String? contact;

  factory Vendor.fromJson(Map<String, dynamic> json) => Vendor(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        leadDays: hwInt(json['default_lead_days']),
        archived: json['archived'] == true,
        contact: json['contact'] as String?,
      );
}

class Vendors {
  const Vendors({required this.vendors, required this.canManage});
  final List<Vendor> vendors;
  final bool canManage;

  List<Vendor> get live => vendors.where((v) => !v.archived).toList(growable: false);
}

class StockEntry {
  const StockEntry({
    required this.partNumber,
    required this.onHand,
    required this.reserved,
    required this.available,
    required this.locations,
  });

  final String partNumber;
  final int onHand;
  final int reserved;
  final int available;
  final Map<String, int> locations;

  bool get isShort => available < 0;

  factory StockEntry.fromJson(Map<String, dynamic> json) => StockEntry(
        partNumber: '${json['part_number'] ?? ''}',
        onHand: hwInt(json['on_hand']),
        reserved: hwInt(json['reserved']),
        available: hwInt(json['available']),
        locations: {
          for (final l in hwList(json['locations'])) '${l['location']}': hwInt(l['on_hand']),
        },
      );
}

class StockView {
  const StockView({required this.entries, required this.canMove, required this.canAdjust});
  final List<StockEntry> entries;
  final bool canMove;
  final bool canAdjust;
}

class StockMovement {
  const StockMovement({
    required this.partNumber,
    required this.location,
    required this.qty,
    required this.kind,
    this.note,
    this.by,
    this.at,
  });

  final String partNumber;
  final String location;
  final int qty;
  final String kind;
  final String? note;
  final String? by;
  final DateTime? at;

  String get kindLabel => const {
        'receive': 'استلام',
        'issue': 'صرف',
        'adjust': 'تسوية',
        'transfer': 'نقل',
      }[kind] ??
      kind;

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        partNumber: '${json['part_number'] ?? ''}',
        location: '${json['location'] ?? ''}',
        qty: hwInt(json['qty']),
        kind: '${json['kind'] ?? ''}',
        note: json['note'] as String?,
        by: json['by'] as String?,
        at: DateTime.tryParse('${json['at'] ?? ''}'),
      );
}

class PoSummary {
  const PoSummary({
    required this.id,
    required this.code,
    required this.vendor,
    required this.status,
    required this.currency,
    required this.lines,
    this.totalCents,
    this.buildName,
  });

  final String id;
  final String code;
  final String vendor;
  final String status;
  final String currency;
  final int lines;
  final int? totalCents;
  final String? buildName;

  String get statusLabel => poStatusLabels[status] ?? status;

  factory PoSummary.fromJson(Map<String, dynamic> json) => PoSummary(
        id: '${json['id']}',
        code: '${json['code'] ?? ''}',
        vendor: '${json['vendor'] ?? ''}',
        status: '${json['status'] ?? 'draft'}',
        currency: '${json['currency'] ?? 'USD'}',
        lines: hwInt(json['lines']),
        totalCents: hwIntOrNull(json['total_cents']),
        buildName: json['build_name'] as String?,
      );
}

class PoLine {
  const PoLine({required this.partNumber, required this.qty, required this.receivedQty, this.unitCostCents});
  final String partNumber;
  final int qty;
  final int receivedQty;
  final int? unitCostCents;

  int get open => qty - receivedQty;

  factory PoLine.fromJson(Map<String, dynamic> json) => PoLine(
        partNumber: '${json['part_number'] ?? ''}',
        qty: hwInt(json['qty']),
        receivedQty: hwInt(json['received_qty']),
        unitCostCents: hwIntOrNull(json['unit_cost_cents']),
      );
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.code,
    required this.vendor,
    required this.status,
    required this.currency,
    required this.lines,
    required this.canApprove,
    this.createdBy,
    this.totalCents,
    this.buildName,
    this.note,
  });

  final String id;
  final String code;
  final String vendor;
  final String status;
  final String currency;
  final List<PoLine> lines;
  final bool canApprove;
  final String? createdBy;
  final int? totalCents;
  final String? buildName;
  final String? note;

  bool get isDraft => status == 'draft';
  bool get canReceive => status == 'ordered' || status == 'partially_received';
  String get statusLabel => poStatusLabels[status] ?? status;

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) => PurchaseOrder(
        id: '${json['id']}',
        code: '${json['code'] ?? ''}',
        vendor: '${json['vendor'] ?? ''}',
        status: '${json['status'] ?? 'draft'}',
        currency: '${json['currency'] ?? 'USD'}',
        lines: hwList(json['lines']).map(PoLine.fromJson).toList(),
        canApprove: json['can_approve'] == true,
        createdBy: json['created_by'] as String?,
        totalCents: hwIntOrNull(json['total_cents']),
        buildName: json['build_name'] as String?,
        note: json['note'] as String?,
      );
}

class Reservation {
  const Reservation({
    required this.id,
    required this.partNumber,
    required this.qty,
    required this.status,
    this.buildName,
  });

  final String id;
  final String partNumber;
  final int qty;
  final String status;
  final String? buildName;

  bool get isActive => status == 'active';

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: '${json['id']}',
        partNumber: '${json['part_number'] ?? ''}',
        qty: hwInt(json['qty']),
        status: '${json['status'] ?? 'active'}',
        buildName: json['build_name'] as String?,
      );
}

class DemandLine {
  const DemandLine({
    required this.partNumber,
    required this.needed,
    required this.reserved,
    required this.onOrder,
    required this.available,
    required this.shortage,
    required this.orderNow,
    this.orderBy,
    this.leadDays,
  });

  final String partNumber;
  final int needed;
  final int reserved;
  final int onOrder;
  final int available;
  final int shortage;
  final bool orderNow;
  final String? orderBy;
  final int? leadDays;

  factory DemandLine.fromJson(Map<String, dynamic> json) => DemandLine(
        partNumber: '${json['part_number'] ?? ''}',
        needed: hwInt(json['needed']),
        reserved: hwInt(json['reserved']),
        onOrder: hwInt(json['on_order']),
        available: hwInt(json['available']),
        shortage: hwInt(json['shortage']),
        orderNow: json['order_now'] == true,
        orderBy: json['order_by'] as String?,
        leadDays: hwIntOrNull(json['lead_days']),
      );
}
