import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/layout/responsive_layout.dart';
import '../../../../routes/app_router.dart';
import '../widgets/home_sidebar.dart';

/// The signed-in shell.
///
/// A phone gets the bottom navigation bar; a desktop window gets a sidebar
/// (icons only while the window is narrow) plus keyboard shortcuts for the
/// branches and for search.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Ctrl on Windows/Linux, ⌘ on macOS.
  static bool get _usesCommandKey =>
      defaultTargetPlatform == TargetPlatform.macOS;

  static const List<LogicalKeyboardKey> _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];

  void _selectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeClass = ResponsiveLayout.of(context);

    if (!sizeClass.usesSidebar) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _selectBranch,
          destinations: [
            for (final destination in homeNavDestinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    final command = _usesCommandKey;
    return CallbackShortcuts(
      bindings: {
        for (final destination in homeNavDestinations)
          SingleActivator(
            _digitKeys[destination.shortcut - 1],
            control: !command,
            meta: command,
          ): () =>
              _selectBranch(destination.shortcut - 1),
        SingleActivator(
          LogicalKeyboardKey.keyK,
          control: !command,
          meta: command,
        ): () =>
            context.push(AppRoutes.taskSearch),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeSidebar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _selectBranch,
                extended: sizeClass.showsSidebarLabels,
              ),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      ),
    );
  }
}
