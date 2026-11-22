import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/groups/domain/group_models.dart';
import 'package:sixdx/features/groups/domain/hardware_models.dart';
import 'package:sixdx/features/groups/presentation/pages/hardware_pages.dart';
import 'package:sixdx/features/groups/presentation/providers/group_providers.dart';
import 'package:sixdx/features/groups/presentation/providers/hardware_providers.dart';

Map<String, dynamic> _overviewJson(List<String> caps) => {
      'phases': [
        {
          'id': 'ph1',
          'name': 'Proto',
          'status': 'passed',
          'checklist': [
            {'text': 'works', 'done': true},
          ],
          'decisions': [
            {'decision': 'go', 'by': 'Sami'},
          ],
        },
        {
          'id': 'ph2',
          'name': 'EVT',
          'status': 'in_progress',
          'checklist': [
            {'text': 'Engineering validation', 'done': false},
          ],
          'decisions': [
            {'decision': 'recycle'},
          ],
        },
        {'id': 'ph3', 'name': 'DVT', 'status': 'not_started', 'checklist': [], 'decisions': []},
      ],
      'current_phase_id': 'ph2',
      'bom': {'released': 'B', 'draft': null},
      'ecos': {'open': 2, 'in_review': 1},
      'builds': {'count': 1, 'units': 3, 'passed': 1, 'failed': 1},
      'tests': {'plans': 1},
      'firmware_links': 0,
      'capabilities': caps,
    };

GroupAccess _access() => GroupAccess.fromJson({
      'id': 'g1',
      'name': 'Power Board',
      'type': 'hardware',
      'is_member': true,
      'group_role': 'member',
      'functional_role': 'technician',
      'capabilities': ['group.view'],
    });

Widget _page(List<String> caps) {
  const key = (gid: 'g1', pid: 'p1');
  return ProviderScope(
    overrides: [
      hwOverviewProvider(key).overrideWith((ref) async => HwOverview.fromJson(_overviewJson(caps))),
      hwFirmwareProvider(key).overrideWith((ref) async => const []),
      groupProjectsProvider('g1').overrideWith((ref) async => [
            GroupProject.fromJson({'id': 'p1', 'name': 'PB-1', 'visibility': 'private'}),
          ]),
    ],
    child: MaterialApp(home: HardwareProjectPage(access: _access(), pid: 'p1')),
  );
}

void main() {
  test('overview parsing: current phase, rounds, counters', () {
    final o = HwOverview.fromJson(_overviewJson(['gate.decide']));
    expect(o.currentPhase!.name, 'EVT');
    expect(o.currentPhase!.round, 2);
    expect(o.phases.first.isClosed, isTrue);
    expect(o.releasedBom, 'B');
    expect(o.draftBom, isNull);
    expect(o.can('gate.decide'), isTrue);
    expect(o.can('bom.release'), isFalse);
  });

  test('money and prices', () {
    expect(formatCents(1234), '12.34');
    expect(formatCents(5), '0.05');
    expect(formatCents(null), '—');
    // A role without prices.view gets no cost at all.
    final part = HwPart.fromJson({'id': 'x', 'part_number': 'R1', 'revision': 'A', 'description': 'r'});
    expect(part.unitCostCents, isNull);
    expect(part.label, 'R1 rev A');
  });

  test('ECO items read as sentences', () {
    final eco = HwEco.fromJson({
      'id': 'e',
      'code': 'ECO-001',
      'kind': 'eco',
      'title': 'Swap MCU',
      'status': 'design_review',
      'can_review': true,
      'items': [
        {'id': 'i1', 'action': 'change', 'from_part': 'MCU-1 rev A', 'to_part': 'MCU-1 rev B'},
        {'id': 'i2', 'action': 'add', 'to_part': 'C-1 rev A', 'quantity': 4},
      ],
      'approvals': [],
    });
    expect(eco.items[0].label, 'MCU-1 rev A ← MCU-1 rev B');
    expect(eco.items[1].label, 'إضافة C-1 rev A × 4');
    expect(eco.statusLabel, 'مراجعة التصميم');
    expect(eco.canReview, isTrue);
  });

  testWidgets('the gate button is for gate.decide only', (tester) async {
    await tester.pumpWidget(_page(['group.view', 'tests.record']));
    await tester.pumpAndSettle();
    expect(find.text('PB-1'), findsOneWidget);
    expect(find.textContaining('جولة 2'), findsOneWidget);
    expect(find.text('قرار الـ gate'), findsNothing);
  });

  testWidgets('a gate decider sees the gate and phase buttons', (tester) async {
    // Tall enough for every phase card (the list builds lazily).
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_page(['group.view', 'gate.decide', 'builds.manage']));
    await tester.pumpAndSettle();
    expect(find.text('قرار الـ gate'), findsOneWidget);
    expect(find.text('ابدأ المرحلة'), findsOneWidget);
  });
}
