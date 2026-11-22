import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/groups/domain/bom_tree_models.dart';

void main() {
  test('tree, leaves and where-used parse', () {
    final t = HwBomTree.fromJson({
      'nodes': [
        {'part_id': 'a', 'part_number': 'PCBA', 'revision': 'A', 'quantity': 2, 'level': 0, 'is_assembly': true},
        {'part_id': 'r', 'part_number': 'R1', 'revision': 'A', 'quantity': 20, 'level': 1},
      ],
      'leaves': [
        {'part_id': 'r', 'part_number': 'R1', 'revision': 'A', 'quantity': 20},
      ],
      'total_cost_cents': 40,
    });
    expect(t.nodes.first.isAssembly, isTrue);
    expect(t.nodes.last.level, 1);
    expect(t.leaves.single.quantity, 20);
    expect(t.totalCostCents, 40);

    final u = HwWhereUsed.fromJson({
      'assemblies': [
        {'part_id': 'a', 'part_number': 'PCBA', 'revision': 'A', 'level': 1},
      ],
      'bom_revisions': [
        {'id': 'b', 'rev': 'A', 'status': 'released'},
      ],
      'builds': [],
    });
    expect(u.isUnused, isFalse);
    expect(u.assemblies.single.label, 'PCBA rev A');
    expect(HwWhereUsed.fromJson({}).isUnused, isTrue);

    expect(HwPartChildren.fromJson({'children': [], 'frozen': true}).frozen, isTrue);
  });
}
