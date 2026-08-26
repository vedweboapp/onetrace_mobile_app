import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_timer_banner.dart';

/// Live per-job timer chip. Tapping opens a popup to stop that job's timer.
class EmployeeJobCardTimer extends ConsumerWidget {
  const EmployeeJobCardTimer({
    super.key,
    required this.jobId,
    required this.jobTitle,
    this.compact = false,
  });

  final int jobId;
  final String jobTitle;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(employeeJobSessionProvider);
    if (!session.isTimerRunning(jobId)) return const SizedBox.shrink();

    final label = EmployeeJobTimerBanner.formatDuration(session.elapsedFor(jobId));

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(top: compact ? 4 : 8),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: () => showEmployeeJobTimerStopCard(
              context: context,
              jobId: jobId,
              jobTitle: jobTitle,
            ),
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EFFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFD9D2FF)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: Color(0xFF5E4BFF),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: AppFonts.labelMedium(
                      color: const Color(0xFF5E4BFF),
                    ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showEmployeeJobTimerStopCard({
  required BuildContext context,
  required int jobId,
  required String jobTitle,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.inkStrong.withValues(alpha: 0.45),
    builder: (ctx) => _EmployeeJobTimerStopCard(
      jobId: jobId,
      jobTitle: jobTitle,
    ),
  );
}

class _EmployeeJobTimerStopCard extends ConsumerWidget {
  const _EmployeeJobTimerStopCard({
    required this.jobId,
    required this.jobTitle,
  });

  final int jobId;
  final String jobTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(employeeJobSessionProvider);
    final running = session.isTimerRunning(jobId);
    final elapsed = EmployeeJobTimerBanner.formatDuration(
      session.elapsedFor(jobId),
    );

    return Dialog(
      backgroundColor: AppColors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.inkStrong.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EFFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  size: 28,
                  color: Color(0xFF5E4BFF),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                running ? 'Stop job timer?' : 'Timer stopped',
                textAlign: TextAlign.center,
                style: AppFonts.titleMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                jobTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.bodyMedium(
                  color: AppColors.muted,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              Text(
                elapsed,
                style: AppFonts.headlineSmall(
                  color: AppColors.inkStrong,
                ).copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                running
                    ? 'Time is being logged for this job only.'
                    : 'This job timer is no longer running.',
                textAlign: TextAlign.center,
                style: AppFonts.bodySmall(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              if (running)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () async {
                      await ref
                          .read(employeeJobSessionProvider.notifier)
                          .stopJobTimer(jobId);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkStrong,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Stop timer',
                      style: AppFonts.titleSmall(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    running ? 'Keep running' : 'Close',
                    style: AppFonts.titleSmall(
                      color: AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
