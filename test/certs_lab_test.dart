import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/groups/data/certs_lab_api.dart';
import 'package:sixdx/features/groups/domain/group_models.dart';
import 'package:sixdx/features/groups/domain/hardware_models.dart';
import 'package:sixdx/features/groups/presentation/pages/hardware_pages.dart';
import 'package:sixdx/features/groups/presentation/providers/group_providers.dart';
import 'package:sixdx/features/groups/presentation/providers/hardware_providers.dart';

void main() {
  test('booking times come back local, private bookings carry nothing', () {
    final b = LabBooking.fromJson({
      'id': 'b',
      'asset_name': 'Chamber',
      'starts_at': '2026-12-01T07:00:00Z',
      'ends_at': '2026-12-01T09:00:00Z',
      'private': true,
    });
    expect(b.startsAt.isUtc, isFalse);
    expect(b.endsAt.difference(b.startsAt), const Duration(hours: 2));
    expect(b.private, isTrue);
    expect(b.purpose, isNull);
  });

  testWidgets('the client sees phases and certifications only', (tester) async {
    const key = (gid: 'g1', pid: 'p1');
    final access = GroupAccess.fromJson({
      'id': 'g1',
      'name': 'Power Board',
      'type': 'hardware',
      'is_member': true,
      'group_role': 'guest',
      'functional_role': 'client',
      'capabilities': ['group.view'],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        hwOverviewProvider(key).overrideWith((ref) async => HwOverview.fromJson({'phases': [], 'capabilities': []})),
        groupProjectsProvider('g1').overrideWith((ref) async => const []),
        certsProvider(key).overrideWith((ref) async => Certifications(canManage: false, certs: [
              Certification.fromJson({'id': 'c', 'standard': 'FCC', 'status': 'testing', 'overdue': true}),
            ])),
      ],
      child: MaterialApp(home: HardwareProjectPage(access: access, pid: 'p1')),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Tab), findsNWidgets(2));
    expect(find.widgetWithText(Tab, 'المراحل'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'الشهادات'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'BOM'), findsNothing);
    expect(find.byIcon(Icons.link_rounded), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'الشهادات'));
    await tester.pumpAndSettle();
    expect(find.textContaining('FCC'), findsOneWidget);
    expect(find.textContaining('متأخرة'), findsOneWidget);
    expect(find.text('شهادة'), findsNothing); // no create button for the client
  });
}
