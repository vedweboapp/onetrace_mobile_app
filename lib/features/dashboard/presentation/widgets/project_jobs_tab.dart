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
import 'package:red5/features/dashboard/presentation/views/add_job_page.dart';
import 'package:red5/features/dashboard/presentation/views/job_details_page.dart';
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

/// One job row on the project Jobs tab (title, worker, location, dates, status).
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

  /// e.g. "Worker 3"
  final String workerLabel;

  /// e.g. "Block A, L02"
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
    final fmt = DateFormat('MMM d');
    return '${fmt.format(startDate)} - ${fmt.format(endDate)}';
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
  if (statusText.contains('pending')) return ProjectJobStatus.pending;
  return ProjectJobStatus.inProgress;
}

String _initialsFor(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return 'W';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

/// Jobs list for [ProjectDetailsPage] — matches design (worker, location, status).
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoading = false;
  String? _errorMessage;
  List<ProjectJobListItem> _jobs = const [];

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
      final rows = await ref
          .read(quoteProjectApiClientProvider)
          .fetchAllJobs(search: _searchController.text.trim(), pageSize: 50);
      if (!mounted) return;
      setState(() {
        _jobs = rows.map(ProjectJobListItem.fromApi).toList(growable: false);
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

  void _onRowTap(ProjectJobListItem job) {
    final projectId = widget.projectId.trim();
    if (projectId.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Project id is missing.')),
      );
      return;
    }
    context.push(
      JobDetailsPage.pathFor(projectId, Uri.encodeComponent(job.id)),
      extra: <String, Object?>{
        'jobId': job.id,
        'jobTitle': job.title,
        'projectName': (widget.projectName ?? '').trim(),
        'clientName': (widget.clientName ?? '').trim(),
        'workerName': job.workerLabel,
        'startDate': job.startDate.toIso8601String(),
        'scheduleDate': job.endDate.toIso8601String(),
        'latitude': job.latitude,
        'longitude': job.longitude,
        'status': job.status == ProjectJobStatus.inProgress
            ? 'Active'
            : job.status.label,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    const metaGrey = Color(0xFF6B7280);
    const dateGrey = Color(0xFF9CA3AF);

    return ColoredBox(
      color: AppColors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Jobs',
                      style: AppFonts.headlineSmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w800, fontSize: 28),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search jobs...',
                    hintStyle: AppFonts.bodyMedium(
                      color: AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
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
              Expanded(
                child: _isLoading && _jobs.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppColors.inkStrong,
                        ),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: AppFonts.bodyMedium(
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _loadJobs,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _jobs.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? 'No jobs found'
                              : 'No jobs match your search',
                          style: AppFonts.bodyMedium(color: AppColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadJobs,
                        color: AppColors.inkStrong,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(0, 4, 0, 88 + bottomPad),
                          itemCount: _jobs.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFE5E7EB),
                            indent: 16,
                            endIndent: 16,
                          ),
                          itemBuilder: (context, index) {
                            final job = _jobs[index];
                            return Material(
                              color: AppColors.white,
                              child: InkWell(
                                onTap: () => _onRowTap(job),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              job.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  AppFonts.titleMedium(
                                                    color: AppColors.inkStrong,
                                                  ).copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 17,
                                                    height: 1.25,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                _WorkerAvatar(
                                                  background:
                                                      job.avatarBackground,
                                                  initials: job.avatarInitials,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    job.workerLocationLine,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style:
                                                        AppFonts.bodyMedium(
                                                          color: metaGrey,
                                                        ).copyWith(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 14,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text.rich(
                                              TextSpan(
                                                style:
                                                    AppFonts.bodySmall(
                                                      color: dateGrey,
                                                    ).copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 14,
                                                    ),
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        '${job.dateRangeLine} • ',
                                                  ),
                                                  TextSpan(
                                                    text: job.status.label,
                                                    style: TextStyle(
                                                      color: job.status.color,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Color(0xFFCBD5E1),
                                        size: 26,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
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
}

class _WorkerAvatar extends StatelessWidget {
  const _WorkerAvatar({required this.background, this.initials});

  final Color background;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: background,
      child: initials != null && initials!.isNotEmpty
          ? Text(
              initials!,
              style: AppFonts.labelSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 10),
            )
          : const Icon(
              Icons.person_rounded,
              size: 16,
              color: Color(0xFF4B5563),
            ),
    );
  }
}
