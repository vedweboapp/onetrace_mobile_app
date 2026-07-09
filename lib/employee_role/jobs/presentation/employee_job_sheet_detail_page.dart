import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/data/employee_job_sheet.dart';
import 'package:red5/employee_role/jobs/data/employee_job_sheet_detail_builder.dart';
import 'package:red5/employee_role/jobs/data/job_form_submission_repository.dart';
import 'package:red5/employee_role/offline/operative_offline_store.dart';

class EmployeeJobSheetDetailPage extends ConsumerStatefulWidget {
  const EmployeeJobSheetDetailPage({
    super.key,
    required this.job,
  });

  final EmployeeJobSummary job;

  static const path = '/employee-role/job-sheet/detail';
  static const name = 'employee-job-sheet-detail';

  @override
  ConsumerState<EmployeeJobSheetDetailPage> createState() =>
      _EmployeeJobSheetDetailPageState();
}

class _EmployeeJobSheetDetailPageState
    extends ConsumerState<EmployeeJobSheetDetailPage> {
  EmployeeJobSheetDetail? _detail;
  var _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDetail);
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(employeeJobRepositoryProvider);
      final submissionRepository =
          ref.read(jobFormSubmissionRepositoryProvider);
      final session = ref.read(employeeJobSessionProvider.notifier);
      final offlineStore = ref.read(operativeOfflineStoreProvider);

      final detailResult = await repository.fetchJobDetailWithSource(
        jobId: widget.job.id,
      );
      final jobRead = await offlineStore.readCachedJobDetail(widget.job.id);
      final linkedFormIds = detailResult.detail.linkedFormIds;
      final completedFormIds = linkedFormIds.isEmpty
          ? <int>{}
          : await submissionRepository.completedFormIdsForJob(
              jobId: widget.job.id,
              formIds: linkedFormIds,
              assignments: detailResult.detail.formAssignments,
            );
      final allFormsComplete = linkedFormIds.isNotEmpty &&
          linkedFormIds.every(completedFormIds.contains);

      if (!mounted) return;
      setState(() {
        _detail = EmployeeJobSheetDetailBuilder.build(
          summary: widget.job,
          detail: detailResult.detail,
          jobRead: jobRead,
          session: session,
          completedFormIds: completedFormIds,
          allFormsComplete: allFormsComplete,
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      final session = ref.read(employeeJobSessionProvider.notifier);
      setState(() {
        _detail = EmployeeJobSheetDetailBuilder.build(
          summary: widget.job,
          session: session,
        );
        _isLoading = false;
        _errorMessage = 'Some job details could not be loaded. Showing available data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final backLabel =
        widget.job.projectName?.trim().isNotEmpty == true
            ? widget.job.projectName!.trim()
            : 'Jobs';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _JobSheetDetailAppBar(
              backLabel: backLabel,
              onBack: () => context.pop(),
            ),
            if (_isLoading)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: AppSkeletonProjectsListBody(
                    includeSearchAndFilters: false,
                    cardCount: 2,
                  ),
                ),
              )
            else if (_detail == null)
              Expanded(
                child: Center(
                  child: Text(
                    'No job details found.',
                    style: AppFonts.bodyMedium(color: AppColors.muted),
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                    children: [
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: AppFonts.bodySmall(color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _JobSheetDetailHeader(detail: _detail!),
                      const SizedBox(height: 18),
                      _TimesheetSummaryCard(detail: _detail!),
                      const SizedBox(height: 12),
                      _ComplianceFormCard(detail: _detail!),
                      const SizedBox(height: 22),
                      _ActivityTimeline(steps: _detail!.timeline),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JobSheetDetailAppBar extends StatelessWidget {
  const _JobSheetDetailAppBar({
    required this.backLabel,
    required this.onBack,
  });

  final String backLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 18, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.inkStrong,
          ),
          Expanded(
            child: Text(
              backLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.titleSmall(
                color: AppColors.muted,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobSheetDetailHeader extends StatelessWidget {
  const _JobSheetDetailHeader({required this.detail});

  final EmployeeJobSheetDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                detail.title,
                style: AppFonts.headlineSmall(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900, fontSize: 26, height: 1.1),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.inkStrong,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                detail.statusLabel,
                style: AppFonts.labelSmall(color: AppColors.white).copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFFD8B48A),
              child: Icon(Icons.person, size: 16, color: AppColors.inkStrong),
            ),
            const SizedBox(width: 8),
            Text(
              'Site ID: ${detail.siteId}',
              style: AppFonts.bodySmall(
                color: AppColors.muted,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimesheetSummaryCard extends StatelessWidget {
  const _TimesheetSummaryCard({required this.detail});

  final EmployeeJobSheetDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TIMESHEET SUMMARY',
                style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: Color(0xFF5E4BFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimesheetMetric(
                  label: 'Start Time',
                  value: detail.startTime,
                ),
              ),
              Expanded(
                child: _TimesheetMetric(
                  label: 'End Time',
                  value: detail.endTime,
                ),
              ),
              Expanded(
                child: _TimesheetMetric(
                  label: 'Total Worked',
                  value: detail.totalWorked,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                detail.totalEarning,
                style: AppFonts.headlineSmall(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900, fontSize: 28),
              ),
              const Spacer(),
              Text(
                'Total Earning',
                style: AppFonts.titleSmall(
                  color: const Color(0xFF5E4BFF),
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimesheetMetric extends StatelessWidget {
  const _TimesheetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.labelSmall(
            color: AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ],
    );
  }
}

class _ComplianceFormCard extends StatelessWidget {
  const _ComplianceFormCard({required this.detail});

  final EmployeeJobSheetDetail detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: AppColors.muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.complianceTitle,
                  style: AppFonts.titleSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  detail.complianceSubtitle,
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (detail.complianceVerified)
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF5E4BFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 16, color: AppColors.white),
            )
          else
            Icon(Icons.chevron_right_rounded, color: AppColors.muted.withValues(alpha: 0.6)),
        ],
      ),
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.steps});

  final List<EmployeeJobSheetTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACTIVITY TIMELINE',
          style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 14),
        ...List.generate(steps.length, (index) {
          final step = steps[index];
          final isLast = index == steps.length - 1;
          return _TimelineRow(
            step: step,
            showConnector: !isLast,
            connectorCompleted: step.state == EmployeeJobSheetTimelineState.completed,
          );
        }),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.showConnector,
    required this.connectorCompleted,
  });

  final EmployeeJobSheetTimelineStep step;
  final bool showConnector;
  final bool connectorCompleted;

  @override
  Widget build(BuildContext context) {
    final isCompleted = step.state == EmployeeJobSheetTimelineState.completed;
    final isActive = step.state == EmployeeJobSheetTimelineState.active;
    final dotColor = isCompleted
        ? const Color(0xFF5E4BFF)
        : isActive
            ? AppColors.inkStrong
            : AppColors.borderLight;
    final labelColor = isCompleted
        ? const Color(0xFF5E4BFF)
        : isActive
            ? AppColors.inkStrong
            : AppColors.muted;
    final dotSize = isCompleted ? 12.0 : 8.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.only(top: isCompleted ? 2 : 4),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: connectorCompleted
                          ? const Color(0xFF5E4BFF)
                          : AppColors.borderLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: showConnector ? 18 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: AppFonts.titleSmall(color: labelColor).copyWith(
                      fontWeight: isActive || isCompleted
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                  if (step.timestamp != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.timestamp!,
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
