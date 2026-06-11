import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_details_page.dart';

class EmployeeJobSafetyVerificationPage extends ConsumerStatefulWidget {
  const EmployeeJobSafetyVerificationPage({super.key, this.jobId});

  static const path = '/employee-role/jobs/safety-verification';
  static const name = 'employee-job-safety-verification';

  final int? jobId;

  @override
  ConsumerState<EmployeeJobSafetyVerificationPage> createState() =>
      _EmployeeJobSafetyVerificationPageState();
}

class _EmployeeJobSafetyVerificationPageState
    extends ConsumerState<EmployeeJobSafetyVerificationPage> {
  late List<EmployeeSafetyChecklistItem> _items;

  @override
  void initState() {
    super.initState();
    _items = EmployeeJobPreStartSafetyChecklist.items
        .map((item) => item.copyWith(isChecked: false))
        .toList(growable: true);
  }

  bool get _allChecked => _items.every((item) => item.isChecked);

  void _toggleItem(String id) {
    setState(() {
      _items = [
        for (final item in _items)
          item.id == id ? item.copyWith(isChecked: !item.isChecked) : item,
      ];
    });
  }

  void _startJob() {
    final jobId = widget.jobId;
    if (jobId == null || !_allChecked) return;

    ref.read(employeeJobSessionProvider.notifier).startJob(jobId);
    context.pushReplacement(
      EmployeeJobDetailsPage.path,
      extra: <String, Object?>{'jobId': jobId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
        leadingWidth: 42,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 16,
                color: AppColors.inkStrong,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Safety Checklist',
              style: AppFonts.titleSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ],
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
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
              children: [
                Text(
                  'Mandatory Verification',
                  style: AppFonts.headlineSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900, fontSize: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ensure all safety protocols are followed before starting the operation.',
                  style: AppFonts.bodyMedium(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w500, height: 1.4),
                ),
                const SizedBox(height: 28),
                for (final item in _items) ...[
                  _SafetyCheckRow(
                    title: item.title,
                    isChecked: item.isChecked,
                    onTap: () => _toggleItem(item.id),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _allChecked ? _startJob : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.inkStrong,
                          disabledBackgroundColor: const Color(0xFFB8B8BE),
                          foregroundColor: AppColors.white,
                          disabledForegroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Start Job',
                          style: AppFonts.titleSmall(
                            color: AppColors.white,
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          if (context.canPop()) context.pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkStrong,
                          side: const BorderSide(color: AppColors.inkStrong),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppFonts.titleSmall(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyCheckRow extends StatelessWidget {
  const _SafetyCheckRow({
    required this.title,
    required this.isChecked,
    required this.onTap,
  });

  final String title;
  final bool isChecked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.bodyLarge(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked ? AppColors.inkStrong : AppColors.transparent,
                  border: Border.all(
                    color: isChecked ? AppColors.inkStrong : AppColors.border,
                    width: 2,
                  ),
                ),
                child: isChecked
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
