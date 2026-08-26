import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/dashboard/data/job_models.dart';
import 'package:red5/features/dashboard/presentation/jobs_list_refresh.dart';
import 'package:red5/features/dashboard/presentation/views/job_details_page.dart';
import 'package:red5/features/dashboard/presentation/widgets/project_jobs_tab.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

/// Admin jobs list from `GET /api/v1/jobs/`.
class JobsListPage extends ConsumerStatefulWidget {
  const JobsListPage({super.key});

  @override
  ConsumerState<JobsListPage> createState() => _JobsListPageState();
}

class _JobsListPageState extends ConsumerState<JobsListPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();

  static const _divider = Color(0xFFE5E7EB);
  static const _metaGrey = Color(0xFF6B7280);
  static const _dateGrey = Color(0xFF9CA3AF);

  final List<JobRead> _jobs = <JobRead>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  String _jobCategory = JobApiCategory.service;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchPage(reset: true);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(() => _fetchPage(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      if (_isLoadingMore || _page >= _totalPages) return;
      setState(() => _isLoadingMore = true);
    }

    final category = _jobCategory;
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final nextPage = reset ? 1 : (_page + 1);
      final result = await api.fetchJobsPage(
        page: nextPage,
        pageSize: kDefaultApiPageSize,
        search: _searchController.text.trim(),
        jobCategory: category,
      );
      if (!mounted) return;
      if (_jobCategory != category) return;
      setState(() {
        if (reset) {
          _jobs
            ..clear()
            ..addAll(result.items);
        } else {
          _jobs.addAll(result.items);
        }
        _page = result.currentPage;
        _totalPages = result.totalPages;
        _isLoading = false;
        _isLoadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_jobCategory != category) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load jobs',
        );
      });
    }
  }

  void _selectCategory(String category) {
    if (_jobCategory == category) return;
    setState(() {
      _jobCategory = category;
      _jobs.clear();
      _error = null;
    });
    _fetchPage(reset: true);
  }

  void _onRowTap(JobRead job) {
    final row = ProjectJobListItem.fromApi(job);
    final extra = <String, Object?>{
      'jobId': row.id,
      'jobTitle': row.title,
      'projectName': (job.projectName ?? '').trim(),
      'clientName': (job.clientName ?? '').trim(),
      'workerName': row.workerLabel,
      'startDate': row.startDate.toIso8601String(),
      'scheduleDate': row.endDate.toIso8601String(),
      'latitude': row.latitude,
      'longitude': row.longitude,
      'status': row.status == ProjectJobStatus.inProgress
          ? job.displayStatus
          : row.status.label,
    };

    final projectId = job.project?.toString().trim();
    if (projectId == null || projectId.isEmpty || job.isServiceJob) {
      context.push(JobDetailsPage.standalonePathFor(row.id), extra: extra);
      return;
    }

    context.push(
      JobDetailsPage.pathFor(projectId, Uri.encodeComponent(row.id)),
      extra: extra,
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
    );
  }

  Widget _categoryTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _JobsCategoryChip(
            label: 'Service',
            selected: _jobCategory == JobApiCategory.service,
            onTap: () => _selectCategory(JobApiCategory.service),
          ),
          const SizedBox(width: 10),
          _JobsCategoryChip(
            label: 'Project',
            selected: _jobCategory == JobApiCategory.project,
            onTap: () => _selectCategory(JobApiCategory.project),
          ),
        ],
      ),
    );
  }

  Widget _jobRow(ProjectJobListItem job, JobRead source) {
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: () => _onRowTap(source),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job.workerLocationLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodyMedium(color: _metaGrey).copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (source.projectName?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        source.projectName!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.bodySmall(color: _dateGrey).copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (source.clientName?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        source.clientName!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.bodySmall(color: _dateGrey).copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: AppFonts.bodySmall(color: _dateGrey).copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(text: '${job.dateRangeLine} • '),
                          TextSpan(
                            text: job.status.label,
                            style: TextStyle(
                              color: job.status.color,
                              fontWeight: FontWeight.w600,
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
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(jobsListRefreshTickProvider, (previous, next) {
      if (previous == next) return;
      _fetchPage(reset: true);
    });

    final bottomPad = MediaQuery.paddingOf(context).bottom;

    Widget body;
    if (_isLoading && _jobs.isEmpty) {
      body = const AppSkeletonScreenBody(
        style: AppSkeletonScreenBodyStyle.listRows,
      );
    } else if (_error != null && _jobs.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _fetchPage(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (_jobs.isEmpty) {
      body = Center(
        child: Text(
          _searchController.text.trim().isEmpty
              ? (_jobCategory == JobApiCategory.project
                  ? 'No project jobs found'
                  : 'No service jobs found')
              : 'No jobs match your search',
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => _fetchPage(reset: true),
        color: AppColors.inkStrong,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification &&
                notification.metrics.extentAfter < 200 &&
                !_isLoadingMore &&
                _page < _totalPages) {
              _fetchPage();
            }
            return false;
          },
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + bottomPad),
            itemCount: _jobs.length + (_isLoadingMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              thickness: 1,
              color: _divider,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              if (index >= _jobs.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.inkStrong,
                      ),
                    ),
                  ),
                );
              }
              final source = _jobs[index];
              final row = ProjectJobListItem.fromApi(source);
              return _jobRow(row, source);
            },
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _searchBar(),
          _categoryTabs(),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _JobsCategoryChip extends StatelessWidget {
  const _JobsCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFF0F172A) : AppColors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFD1D5DB),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppFonts.labelLarge(
                color: selected ? AppColors.white : const Color(0xFF9CA3AF),
              ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
