import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
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
  List<EmployeeSafetyChecklistItem> _items = const [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadChecklist);
  }

  Future<void> _loadChecklist() async {
    final jobId = widget.jobId;
    if (jobId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Job not found.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final job = await ref.read(employeeJobRepositoryProvider).fetchJobDetail(
            jobId: jobId,
          );
      if (!mounted) return;
      setState(() {
        _items = job.safetyChecklist;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          error,
          genericFallback: 'Could not load checklist.',
        );
      });
    }
  }

  bool get _allRequiredChecked {
    final requiredItems =
        _items.where((item) => item.isRequired).toList(growable: false);
    if (requiredItems.isEmpty) return true;
    return requiredItems.every((item) => item.isChecked);
  }

  void _toggleItem(String id) {
    setState(() {
      _items = [
        for (final item in _items)
          item.id == id ? item.copyWith(isChecked: !item.isChecked) : item,
      ];
    });
  }

  Future<void> _startJob() async {
    final jobId = widget.jobId;
    if (jobId == null || !_allRequiredChecked || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (_items.isNotEmpty) {
        await ref.read(employeeJobRepositoryProvider).updateJobChecklists(
              jobId: jobId,
              items: _items,
            );
      }

      await ref.read(employeeJobRepositoryProvider).markJobStarted(jobId);

      ref.read(employeeJobSessionProvider.notifier).startJob(jobId);
      if (!mounted) return;
      context.pushReplacement(
        EmployeeJobDetailsPage.path,
        extra: <String, Object?>{'jobId': jobId},
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              error,
              genericFallback: 'Could not save checklist. Please try again.',
            ),
          ),
        ),
      );
    }
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
              'Job Checklist',
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
                  'Complete every required checklist item before starting the job.',
                  style: AppFonts.bodyMedium(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w500, height: 1.4),
                ),
                const SizedBox(height: 28),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: AppFonts.bodyMedium(color: AppColors.error),
                  )
                else if (_items.isEmpty)
                  Text(
                    'No checklist items for this job.',
                    style: AppFonts.bodyMedium(color: AppColors.muted),
                  )
                else
                  for (final item in _items) ...[
                    _SafetyCheckRow(
                      title: item.title,
                      isChecked: item.isChecked,
                      isRequired: item.isRequired,
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
                        onPressed:
                            !_isLoading && _allRequiredChecked && !_isSubmitting
                                ? _startJob
                                : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.inkStrong,
                          disabledBackgroundColor: const Color(0xFFB8B8BE),
                          foregroundColor: AppColors.white,
                          disabledForegroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(
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
                        onPressed: _isSubmitting
                            ? null
                            : () {
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
    required this.isRequired,
    required this.onTap,
  });

  final String title;
  final bool isChecked;
  final bool isRequired;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.bodyLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (isRequired)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Required',
                          style: AppFonts.labelSmall(color: AppColors.muted),
                        ),
                      ),
                  ],
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
