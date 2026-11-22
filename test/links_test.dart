import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/groups/data/links_api.dart';
import 'package:sixdx/features/groups/domain/group_models.dart';
import 'package:sixdx/features/groups/presentation/pages/links_pages.dart';
import 'package:sixdx/features/groups/presentation/providers/group_providers.dart';

GroupAccess _access(String role) => GroupAccess.fromJson({
      'id': 'g1',
      'name': 'Power Board',
      'type': 'hardware',
      'is_member': true,
      'group_role': role,
      'functional_role': role == 'guest' ? 'client' : 'hw_lead',
      'capabilities': ['group.view', if (role != 'guest') 'group.manage'],
    });

ProjectLink _link(String status, {bool outgoing = false}) => ProjectLink.fromJson({
      'id': 'l-$status',
      'status': status,
      'outgoing': outgoing,
      'other': {'project_id': 'p2', 'project_name': 'App', 'group_name': 'Mobile', 'group_type': 'software'},
    });

Widget _page(String role, List<ProjectLink> links) => ProviderScope(
      overrides: [
        groupAccessProvider('g1').overrideWith((ref) async => _access(role)),
        projectLinksProvider((gid: 'g1', pid: 'p1'))
            .overrideWith((ref) async => ProjectLinks(links: links, canManage: role != 'guest')),
      ],
      child: const MaterialApp(home: ProjectLinksPage(gid: 'g1', pid: 'p1')),
    );

void main() {
  test('summary parsing keeps only what a link shows', () {
    final s = LinkSummary.fromJson({
      'summary': {
        'project_name': 'PB-1',
        'group_name': 'HW',
        'group_type': 'hardware',
        'open_tasks': 3,
        'done_tasks': 1,
        'phases': [
          {'name': 'EVT', 'status': 'in_progress'},
        ],
        'released_bom': 'B',
        'firmware': [
          {'firmware_tag': 'v1.0', 'bom_rev': 'B'},
        ],
      },
      'dependencies': [
        {
          'id': 'd',
          'waiting': {'task_id': 'a', 'title': 'BLE pairing', 'status': 'todo', 'mine': true},
          'depends_on': {'task_id': 'b', 'title': 'BLE antenna', 'status': 'done', 'mine': false},
        },
      ],
      'can_edit': true,
    });
    expect(s.phases.single.name, 'EVT');
    expect(s.firmware.single.bomRev, 'B');
    expect(s.dependencies.single.dependsOn.done, isTrue);
    expect(s.dependencies.single.waiting.mine, isTrue);
  });

  testWidgets('an incoming request offers approval; an outgoing one waits', (tester) async {
    await tester.pumpWidget(_page('lead', [_link('requested'), _link('requested', outgoing: true)]));
    await tester.pumpAndSettle();
    expect(find.text('موافقة'), findsOneWidget);
    expect(find.textContaining('طالبين الربط معاك'), findsOneWidget);
    expect(find.textContaining('مستني موافقتهم'), findsOneWidget);
    expect(find.text('طلب ربط'), findsOneWidget);
  });

  testWidgets('a guest never sees links', (tester) async {
    await tester.pumpWidget(_page('guest', [_link('active')]));
    await tester.pumpAndSettle();
    expect(find.text('App · Mobile'), findsNothing);
    expect(find.text('مش متاحة لدورك'), findsOneWidget);
  });
}
