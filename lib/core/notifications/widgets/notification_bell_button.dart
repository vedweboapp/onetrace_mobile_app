import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/notifications/app_notifications_controller.dart';
import 'package:red5/core/notifications/presentation/notifications_page.dart';
import 'package:red5/core/theme/app_colors.dart';

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({
    super.key,
    this.iconSize = 22,
    this.color = AppColors.inkStrong,
  });

  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(
      appNotificationsControllerProvider.select((state) => state.unreadCount),
    );

    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: 'Notifications',
      onPressed: () => context.push(NotificationsPage.path),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        child: Icon(
          unreadCount > 0
              ? Icons.notifications_rounded
              : Icons.notifications_none_rounded,
          size: iconSize,
          color: color,
        ),
      ),
    );
  }
}
