import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/notifications/app_notifications_controller.dart';
import 'package:red5/core/notifications/data/notification_models.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/employee_role/jobs/application/employee_job_navigation.dart';
import 'package:red5/employee_role/jobs/application/employee_jobs_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  static const path = '/notifications';
  static const name = 'notifications';

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      final notifier = ref.read(appNotificationsControllerProvider.notifier);
      if (!ref.read(appNotificationsControllerProvider).isInitialized) {
        notifier.initialize();
      } else {
        notifier.refresh();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      ref.read(appNotificationsControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _openNotification(AppNotificationItem notification) async {
    await ref
        .read(appNotificationsControllerProvider.notifier)
        .markRead(notification.id);

    final jobId = notification.referenceIdAsInt;
    if (jobId == null) return;
    if (!mounted) return;

    final jobs = ref.read(employeeJobsControllerProvider).jobs;
    EmployeeJobSummary? job;
    for (final candidate in jobs) {
      if (candidate.id == jobId) {
        job = candidate;
        break;
      }
    }

    job ??= EmployeeJobSummary(
      id: jobId,
      title: notification.title.trim().isNotEmpty
          ? notification.title.trim()
          : 'Job #$jobId',
      status: EmployeeJobStatus.upcoming,
      earning: '',
      location: '',
      schedule: '',
      primaryActionLabel: 'View',
    );

    openEmployeeJob(context, job: job);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appNotificationsControllerProvider);
    final today = <AppNotificationItem>[];
    final earlier = <AppNotificationItem>[];
    final now = DateTime.now();
    for (final item in state.items) {
      if (_isSameDay(item.createdAt, now)) {
        today.add(item);
      } else {
        earlier.add(item);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Notifications',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          if (state.unreadCount > 0 || state.items.any((e) => !e.isRead))
            TextButton(
              onPressed: state.isMarkingAll
                  ? null
                  : () => ref
                        .read(appNotificationsControllerProvider.notifier)
                        .markAllRead(),
              child: Text(
                state.isMarkingAll ? 'Marking…' : 'Mark all as read',
                style: AppFonts.bodyMedium(
                  color: const Color(0xFF2563EB),
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: _buildBody(state, today, earlier),
    );
  }

  Widget _buildBody(
    AppNotificationsState state,
    List<AppNotificationItem> today,
    List<AppNotificationItem> earlier,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(
        child: AppSkeletonScreenBody(scrollable: false, toastBlockCount: 5),
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.inkStrong, size: 48),
            const SizedBox(height: 12),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.inkStrong),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref
                  .read(appNotificationsControllerProvider.notifier)
                  .initialize(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkStrong,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: AppColors.muted.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 12),
              Text(
                'No notifications yet',
                style: AppFonts.titleMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Job assignments, form updates, and comments will show up here.',
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(appNotificationsControllerProvider.notifier).refresh(),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 28),
        children: [
          if (today.isNotEmpty) ...[
            const _SectionHeader('TODAY'),
            for (final item in today)
              _NotificationTile(
                notification: item,
                timeLabel: _relativeTime(item.createdAt),
                onTap: () => _openNotification(item),
              ),
          ],
          if (earlier.isNotEmpty) ...[
            const _SectionHeader('EARLIER'),
            for (final item in earlier)
              _NotificationTile(
                notification: item,
                timeLabel: _relativeTime(item.createdAt),
                onTap: () => _openNotification(item),
              ),
          ],
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _relativeTime(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && _isSameDay(when, now)) {
      return '${diff.inHours}h ago';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(when, yesterday)) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    return '$m/$d/${when.year}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF)).copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.timeLabel,
    required this.onTap,
  });

  final AppNotificationItem notification;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _NotificationVisual.of(notification.notificationType);
    final unread = !notification.isRead;

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: style.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(style.icon, color: style.foreground, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.headline,
                      style: AppFonts.bodyLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    if (notification.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: AppFonts.bodyMedium(
                          color: const Color(0xFF6B7280),
                        ).copyWith(fontSize: 13.5, height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: AppFonts.labelSmall(
                        color: const Color(0xFF9CA3AF),
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationVisual {
  const _NotificationVisual({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;

  static _NotificationVisual of(NotificationType type) {
    switch (type) {
      case NotificationType.jobAssigned:
        return const _NotificationVisual(
          icon: Icons.work_outline_rounded,
          foreground: Color(0xFF2563EB),
          background: Color(0xFFDBEAFE),
        );
      case NotificationType.jobReassigned:
        return const _NotificationVisual(
          icon: Icons.sync_rounded,
          foreground: Color(0xFF2563EB),
          background: Color(0xFFDBEAFE),
        );
      case NotificationType.jobRemoved:
        return const _NotificationVisual(
          icon: Icons.close_rounded,
          foreground: Color(0xFFDC2626),
          background: Color(0xFFFEE2E2),
        );
      case NotificationType.dueDateUpdated:
        return const _NotificationVisual(
          icon: Icons.calendar_today_rounded,
          foreground: Color(0xFFD97706),
          background: Color(0xFFFEF3C7),
        );
      case NotificationType.jobStatusUpdated:
        return const _NotificationVisual(
          icon: Icons.play_arrow_rounded,
          foreground: Color(0xFF2563EB),
          background: Color(0xFFDBEAFE),
        );
      case NotificationType.newComment:
        return const _NotificationVisual(
          icon: Icons.chat_bubble_outline_rounded,
          foreground: Color(0xFF059669),
          background: Color(0xFFD1FAE5),
        );
      case NotificationType.newFormAssigned:
        return const _NotificationVisual(
          icon: Icons.assignment_outlined,
          foreground: Color(0xFF7C3AED),
          background: Color(0xFFEDE9FE),
        );
      case NotificationType.submissionRejected:
        return const _NotificationVisual(
          icon: Icons.warning_amber_rounded,
          foreground: Color(0xFFEA580C),
          background: Color(0xFFFFEDD5),
        );
      case NotificationType.unknown:
        return const _NotificationVisual(
          icon: Icons.notifications_outlined,
          foreground: Color(0xFF4B5563),
          background: Color(0xFFF3F4F6),
        );
    }
  }
}
