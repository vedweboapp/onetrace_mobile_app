import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_jobs_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/presentation/operative_job_site_listings_page.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_sheet_widgets.dart';
import 'package:red5/employee_role/projects/data/operative_map_geocoder.dart';
import 'package:red5/employee_role/projects/data/operative_map_pins_cache.dart';
import 'package:red5/employee_role/projects/presentation/operative_site_route_page.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_site_action_sheet.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_site_google_map.dart';

enum EmployeeJobsHomeViewMode { map, list }

/// Operative home job tab — map or site list, with icon toggle above the map.
class EmployeeJobsTabContent extends ConsumerStatefulWidget {
  const EmployeeJobsTabContent({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  ConsumerState<EmployeeJobsTabContent> createState() =>
      _EmployeeJobsTabContentState();
}

class _EmployeeJobsTabContentState extends ConsumerState<EmployeeJobsTabContent> {
  EmployeeJobsHomeViewMode _viewMode = EmployeeJobsHomeViewMode.map;
  int? _selectedJobId;
  var _isDarkMap = false;

  List<EmployeeJobSummary> _visibleJobs(EmployeeJobsState state) {
    final session = ref.read(employeeJobSessionProvider.notifier);
    return _sortedJobs(state.visibleJobsFor(session));
  }

  List<EmployeeJobSummary> _sortedJobs(List<EmployeeJobSummary> jobs) {
    final sorted = [...jobs];
    sorted.sort((a, b) {
      final byStatus = _statusRank(a.status).compareTo(_statusRank(b.status));
      if (byStatus != 0) return byStatus;

      final aDate = a.startDate;
      final bDate = b.startDate;
      if (aDate == null && bDate == null) return a.id.compareTo(b.id);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });
    return sorted;
  }

  static int _statusRank(EmployeeJobStatus status) {
    return switch (status) {
      EmployeeJobStatus.inProgress => 0,
      EmployeeJobStatus.upcoming => 1,
      EmployeeJobStatus.pending => 2,
      EmployeeJobStatus.completed => 3,
    };
  }

  void _selectJob(int jobId) {
    setState(() => _selectedJobId = jobId);
  }

  void _clearJobSelection() {
    if (_selectedJobId == null) return;
    setState(() => _selectedJobId = null);
  }

  Future<void> _openRouteFor(
    EmployeeJobSummary job,
    List<EmployeeJobSummary> jobs,
  ) async {
    double? latitude;
    double? longitude;
    final pinCache = ref.read(operativeMapPinsCacheProvider);
    var pins = pinCache.cachedEmployeeJobPins(jobs);
    pins ??= await resolveEmployeeJobMapPins(
      jobs: jobs,
      geocoder: ref.read(operativeMapGeocoderProvider),
    );
    for (final pin in pins) {
      if (pin.id == 'job-${job.id}') {
        latitude = pin.position.latitude;
        longitude = pin.position.longitude;
        break;
      }
    }
    if (!mounted) return;
    await OperativeSiteRoutePage.open(
      context,
      title: job.title,
      subtitle: job.location,
      stableId: job.id,
      latitude: latitude,
      longitude: longitude,
    );
  }

  void _openRoute(List<EmployeeJobSummary> jobs) {
    final job = _selectedJob(jobs);
    if (job == null) return;
    unawaited(_openRouteFor(job, jobs));
  }

  void _openSiteListings(EmployeeJobSummary job) {
    context.push(
      OperativeJobSiteListingsPage.path,
      extra: <String, Object?>{
        'jobId': job.id,
        'initialTab': OperativeJobSiteListingsTab.drawings.name,
      },
    );
  }

  void _openSiteListingsForSelected(List<EmployeeJobSummary> jobs) {
    final job = _selectedJob(jobs);
    if (job == null) return;
    _openSiteListings(job);
  }

  Future<void> _onSiteListTap(
    EmployeeJobSummary job,
    List<EmployeeJobSummary> jobs,
  ) async {
    final action = await showOperativeSiteActionSheet(
      context,
      title: job.title,
      subtitle: job.location,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case OperativeSiteAction.drawings:
        _openSiteListings(job);
      case OperativeSiteAction.showRoutes:
        unawaited(_openRouteFor(job, jobs));
    }
  }

  EmployeeJobSummary? _selectedJob(List<EmployeeJobSummary> jobs) {
    final id = _selectedJobId;
    if (id == null) return null;
    for (final job in jobs) {
      if (job.id == id) return job;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeJobsControllerProvider);
    final controller = ref.read(employeeJobsControllerProvider.notifier);
    final jobs = _visibleJobs(state);

    if (state.isLoading && state.jobs.isEmpty) {
      return widget.embedded
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: AppSkeletonBox(width: 88, height: 40, borderRadius: 20),
                ),
                SizedBox(height: 12),
                AppSkeletonBox(height: 400, borderRadius: 16),
              ],
            )
          : const AppSkeletonProjectsListBody();
    }

