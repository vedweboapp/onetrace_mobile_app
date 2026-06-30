import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/offline/operative_sync_coordinator.dart';

/// Mount on operative shells to auto-sync when connectivity returns.
class OperativeSyncScope extends ConsumerWidget {
  const OperativeSyncScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(operativeSyncBootstrapProvider);

    ref.listen<AsyncValue<int>>(
      operativePendingSyncCountProvider,
      (previous, next) {
        final count = next.valueOrNull;
        if (count == null || count <= 0) return;
        final prevCount = previous?.valueOrNull ?? 0;
        if (count >= prevCount) return;
        if (!context.mounted) return;
        context.showTopSnackBar(
          SnackBar(
            content: Text(
              count == 0
                  ? 'All offline changes synced to the server.'
                  : '$count change(s) still waiting to sync.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    return child;
  }
}
