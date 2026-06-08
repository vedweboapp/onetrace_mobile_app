import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/presentation/employee_jobs_page.dart';

class EmployeeJobConfirmationPage extends StatelessWidget {
  const EmployeeJobConfirmationPage({super.key, this.jobTitle});

  static const path = '/employee-role/jobs/confirmation';
  static const name = 'employee-job-confirmation';

  final String? jobTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 52,
        leadingWidth: 46,
        titleSpacing: 0,
        leading: const Icon(Icons.groups_rounded, size: 21),
        title: Text(
          'Confirmation',
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
              children: const [
                SizedBox(height: 4),
                _SuccessMark(),
                SizedBox(height: 22),
                _StatusPill(),
                SizedBox(height: 18),
                _SuccessCopy(),
                SizedBox(height: 28),
                _ReadyPill(),
                SizedBox(height: 42),
                _ConfirmationActivityCard(
                  icon: Icons.access_time_filled_rounded,
                  title: 'Timesheet updated',
                  subtitle: 'Hours logged automatically',
                ),
                SizedBox(height: 14),
                _ConfirmationActivityCard(
                  icon: Icons.wallet_rounded,
                  title: 'Earning added',
                  subtitle: 'Updated in your Job Sheet',
                ),
                SizedBox(height: 34),
                _VerifiedByRow(),
              ],
            ),
          ),
          _CompleteJobBar(onPressed: () => context.go(EmployeeJobsPage.path)),
        ],
      ),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 108,
        height: 108,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Center(
          child: Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F3F5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.inkStrong,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.white,
                  size: 31,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0ECFF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'VERIFICATION COMPLETE',
          style: AppFonts.labelSmall(color: const Color(0xFF4F46E5)).copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _SuccessCopy extends StatelessWidget {
  const _SuccessCopy();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Form submitted\nsuccessfully',
          textAlign: TextAlign.center,
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 24, height: 1.04),
        ),
        const SizedBox(height: 17),
        Text(
          'Your job details and forms have been\nverified. You can now complete the\njob.',
          textAlign: TextAlign.center,
          style: AppFonts.bodyMedium(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w500, height: 1.45),
        ),
      ],
    );
  }
}

class _ReadyPill extends StatelessWidget {
  const _ReadyPill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Ready to complete',
              style: AppFonts.labelMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationActivityCard extends StatelessWidget {
  const _ConfirmationActivityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AppColors.muted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.titleSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.inkStrong,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _VerifiedByRow extends StatelessWidget {
  const _VerifiedByRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.inkStrong,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            color: AppColors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'Verified by Site Manager',
          style: AppFonts.bodySmall(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CompleteJobBar extends StatelessWidget {
  const _CompleteJobBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkStrong,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Complete Job',
                    style: AppFonts.titleSmall(
                      color: AppColors.white,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle_rounded, size: 17),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
