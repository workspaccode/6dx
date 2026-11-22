/// Multi-level BOM and where-used (migration 0008).
library;

import 'hardware_models.dart';

/// One node of an exploded BOM revision (`.../bom/{rid}/tree`).
class HwTreeNode {
  const HwTreeNode({
    required this.partId,
    required this.partNumber,
    required this.revision,
    required this.description,
    required this.quantity,
    required this.level,
    required this.isAssembly,
  });

  final String partId;
  final String partNumber;
  final String revision;
  final String description;

  /// Per finished unit (multiplied down the tree).
  final int quantity;
  final int level;
  final bool isAssembly;

  factory HwTreeNode.fromJson(Map<String, dynamic> json) => HwTreeNode(
        partId: '${json['part_id']}',
        partNumber: '${json['part_number'] ?? ''}',
        revision: '${json['revision'] ?? ''}',
        description: '${json['description'] ?? ''}',
        quantity: hwInt(json['quantity']),
        level: hwInt(json['level']),
        isAssembly: json['is_assembly'] == true,
      );
}

class HwBomTree {
  const HwBomTree({required this.nodes, required this.leaves, this.totalCostCents});
  final List<HwTreeNode> nodes;

  /// What is bought: the leaves with their total quantity per unit.
  final List<HwBomLine> leaves;
  final int? totalCostCents;

  factory HwBomTree.fromJson(Map<String, dynamic> json) => HwBomTree(
        nodes: hwList(json['nodes']).map(HwTreeNode.fromJson).toList(),
        leaves: hwList(json['leaves']).map(HwBomLine.fromJson).toList(),
        totalCostCents: hwIntOrNull(json['total_cost_cents']),
      );
}

class HwPartChildren {
  const HwPartChildren({required this.children, required this.frozen});
  final List<HwBomLine> children;

  /// In a released BOM (directly or inside an assembly): fixed.
  final bool frozen;

  factory HwPartChildren.fromJson(Map<String, dynamic> json) => HwPartChildren(
        children: hwList(json['children']).map(HwBomLine.fromJson).toList(),
        frozen: json['frozen'] == true,
      );
}

typedef UsedInAssembly = ({String partId, String label, int level});
typedef UsedInRevision = ({String id, String rev, String status});
typedef UsedInBuild = ({String id, String name, String status, String bomRev});

class HwWhereUsed {
  const HwWhereUsed({required this.assemblies, required this.revisions, required this.builds});
  final List<UsedInAssembly> assemblies;
  final List<UsedInRevision> revisions;
  final List<UsedInBuild> builds;

  bool get isUnused => assemblies.isEmpty && revisions.isEmpty;

  factory HwWhereUsed.fromJson(Map<String, dynamic> json) => HwWhereUsed(
        assemblies: [
          for (final a in hwList(json['assemblies']))
            (partId: '${a['part_id']}', label: '${a['part_number']} rev ${a['revision']}', level: hwInt(a['level'])),
        ],
        revisions: [
          for (final r in hwList(json['bom_revisions']))
            (id: '${r['id']}', rev: '${r['rev']}', status: '${r['status']}'),
        ],
        builds: [
          for (final b in hwList(json['builds']))
            (id: '${b['id']}', name: '${b['name']}', status: '${b['status']}', bomRev: '${b['bom_rev']}'),
        ],
      );
}
