import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/dashboard/data/project_jobs_tree_models.dart';
import 'package:red5/features/dashboard/presentation/views/add_job_page.dart';
import 'package:red5/features/dashboard/presentation/views/project_level_jobs_page.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

enum ProjectJobStatus { inProgress, completed, pending }

extension ProjectJobStatusX on ProjectJobStatus {
  String get label {
    switch (this) {
      case ProjectJobStatus.inProgress:
        return 'In Progress';
      case ProjectJobStatus.completed:
        return 'Completed';
      case ProjectJobStatus.pending:
        return 'Pending';
    }
  }

  Color get color {
    switch (this) {
      case ProjectJobStatus.inProgress:
        return const Color(0xFF16A34A);
      case ProjectJobStatus.completed:
        return const Color(0xFF2563EB);
      case ProjectJobStatus.pending:
        return const Color(0xFF9CA3AF);
    }
  }
}

/// One job row on the global jobs list (flat `GET /jobs/`).
class ProjectJobListItem {
  const ProjectJobListItem({
    required this.id,
    required this.title,
    required this.workerLabel,
    required this.locationLabel,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.latitude,
    this.longitude,
    this.avatarBackground = const Color(0xFFE5E7EB),
    this.avatarInitials,
  });

  factory ProjectJobListItem.fromApi(JobRead job) {
    final status = job.completedAt != null
        ? ProjectJobStatus.completed
        : _statusFromLabel(job.displayStatus);
    final worker = job.displayWorker;
    return ProjectJobListItem(
      id: job.id.toString(),
      title: job.title,
      workerLabel: worker,
      locationLabel: job.displayLocation,
      startDate: job.startDate ?? DateTime.now(),
      endDate: job.endDate ?? job.startDate ?? DateTime.now(),
      status: status,
      avatarBackground: const Color(0xFFD4E4F7),
      avatarInitials: _initialsFor(worker),
    );
  }

  final String id;
  final String title;
  final String workerLabel;
  final String locationLabel;
  final DateTime startDate;
  final DateTime endDate;
  final ProjectJobStatus status;
  final double? latitude;
  final double? longitude;
  final Color avatarBackground;
  final String? avatarInitials;

  String get workerLocationLine => '$workerLabel • $locationLabel';

  String get dateRangeLine {
    final start = startDate.toLocal();
    final end = endDate.toLocal();
    final dayFmt = DateFormat('MMM d');
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    if (startDay == endDay) {
      return '${dayFmt.format(start)} · ${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}';
    }
    return '${dayFmt.format(start)} - ${dayFmt.format(end)}';
  }

  bool matchesQuery(String q) {
    if (q.isEmpty) return true;
    final s = q.toLowerCase();
    return title.toLowerCase().contains(s) ||
        id.toLowerCase().contains(s) ||
        workerLabel.toLowerCase().contains(s) ||
        locationLabel.toLowerCase().contains(s) ||
        status.label.toLowerCase().contains(s);
  }
}

ProjectJobStatus _statusFromLabel(String label) {
  final statusText = label.toLowerCase();
  if (statusText.contains('complete')) return ProjectJobStatus.completed;
  if (statusText.contains('pending') ||
      statusText.contains('to do') ||
      statusText.contains('todo')) {
    return ProjectJobStatus.pending;
  }
  return ProjectJobStatus.inProgress;
}

