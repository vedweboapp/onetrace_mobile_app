import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder widget — form submissions sync on job completion, not on reconnect.
class JobFormSubmissionSyncListener extends ConsumerWidget {
  const JobFormSubmissionSyncListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => child;
}
