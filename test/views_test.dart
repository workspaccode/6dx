import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sixdx/features/tasks/presentation/pages/task_board_page.dart';
import 'package:sixdx/features/tasks/presentation/pages/task_views_page.dart';
import 'package:sixdx/shared/widgets/ui_kit.dart';

void main() {
  testWidgets('ViewSegmented fires onChanged and board navigates to list view',
      (tester) async {
    String? currentView;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ViewSegmented(
              current: 'لوحة',
              onChanged: (view) => currentView = view,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('قائمة'));
    await tester.pump();

    expect(currentView, 'قائمة');
  });

  testWidgets('board segmented switch pushes the list route', (tester) async {
    final router = GoRouter(
      initialLocation: '/tasks/board',
      routes: [
        GoRoute(
          path: '/tasks/board',
          builder: (_, __) => const TaskBoardPage(),
        ),
        GoRoute(
          path: '/tasks/list',
          builder: (_, __) => const TaskListPage(),
        ),
      ],
    );

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('قائمة'));
    await tester.pumpAndSettle();

    // The list page shows the app bar subtitle "عرض القائمة".
    expect(find.text('عرض القائمة'), findsOneWidget);
  });
}