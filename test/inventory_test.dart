import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/features/groups/domain/hardware_models.dart';
import 'package:sixdx/features/groups/domain/inventory_models.dart';
import 'package:sixdx/features/groups/presentation/pages/inventory_pages.dart';
import 'package:sixdx/features/groups/presentation/providers/inventory_providers.dart';

HwOverview _overview(List<String> caps) => HwOverview.fromJson({'phases': [], 'capabilities': caps});

void main() {
  test('stock, PO and demand parsing', () {
    final s = StockEntry.fromJson({
      'part_number': 'R-10K',
      'on_hand': 100,
      'reserved': 120,
      'available': -20,
      'locations': [
        {'location': 'Shelf-A', 'on_hand': 100},
      ],
    });
    expect(s.isShort, isTrue);
    expect(s.locations['Shelf-A'], 100);

    final po = PurchaseOrder.fromJson({
      'id': 'p',
      'code': 'PO-001',
      'vendor': 'Digi',
      'status': 'partially_received',
      'currency': 'EGP',
      'lines': [
        {'part_number': 'R-10K', 'qty': 120, 'received_qty': 100},
      ],
    });
    expect(po.canReceive, isTrue);
    expect(po.lines.single.open, 20);
    expect(po.totalCents, isNull); // no prices.view
    expect(money(1250, 'EGP'), '12.50 EGP');

    final d = DemandLine.fromJson({'part_number': 'X', 'needed': 10, 'shortage': 4, 'order_now': true});
    expect(d.orderNow, isTrue);
    expect(d.shortage, 4);
  });

  testWidgets('the purchasing tab flags what to order now', (tester) async {
    const key = (gid: 'g1', pid: 'p1');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        demandProvider(key).overrideWith((ref) async => [
              DemandLine.fromJson({
                'part_number': 'MCU-1',
                'needed': 10,
                'reserved': 0,
                'on_order': 0,
                'available': 2,
                'shortage': 8,
                'order_now': true,
              }),
            ]),
        posProvider(key).overrideWith((ref) async => const []),
        reservationsProvider(key).overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ProjectPurchasingTab(projectKey: key, overview: _overview(['po.request'])),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('اطلب دلوقتي'), findsOneWidget);
    expect(find.textContaining('عجز 8'), findsOneWidget);
    expect(find.text('أمر شراء'), findsOneWidget); // po.request may open a draft
    expect(find.text('حجز'), findsNothing); // reserving is builds.manage
  });
}
