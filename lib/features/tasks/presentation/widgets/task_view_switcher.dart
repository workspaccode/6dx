import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// Segmented control that switches between the board / list / calendar views.
class TaskViewSwitcher extends StatelessWidget {
  const TaskViewSwitcher({super.key, required this.current});

  final String current;

  static const _routes = {
    'لوحة': AppRoutes.taskBoard,
    'قائمة': AppRoutes.taskList,
    'تقويم': AppRoutes.taskCalendar,
  };

  @override
  Widget build(BuildContext context) {
    return ViewSegmented(
      current: current,
      onChanged: (view) {
        final route = _routes[view];
        if (route == null || route == current) return;
        context.go(route);
      },
    );
  }
}
