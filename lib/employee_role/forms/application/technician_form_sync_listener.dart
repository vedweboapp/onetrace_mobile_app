import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/connectivity_service.dart';
import 'package:red5/employee_role/forms/application/technician_form_controller.dart';

/// Listens for offline → online transitions and refreshes the active form.
final technicianFormSyncListenerProvider = Provider<void>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  var wasOnline = connectivity.isOnline;

  final subscription = connectivity.isOnlineStream.listen((online) async {
    if (wasOnline || !online) {
      wasOnline = online;
      return;
    }
    wasOnline = online;
    await ref.read(technicianFormControllerProvider.notifier).onConnectivityRestored();
  });

  ref.onDispose(subscription.cancel);
});

/// Mount once on pages that display technician forms.
class TechnicianFormSyncListener extends ConsumerWidget {
  const TechnicianFormSyncListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(technicianFormSyncListenerProvider);
    ref.listen<bool>(
      technicianFormControllerProvider.select((s) => s.showRefreshedNotice),
      (previous, next) {
        if (next != true) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Form updated from server')),
        );
        ref.read(technicianFormControllerProvider.notifier).clearRefreshedNotice();
      },
    );
    return child;
  }
}
