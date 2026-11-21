import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sixdx/core/layout/app_breakpoints.dart';
import 'package:sixdx/core/layout/responsive_layout.dart';
import 'package:sixdx/features/home/presentation/pages/home_shell.dart';
import 'package:sixdx/features/home/presentation/widgets/home_sidebar.dart';
import 'package:sixdx/shared/widgets/ui_kit.dart';

/// Sizes the test surface in logical pixels and restores it afterwards.
void _useWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) => MaterialApp(home: child);

/// The real shell wired to a four-branch router, like `app_router.dart`.
Widget _shell() {
  final router = GoRouter(
    initialLocation: '/a',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          for (final name in ['A', 'B', 'C', 'D'])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/${name.toLowerCase()}',
                  builder: (_, __) => Scaffold(body: Text('BRANCH_$name')),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('WindowSizeClass', () {
    test('maps widths to the three layouts', () {
      expect(WindowSizeClass.fromWidth(360), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(699), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(700), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(1099), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(1100), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(2560), WindowSizeClass.expanded);
    });

    test('only windows above the compact breakpoint get the sidebar', () {
      expect(WindowSizeClass.compact.usesSidebar, isFalse);
      expect(WindowSizeClass.medium.usesSidebar, isTrue);
      expect(WindowSizeClass.expanded.usesSidebar, isTrue);
      expect(WindowSizeClass.medium.showsSidebarLabels, isFalse);
      expect(WindowSizeClass.expanded.showsSidebarLabels, isTrue);
    });
  });

  testWidgets('ResponsiveLayout falls back to the ambient MediaQuery', (
    tester,
  ) async {
    _useWindowSize(tester, const Size(1400, 900));
    late WindowSizeClass resolved;

    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) {
            resolved = ResponsiveLayout.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolved, WindowSizeClass.expanded);
  });

  testWidgets('ResponsiveLayout publishes the size class it is given', (
    tester,
  ) async {
    _useWindowSize(tester, const Size(1400, 900));
    late WindowSizeClass resolved;

    await tester.pumpWidget(
      _host(
        ResponsiveLayout(
          sizeClass: WindowSizeClass.compact,
          child: Builder(
            builder: (context) {
              resolved = ResponsiveLayout.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // The explicit class wins over the 1400px window.
    expect(resolved, WindowSizeClass.compact);
  });

  testWidgets('AppScreen caps and centres content on a wide window', (
    tester,
  ) async {
    _useWindowSize(tester, const Size(1600, 1000));

    await tester.pumpWidget(
      const MaterialApp(
        home: AppScreen(title: 'المشاريع', children: [SizedBox(height: 400)]),
      ),
    );

    final width = tester.getSize(find.byType(ListView)).width;
    expect(width, lessThanOrEqualTo(AppBreakpoints.maxContentWidth));
    // It is centred rather than pinned to the leading edge.
    final left = tester.getTopLeft(find.byType(ListView)).dx;
    final right = tester.getTopRight(find.byType(ListView)).dx;
    expect(left, greaterThan(0));
    expect(right, lessThan(1600));
  });

  testWidgets('AppScreen keeps the phone gutter on a compact window', (
    tester,
  ) async {
    _useWindowSize(tester, const Size(420, 900));

    await tester.pumpWidget(
      const MaterialApp(
        home: AppScreen(title: 'المشاريع', children: [SizedBox(height: 400)]),
      ),
    );

    final size = tester.getSize(find.byType(ListView));
    expect(size.width, 420);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeSidebar collapses to icons and still reports taps', (
    tester,
  ) async {
    _useWindowSize(tester, const Size(1280, 800));
    final taps = <int>[];

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: Row(
            children: [
              HomeSidebar(
                selectedIndex: 0,
                onDestinationSelected: taps.add,
                extended: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(HomeSidebar)).width,
      AppBreakpoints.sidebarCollapsedWidth,
    );
    expect(find.text('المشاريع'), findsNothing);
    expect(find.byIcon(Icons.folder), findsOneWidget);

    await tester.tap(find.byIcon(Icons.folder));
    await tester.pump();
    expect(taps, [0]);
  });

  testWidgets('HomeSidebar shows its labels when extended', (tester) async {
    _useWindowSize(tester, const Size(1400, 900));
    final taps = <int>[];

    await tester.pumpWidget(
      _host(
        Scaffold(
          body: Row(
            children: [
              HomeSidebar(
                selectedIndex: 0,
                onDestinationSelected: taps.add,
                extended: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(HomeSidebar)).width,
      AppBreakpoints.sidebarExpandedWidth,
    );

    for (final destination in homeNavDestinations) {
      expect(find.text(destination.label), findsOneWidget);
    }

    await tester.tap(find.text('مهامي'));
    await tester.pump();
    expect(taps, [1]);
  });

  testWidgets('a desktop window gets the sidebar instead of the bottom bar',
      (tester) async {
    _useWindowSize(tester, const Size(1280, 800));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.text('BRANCH_A'), findsOneWidget);
    expect(find.byType(HomeSidebar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('مهامي'));
    await tester.pumpAndSettle();
    expect(find.text('BRANCH_B'), findsOneWidget);
  });

  testWidgets('Ctrl+2 switches branch on a desktop window', (tester) async {
    _useWindowSize(tester, const Size(1280, 800));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();
    expect(find.text('BRANCH_A'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('BRANCH_B'), findsOneWidget);
  });

  testWidgets('a phone-sized window keeps the bottom navigation bar',
      (tester) async {
    _useWindowSize(tester, const Size(600, 900));

    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(HomeSidebar), findsNothing);
    expect(find.text('BRANCH_A'), findsOneWidget);

    await tester.tap(find.text('المراجعات'));
    await tester.pumpAndSettle();
    expect(find.text('BRANCH_C'), findsOneWidget);
  });
}
