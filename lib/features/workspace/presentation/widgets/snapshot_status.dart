import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/feedback.dart';
import '../providers/workspace_providers.dart';

/// The state of the workspace snapshot for a screen built on it: a thin
/// progress bar on the first load, and the error with "حاول تاني" when it
/// failed — so an unreachable server never looks like an empty workspace.
class SnapshotStatus extends ConsumerWidget {
  const SnapshotStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(workspaceSnapshotProvider);
    if (snapshot.isLoading && !snapshot.hasValue) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    final error = snapshot.error;
    if (error == null) return const SizedBox.shrink();
    return Material(
      color: AppColors.danger.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                describeError(error, fallback: 'تعذّر تحميل البيانات.'),
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(workspaceSnapshotProvider),
              child: const Text('حاول تاني'),
            ),
          ],
        ),
      ),
    );
  }
}
