import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/groups/domain/group_models.dart';
import 'package:sixdx/features/groups/presentation/providers/group_providers.dart';
import 'package:sixdx/features/groups/presentation/widgets/group_widgets.dart';
import 'package:sixdx/routes/app_router.dart';

GroupAccess _access({
  String role = 'member',
  String functional = 'technician',
  List<String> caps = const ['group.view', 'tests.record'],
}) =>
    GroupAccess.fromJson({
      'id': 'g1',
      'name': 'Power Board',
      'type': 'hardware',
      'template': 'evt_dvt_pvt',
      'is_default': false,
      'is_archived': false,
      'is_member': true,
      'uid': 'u1',
      'group_role': role,
      'functional_role': functional,
      'capabilities': caps,
    });

Widget _scope(GroupAccess access, {String? requires}) => ProviderScope(
      overrides: [
        groupAccessProvider('g1').overrideWith((ref) async => access),
      ],
      child: MaterialApp(
        home: GroupScope(
          gid: 'g1',
          requires: requires,
          builder: (_, a) => Text('inside ${a.name}'),
        ),
      ),
    );

void main() {
  group('GroupAccess', () {
    test('parses roles and capabilities from the API', () {
      final access = _access();
      expect(access.type, GroupType.hardware);
      expect(access.groupRole, GroupRole.member);
      expect(access.uid, 'u1');
      expect(access.can('tests.record'), isTrue);
      expect(access.can(Caps.manageMembers), isFalse);
      expect(access.roleLabel, 'عضو · فني');
    });

    test('a workspace admin outside the group has no role label', () {
      final access = GroupAccess.fromJson({
        'id': 'g1',
        'name': 'X',
        'type': 'software',
        'is_member': false,
        'capabilities': ['group.view', 'members.manage'],
      });
      expect(access.groupRole, isNull);
      expect(access.roleLabel, 'مدير مساحة العمل');
    });

    test('plan usage knows when the limit is reached', () {
      final full = PlanUsage.fromJson(
          {'plan': 'free', 'name': 'العادية', 'max_groups': 10, 'used_groups': 10});
      final pro = PlanUsage.fromJson(
          {'plan': 'pro', 'max_groups': 50, 'used_groups': 10, 'price_cents_monthly': 6000});
      expect(full.canAddGroup, isFalse);
      expect(pro.canAddGroup, isTrue);
      expect(pro.isPaid, isTrue);
    });
  });

  group('safeFrom', () {
    test('follows in-app paths only', () {
      expect(AppRoutes.safeFrom('/invite/abc'), '/invite/abc');
      expect(AppRoutes.safeFrom('/g/1/home?x=1'), '/g/1/home?x=1');
    });

    test('rejects open redirects and loops', () {
      expect(AppRoutes.safeFrom('https://evil.example'), isNull);
      expect(AppRoutes.safeFrom('//evil.example/x'), isNull);
      expect(AppRoutes.safeFrom('/login?from=/x'), isNull);
      expect(AppRoutes.safeFrom('/'), isNull);
      expect(AppRoutes.safeFrom(''), isNull);
      expect(AppRoutes.safeFrom(null), isNull);
    });
  });

  group('GroupScope', () {
    testWidgets('renders the screen when the capability is there', (tester) async {
      await tester.pumpWidget(_scope(_access(), requires: 'tests.record'));
      await tester.pumpAndSettle();
      expect(find.text('inside Power Board'), findsOneWidget);
    });

    testWidgets('shows the locked state for a missing capability', (tester) async {
      await tester.pumpWidget(_scope(_access(), requires: Caps.manageMembers));
      await tester.pumpAndSettle();
      expect(find.text('inside Power Board'), findsNothing);
      expect(find.text('الصفحة دي مش متاحة لدورك'), findsOneWidget);
    });

    testWidgets('shows the error state when access fails', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          groupAccessProvider('g1').overrideWith((ref) async => throw Exception('403')),
        ],
        child: MaterialApp(
          home: GroupScope(gid: 'g1', builder: (_, a) => const Text('inside')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('inside'), findsNothing);
      expect(find.text('مش قادر تفتح المجموعة دي'), findsOneWidget);
    });
  });
}
