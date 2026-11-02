import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../routes/app_router.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../tasks/domain/entities/task.dart';
import '../../../tasks/presentation/providers/task_providers.dart';

@RoutePage()
class ReviewsPage extends ConsumerWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksNotifierProvider).value ?? const [];
    final pending = tasks.where((t) => t.status == TaskStatus.review).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('بانتظار مراجعتك')),
      body: pending.isEmpty
          ? Center(
              child: Text(
                'لا توجد مهام بانتظار المراجعة',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = pending[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
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
                          const StatusBadge(
                            label: '4/4 فحوصات',
                            color: AppColors.success,
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (task.prNumber != null)
                            MonoChip(
                              label: 'PR #${task.prNumber}',
                              icon: Icons.merge_type,
                            ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => context.push(
                              AppRoutes.taskDetailPath(task.id),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                            ),
                            child: const Text('مراجعة'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