    if (state.errorMessage != null && state.jobs.isEmpty) {
      return _JobsErrorState(
        message: state.errorMessage!,
        onRetry: controller.load,
        compact: widget.embedded,
      );
    }

    final listSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No sites found.',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
          )
        else
          for (var i = 0; i < jobs.length; i++) ...[
            _EmployeeSiteCard(
              job: jobs[i],
              onTap: () => _onSiteListTap(jobs[i], jobs),
            ),
            if (i < jobs.length - 1) const SizedBox(height: 14),
          ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapHeight = widget.embedded
            ? 400.0
            : (constraints.maxHeight.isFinite
                ? (constraints.maxHeight - 52).clamp(320.0, 900.0)
                : 500.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: widget.embedded ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _JobMapListIconToggle(
                value: _viewMode,
                onChanged: (mode) => setState(() => _viewMode = mode),
              ),
            ),
            const SizedBox(height: 12),
            if (_viewMode == EmployeeJobsHomeViewMode.list) listSection,
            Offstage(
              offstage: _viewMode != EmployeeJobsHomeViewMode.map,
              child: SizedBox(
                height: mapHeight,
                child: OperativeEmployeeJobsMapLoader(
                  jobs: jobs,
                  selectedJobId: _selectedJobId,
                  onJobSelected: _selectJob,
                  onDrawings: () => _openSiteListingsForSelected(jobs),
                  onShowRoutes: () => _openRoute(jobs),
                  onClearSelection: _clearJobSelection,
                  isDark: _isDarkMap,
                  onToggleTheme: () => setState(() => _isDarkMap = !_isDarkMap),
                  borderRadius: widget.embedded ? 16 : 0,
                  embedded: widget.embedded,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact list / map icon toggle shown above the operative job map.
class _JobMapListIconToggle extends StatelessWidget {
  const _JobMapListIconToggle({
    required this.value,
    required this.onChanged,
  });

  final EmployeeJobsHomeViewMode value;
  final ValueChanged<EmployeeJobsHomeViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconToggleSegment(
            icon: Icons.format_list_bulleted_rounded,
            selected: value == EmployeeJobsHomeViewMode.list,
            onTap: () => onChanged(EmployeeJobsHomeViewMode.list),
          ),
          _IconToggleSegment(
            icon: Icons.location_on_rounded,
            selected: value == EmployeeJobsHomeViewMode.map,
            onTap: () => onChanged(EmployeeJobsHomeViewMode.map),
          ),
        ],
      ),
    );
  }
}

class _IconToggleSegment extends StatelessWidget {
  const _IconToggleSegment({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 32,
          decoration: BoxDecoration(
            color: selected ? AppColors.inkStrong : AppColors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? AppColors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _EmployeeSiteCard extends StatelessWidget {
  const _EmployeeSiteCard({
    required this.job,
    required this.onTap,
  });

  final EmployeeJobSummary job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlightEarning = job.status == EmployeeJobStatus.inProgress;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  JobSheetStatusChip(status: job.status),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Earning',
                        style: AppFonts.labelSmall(
                          color: AppColors.muted,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.earning,
                        style: AppFonts.titleSmall(
                          color: highlightEarning
                              ? const Color(0xFF00A553)
                              : AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w900, fontSize: 17),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                job.title,
                style: AppFonts.titleMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900, fontSize: 18, height: 1.1),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 17,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.location,
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 17,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      job.schedule,
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobsErrorState extends StatelessWidget {
  const _JobsErrorState({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 12 : 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: compact ? 32 : 40,
            color: AppColors.muted,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
