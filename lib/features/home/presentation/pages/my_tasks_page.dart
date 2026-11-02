import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/app_states.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../tasks/presentation/pages/task_board_page.dart';
import '../../../tasks/presentation/providers/task_providers.dart';

@RoutePage()
class MyTasksPage extends ConsumerWidget {
  const MyTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksNotifierProvider).value ?? const [];
    final isLoading = ref.watch(tasksNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مهامي'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.taskBoard),
            icon: const Icon(Icons.view_kanban_outlined),
          ),
        ],
      ),
      body: isLoading && tasks.isEmpty
          ? const AppLoadingView()
          : tasks.isEmpty
              ? const AppEmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'لا توجد مهام',
                  message: 'المهام المسندة إليك ستظهر هنا.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return InkWell(
                      onTap: () => context.push('${AppRoutes.taskDetail}/${task.id}'),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  task.key,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                const Spacer(),
                                StatusBadge(
                                  label: statusLabel(task.status),
                                  color: statusColor(task.status),
                                  dense: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              task.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              task.projectName ?? '',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
