import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/groups/domain/group_models.dart';
import 'package:sixdx/features/groups/domain/workflow_models.dart';
import 'package:sixdx/features/groups/presentation/pages/workflow_pages.dart';
import 'package:sixdx/features/groups/presentation/providers/group_providers.dart';

Map<String, dynamic> _state(String id, String name, String category,
        {String legacy = 'in_progress', bool archived = false, int tasks = 0}) =>
    {
      'id': id,
      'name': name,
      'category': category,
      'color': '#2563EB',
      'legacy_status': legacy,
      'order': 0,
      'is_locked': false,
      'archived': archived,
      'task_count': tasks,
    };

GroupWorkflow _flow() => GroupWorkflow(
      canManage: true,
      states: [
        _state('g:todo', 'للتنفيذ', 'backlog', legacy: 'todo'),
        _state('g:qa', 'QA', 'active'),
        _state('g:review', 'مراجعة', 'active', legacy: 'review'),
        _state('g:done', 'تم', 'done', legacy: 'done', tasks: 3),
        _state('g:old', 'قديمة', 'cancelled', legacy: 'done', archived: true),
      ].map(WorkflowState.fromJson).toList(),
    );

void main() {
  test('colours parse, and a bad stored colour falls back instead of crashing', () {
    expect(parseHexColor('#2563EB'), 0xFF2563EB);
    expect(parseHexColor('2563eb'), 0xFF2563EB);
    expect(parseHexColor('red'), 0xFF64748B);
    expect(parseHexColor(null), 0xFF64748B);
  });

  test('a task shows in its own state, else by its legacy status', () {
    final flow = _flow();
    expect(flow.live.map((s) => s.id), ['g:todo', 'g:qa', 'g:review', 'g:done']);
    expect(flow.archived.single.id, 'g:old');

    GroupTask task({String? state, String status = 'todo'}) => GroupTask.fromJson(
        {'id': 't', 'title': 'x', 'status': status, 'state_id': state});
    expect(flow.forTask(task(state: 'g:qa', status: 'in_progress'))!.name, 'QA');
    // An archived state still names its old tasks.
    expect(flow.forTask(task(state: 'g:old', status: 'done'))!.name, 'قديمة');
    // Written by old code: no state id.
    expect(flow.forTask(task(status: 'review'))!.id, 'g:review');
    expect(flow.liveIn(StateCategory.done), 1);
  });

  test('the home payload keeps what the API left out as null', () {
    final guest = GroupHome.fromJson({
      'group': {'id': 'g', 'name': 'Web', 'type': 'software', 'group_role': 'guest'},
      'counts': {'backlog': 2, 'active': 1, 'blocked': 1, 'done': 4},
      'projects': [
        {'id': 'p', 'name': 'Site', 'visibility': 'private', 'open_tasks': 1, 'done_tasks': 3},
      ],
    });
    expect(guest.myTasks, isNull);
    expect(guest.team, isNull);
    expect(guest.openTasks, 4);
    expect(guest.projects.single.isPrivate, isTrue);
    expect(guest.projects.single.progress, 0.75);

    final lead = GroupHome.fromJson({
      'group': {'id': 'g', 'group_role': 'lead'},
      'counts': {},
      'projects': [],
      'my_tasks': [
        {'id': 't', 'title': 'Cart', 'due_at': '2020-01-01', 'category': 'active'},
      ],
      'my_overdue': 1,
      'team': {'members': 3, 'pending_invites': 1, 'blocked': 0, 'unassigned': 2, 'overdue': 1},
    });
    expect(lead.team!.unassigned, 2);
    expect(lead.myTasks!.single.isOverdue(DateTime(2026)), isTrue);
    expect(lead.count(StateCategory.cancelled), 0);
  });

  test('project access reads the override', () {
    final readOnly = ProjectAccess.fromJson({
      'id': 'p',
      'visibility': 'private',
      'override': 'read',
      'capabilities': ['group.view', 'comments.write'],
    });
    expect(readOnly.isPrivate, isTrue);
    expect(readOnly.canEditTasks, isFalse);
    expect(GroupProject.fromJson({'id': 'p', 'my_access': 'read'}).myAccess, 'read');
  });

  testWidgets('the workflow screen lists live and archived states', (tester) async {
    final access = GroupAccess.fromJson({
      'id': 'g1',
      'name': 'App',
      'type': 'software',
      'is_member': true,
      'group_role': 'lead',
      'functional_role': 'tech_lead',
      'capabilities': ['group.view', 'workflow.manage'],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        groupAccessProvider('g1').overrideWith((ref) async => access),
        groupWorkflowProvider('g1').overrideWith((ref) async => _flow()),
      ],
      child: const MaterialApp(home: WorkflowSettingsPage(gid: 'g1')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('QA'), findsOneWidget);
    expect(find.text('مؤرشفة'), findsOneWidget);
    expect(find.text('قديمة'), findsOneWidget);
    expect(find.textContaining('3 مهمة'), findsOneWidget);

    // Archiving a state that holds tasks explains why instead of calling
    // the API.
    final archive = find.descendant(
      of: find.byKey(const ValueKey('g:done')),
      matching: find.byIcon(Icons.archive_outlined),
    );
    await tester.ensureVisible(archive);
    await tester.tap(archive);
    await tester.pump();
    expect(find.textContaining('انقلهم لحالة تانية'), findsOneWidget);
  });

  testWidgets('a member without workflow.manage sees the locked screen', (tester) async {
    final access = GroupAccess.fromJson({
      'id': 'g1',
      'name': 'App',
      'type': 'software',
      'is_member': true,
      'group_role': 'member',
      'functional_role': 'developer',
      'capabilities': ['group.view', 'tasks.edit'],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [groupAccessProvider('g1').overrideWith((ref) async => access)],
      child: const MaterialApp(home: WorkflowSettingsPage(gid: 'g1')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('QA'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