String _initialsFor(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'W';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

int _levelJobCount(ProjectJobsLevel level) {
  var count = 0;
  for (final plot in level.plots) {
    count += plot.jobs.length;
  }
  return count;
}

int _plotCount(ProjectJobsLevel level) => level.plots.length;

/// Jobs tab on [ProjectDetailsPage] — level list → plot/job detail screen.
class ProjectJobsTab extends ConsumerStatefulWidget {
  const ProjectJobsTab({
    super.key,
    required this.projectId,
    this.projectName,
    this.clientName,
    this.refreshToken,
  });

  final String projectId;
  final String? projectName;
  final String? clientName;
  final Object? refreshToken;

  @override
  ConsumerState<ProjectJobsTab> createState() => _ProjectJobsTabState();
}

class _ProjectJobsTabState extends ConsumerState<ProjectJobsTab> {
  static const _surfaceGrey = Color(0xFFF9FAFB);

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoading = false;
  String? _errorMessage;
  ProjectJobsTree _tree = const ProjectJobsTree();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadJobs();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProjectJobsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_loadJobs());
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadJobs);
    setState(() {});
  }

  Future<void> _loadJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final projectId = widget.projectId.trim();
      final tree = projectId.isEmpty
          ? const ProjectJobsTree()
          : await ref.read(quoteProjectApiClientProvider).fetchProjectJobsTree(
                projectId: projectId,
                search: _searchController.text.trim(),
              );
      if (!mounted) return;
      setState(() {
        _tree = tree;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Could not load jobs',
        );
      });
    }
  }

  void _onAddJob() {
    final id = widget.projectId.trim();
    if (id.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Project id is missing.')),
      );
      return;
    }
    context.push(
      AddJobPage.pathFor(id),
      extra: <String, String>{
        'projectName': (widget.projectName ?? '').trim(),
        'clientName': (widget.clientName ?? '').trim(),
      },
    );
  }

  void _openLevel(ProjectJobsLevel level) {
    final projectId = widget.projectId.trim();
    if (projectId.isEmpty) return;
    context.push(
      ProjectLevelJobsPage.pathFor(projectId),
      extra: ProjectLevelJobsArgs(
        levelName: level.name,
        plots: level.plots,
        projectName: widget.projectName,
        clientName: widget.clientName,
      ),
    );
  }

  void _openManualJobs() {
    final projectId = widget.projectId.trim();
    if (projectId.isEmpty || _tree.manualJobs.isEmpty) return;
    context.push(
      ProjectLevelJobsPage.pathFor(projectId),
      extra: ProjectLevelJobsArgs(
        levelName: 'Manual Jobs',
        plots: [
          ProjectJobsPlot(id: 0, name: 'Manual', jobs: _tree.manualJobs),
        ],
        projectName: widget.projectName,
        clientName: widget.clientName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: _surfaceGrey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: AppColors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            'Jobs',
                            style: AppFonts.headlineSmall(
                              color: AppColors.inkStrong,
                            ).copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                            ),
                          ),
                          const Spacer(),
                          Material(
                            color: const Color(0xFFECECEE),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _onAddJob,
                              customBorder: const CircleBorder(),
                              child: const SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.add,
                                  size: 22,
                                  color: AppColors.inkStrong,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        style: AppFonts.bodyMedium(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search jobs...',
                          hintStyle: AppFonts.bodyMedium(
                            color: AppColors.muted,
                          ).copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF9CA3AF),
                            size: 22,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody(bottomPad)),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 20 + bottomPad,
            child: FloatingActionButton(
              heroTag: 'project_jobs_fab',
              backgroundColor: const Color(0xFF111111),
              foregroundColor: AppColors.white,
              elevation: 4,
              onPressed: _onAddJob,
              child: const Icon(Icons.add, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double bottomPad) {
    if (_isLoading && _tree.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.inkStrong),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadJobs, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_tree.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().isEmpty
              ? 'No jobs found'
              : 'No jobs match your search',
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
      );
    }

    final levelRows = <Widget>[
      for (final level in _tree.levels)
        _LevelListTile(
          name: level.name,
          jobCount: _levelJobCount(level),
          plotCount: _plotCount(level),
          onTap: () => _openLevel(level),
        ),
      if (_tree.manualJobs.isNotEmpty)
        _LevelListTile(
          name: 'Manual Jobs',
          jobCount: _tree.manualJobs.length,
          plotCount: 1,
          onTap: _openManualJobs,
        ),
    ];

    return RefreshIndicator(
      onRefresh: _loadJobs,
      color: AppColors.inkStrong,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 88 + bottomPad),
        itemCount: levelRows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) => levelRows[index],
      ),
    );
  }
}

class _LevelListTile extends StatelessWidget {
  const _LevelListTile({
    required this.name,
    required this.jobCount,
    required this.plotCount,
    required this.onTap,
  });

  static const _border = Color(0xFFE5E7EB);

  final String name;
  final int jobCount;
  final int plotCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jobsLabel = jobCount == 1 ? '1 job' : '$jobCount jobs';
    final plotsLabel = plotCount == 1 ? '1 plot' : '$plotCount plots';

    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.inkStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$jobsLabel • $plotsLabel',
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF6B7280),
                      ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
