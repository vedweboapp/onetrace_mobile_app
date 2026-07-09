import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_details_page.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_drawings_list_body.dart';
import 'package:red5/employee_role/projects/application/project_map_controller.dart';
import 'package:red5/employee_role/projects/presentation/widgets/project_map_overlays.dart';

enum OperativeJobSiteListingsTab { list, drawings }

/// List + Drawings for a job site — opened from the home map pin "Drawings" action.
class OperativeJobSiteListingsPage extends ConsumerStatefulWidget {
  const OperativeJobSiteListingsPage({
    super.key,
    required this.jobId,
    this.initialTab = OperativeJobSiteListingsTab.drawings,
  });

  static const path = '/employee-role/jobs/site-listings';
  static const name = 'operative-job-site-listings';

  final int jobId;
  final OperativeJobSiteListingsTab initialTab;

  static OperativeJobSiteListingsPage? fromExtra(Object? extra) {
    if (extra is! Map) return null;
    final map = Map<String, dynamic>.from(extra);
    final rawJobId = map['jobId'];
    final jobId = rawJobId is int
        ? rawJobId
        : int.tryParse(rawJobId?.toString() ?? '');
    if (jobId == null || jobId <= 0) return null;

    var initialTab = OperativeJobSiteListingsTab.drawings;
    final rawTab = map['initialTab']?.toString().trim().toLowerCase();
    if (rawTab == OperativeJobSiteListingsTab.list.name) {
      initialTab = OperativeJobSiteListingsTab.list;
    } else if (rawTab == OperativeJobSiteListingsTab.drawings.name ||
        rawTab == ProjectMapViewTab.drawings.name) {
      initialTab = OperativeJobSiteListingsTab.drawings;
    }

    return OperativeJobSiteListingsPage(
      jobId: jobId,
      initialTab: initialTab,
    );
  }

  @override
  ConsumerState<OperativeJobSiteListingsPage> createState() =>
      _OperativeJobSiteListingsPageState();
}

class _OperativeJobSiteListingsPageState
    extends ConsumerState<OperativeJobSiteListingsPage> {
  late OperativeJobSiteListingsTab _tab = widget.initialTab;
  EmployeeJobDetail? _job;
  var _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadJob);
  }

  Future<void> _loadJob() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final detail = await ref
          .read(employeeJobRepositoryProvider)
          .fetchJobDetail(jobId: widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = detail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load site details.';
      });
    }
  }

  ProjectMapViewTab get _mapTab => _tab == OperativeJobSiteListingsTab.drawings
      ? ProjectMapViewTab.drawings
      : ProjectMapViewTab.list;

  void _onTabChanged(ProjectMapViewTab tab) {
    setState(() {
      _tab = tab == ProjectMapViewTab.drawings
          ? OperativeJobSiteListingsTab.drawings
          : OperativeJobSiteListingsTab.list;
    });
  }

  void _openJobDetails() {
    context.push(
      EmployeeJobDetailsPage.path,
      extra: <String, Object?>{'jobId': widget.jobId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final title = job?.siteDetail?.name ?? job?.title ?? 'Site';
    final pinCount = job == null
        ? 0
        : job.levels.fold<int>(0, (sum, level) => sum + level.pinCount);
    final subtitle = pinCount > 0
        ? '$pinCount active pin${pinCount == 1 ? '' : 's'}'
        : (job?.siteDetail?.address ?? job?.block ?? '');

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: AppColors.transparent,
        leadingWidth: 40,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.titleMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            if (subtitle.trim().isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.labelSmall(
                  color: AppColors.muted,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
              ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.borderLight),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            child: ProjectMapTabSwitcher(
              selectedTab: _mapTab,
              onChanged: _onTabChanged,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                : _errorMessage != null
                    ? _ErrorState(
                        message: _errorMessage!,
                        onRetry: _loadJob,
                      )
                    : job == null
                        ? const _EmptyState()
                        : _tab == OperativeJobSiteListingsTab.drawings
                            ? EmployeeJobDrawingsListBody(
                                jobIds: [widget.jobId],
                                initialItems: ref
                                    .read(employeeJobRepositoryProvider)
                                    .drawingListItemsForDetail(job),
                                emptyMessage:
                                    'No drawings linked to this site yet.',
                              )
                            : _SiteListTab(
                                job: job,
                                onOpenJobDetails: _openJobDetails,
                              ),
          ),
        ],
      ),
    );
  }
}

class _SiteListTab extends StatelessWidget {
  const _SiteListTab({
    required this.job,
    required this.onOpenJobDetails,
  });

  final EmployeeJobDetail job;
  final VoidCallback onOpenJobDetails;

  @override
  Widget build(BuildContext context) {
    final pins = <EmployeeJobDrawingPin>[];
    for (final level in job.levels) {
      for (final plot in level.plots) {
        pins.addAll(plot.pins);
      }
    }

    if (pins.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        children: [
          _JobSummaryCard(job: job, onTap: onOpenJobDetails),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      itemCount: pins.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final pin = pins[index];
        return _PinLocationCard(
          pin: pin,
          fallbackAddress: job.siteDetail?.address ?? job.block,
          onTap: onOpenJobDetails,
        );
      },
    );
  }
}

class _PinLocationCard extends StatelessWidget {
  const _PinLocationCard({
    required this.pin,
    required this.fallbackAddress,
    required this.onTap,
  });

  final EmployeeJobDrawingPin pin;
  final String fallbackAddress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = pin.statusName.trim().isNotEmpty
        ? pin.statusName.trim().toUpperCase()
        : 'SCHEDULED';
    final isActive = status.contains('ACTIVE') ||
        status.contains('PROGRESS') ||
        status.contains('IN PROGRESS');

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.inkStrong,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            pin.displayLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.titleSmall(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFE8F8EE)
                                : const Color(0xFFFFF4E8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: AppFonts.labelSmall(
                              color: isActive
                                  ? const Color(0xFF00A553)
                                  : const Color(0xFFE67E22),
                            ).copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pin.location.trim().isNotEmpty
                          ? pin.location.trim()
                          : fallbackAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobSummaryCard extends StatelessWidget {
  const _JobSummaryCard({
    required this.job,
    required this.onTap,
  });

  final EmployeeJobDetail job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
                    'JOB',
                    style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.title,
                style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                job.currentStatus,
                style: AppFonts.labelSmall(
                  color: AppColors.muted,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              if (job.plot.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  job.plot,
                  style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
                    fontWeight: FontWeight.w600,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Job not found.',
        style: AppFonts.bodyMedium(color: AppColors.muted),
      ),
    );
  }
}
