import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sixdx/shared/widgets/ui_kit.dart';

/// Regression guard: a `ListTile` under a decorated box makes the framework
/// assert that its background and ink splashes may be invisible. The shared
/// containers therefore paint with `Material` instead of a `BoxDecoration`.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: ListView(children: [child])),
      );

  testWidgets('SettingsTile hosts its ListTile without asserting',
      (tester) async {
    await tester.pumpWidget(
      host(SettingsTile(icon: Icons.lock_outline, title: 'الحساب', onTap: () {})),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsOneWidget);
    // The tile is painted on a Material, so the splash is visible.
    expect(
      find.ancestor(of: find.byType(ListTile), matching: find.byType(Material)),
      findsWidgets,
    );
  });

  testWidgets('a ListTile inside an AppPanel renders without asserting',
      (tester) async {
    await tester.pumpWidget(
      host(
        AppPanel(
          child: ListTile(title: const Text('قناة'), onTap: () {}),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
