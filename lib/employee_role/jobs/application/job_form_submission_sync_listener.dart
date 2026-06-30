import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/employee_role/offline/operative_sync_coordinator.dart';

/// Starts operative background sync when connectivity is restored.
class JobFormSubmissionSyncListener extends ConsumerWidget {
  const JobFormSubmissionSyncListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(operativeSyncBootstrapProvider);
    return child;
  }
}
