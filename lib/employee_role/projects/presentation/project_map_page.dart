import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/employee_role/jobs/presentation/operative_job_site_listings_page.dart';
import 'package:red5/employee_role/projects/application/project_map_controller.dart';
import 'package:red5/employee_role/projects/data/project_map_job.dart';
import 'package:red5/employee_role/projects/presentation/operative_site_route_page.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_site_google_map.dart';
import 'package:red5/employee_role/projects/presentation/widgets/project_map_overlays.dart';

class EmployeeProjectMapPage extends ConsumerStatefulWidget {
  const EmployeeProjectMapPage({
    super.key,
    this.projectId,
    this.projectName = 'Project',
    this.activeSites = 0,
  });

  static const path = '/employee-role/projects/map';
  static const name = 'employee-project-map';

  final int? projectId;
  final String projectName;
  final int activeSites;

  @override
  ConsumerState<EmployeeProjectMapPage> createState() =>
      _EmployeeProjectMapPageState();
}

class _EmployeeProjectMapPageState
    extends ConsumerState<EmployeeProjectMapPage> {
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(projectMapControllerProvider.notifier)
          .loadJobs(
            projectId: widget.projectId,
            projectName: widget.projectName,
            activeSites: widget.activeSites,
          );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _selectJob(ProjectMapJob job) {
    ref.read(projectMapControllerProvider.notifier).selectJob(job.id);
  }

  void _clearJobSelection() {
    ref.read(projectMapControllerProvider.notifier).clearSelection();
  }

  ProjectMapJob? _selectedJob(List<ProjectMapJob> jobs, int? selectedJobId) {
    if (selectedJobId == null) return null;
    for (final job in jobs) {
      if (job.id == selectedJobId) return job;
    }
    return null;
  }

  void _openDrawings(List<ProjectMapJob> jobs, int? selectedJobId) {
    final job = _selectedJob(jobs, selectedJobId);
    if (job == null) return;
    context.push(
      OperativeJobSiteListingsPage.path,
      extra: <String, Object?>{
        'jobId': job.id,
        'initialTab': OperativeJobSiteListingsTab.drawings.name,
      },
    );
  }

  void _openRoute(List<ProjectMapJob> jobs, int? selectedJobId) {
    final job = _selectedJob(jobs, selectedJobId);
    if (job == null) return;
    OperativeSiteRoutePage.open(
      context,
      title: job.title,
      subtitle: job.address,
      stableId: job.id,
      latitude: job.position.latitude,
      longitude: job.position.longitude,
    );
  }

  void _searchJobs(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(projectMapControllerProvider.notifier).searchJobs(query);
    });
  }

  Future<void> _showSearchSheet() async {
    final controller = TextEditingController(
      text: ref.read(projectMapControllerProvider).searchQuery,
    );
    final query = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search project jobs',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: Navigator.of(context).pop,
          ),
        );
      },
    );
    controller.dispose();
    if (query != null) _searchJobs(query);
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(projectMapControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: ProjectMapTopBar(
        projectName: mapState.projectName ?? widget.projectName,
        activeSites: mapState.jobs.isEmpty
            ? (mapState.activeSites > 0
                  ? mapState.activeSites
                  : widget.activeSites)
            : mapState.jobs.length,
        onSearch: _showSearchSheet,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: OperativeJobsMapLoader(
              jobs: mapState.jobs,
              selectedJobId: mapState.selectedJobId,
              onJobSelected: (jobId) {
                final job = _selectedJob(mapState.jobs, jobId);
                if (job != null) _selectJob(job);
              },
              onDrawings: () =>
                  _openDrawings(mapState.jobs, mapState.selectedJobId),
              onShowRoutes: () =>
                  _openRoute(mapState.jobs, mapState.selectedJobId),
              onClearSelection: _clearJobSelection,
              isDark: mapState.isDarkMap,
              onToggleTheme: () {
                ref
                    .read(projectMapControllerProvider.notifier)
                    .toggleMapTheme();
              },
            ),
          ),
          ProjectJobsDraggableSheet(
            jobs: mapState.jobs,
            selectedJobId: mapState.selectedJobId,
            isLoading: mapState.isLoading,
            errorMessage: mapState.errorMessage,
            searchQuery: mapState.searchQuery,
            onRefresh: () => ref
                .read(projectMapControllerProvider.notifier)
                .loadJobs(projectId: widget.projectId),
            onRetry: () {
              ref
                  .read(projectMapControllerProvider.notifier)
                  .loadJobs(projectId: widget.projectId);
            },
            onSearchChanged: _searchJobs,
            onJobTap: _selectJob,
          ),
          const ProjectMapBottomNav(),
        ],
      ),
    );
  }
}

/// Stylized offline map painter shared with [OperativePaintedSiteMap].
class ProjectSiteMapPainter extends CustomPainter {
  const ProjectSiteMapPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = isDark ? const Color(0xFF777A7C) : const Color(0xFFBFC1C3);
    canvas.drawRect(Offset.zero & size, background);

    final road = Paint()
      ..color = isDark ? const Color(0xFFE7E7E7) : AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    void drawRoad(List<Offset> points, double width) {
      road.strokeWidth = width;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, road);
    }

    Offset p(double x, double y) => Offset(size.width * x, size.height * y);

    for (final x in <double>[
      0.02,
      0.10,
      0.22,
      0.36,
      0.43,
      0.50,
      0.58,
      0.68,
      0.86,
    ]) {
      drawRoad([p(x, 0.06), p(x, 0.58)], x == 0.43 ? 8 : 4);
    }
    for (final y in <double>[0.13, 0.22, 0.31, 0.39, 0.48, 0.56, 0.64, 0.72]) {
      drawRoad([p(0.0, y), p(0.88, y)], y == 0.31 ? 8 : 4);
    }

    drawRoad([p(0.0, 0.12), p(0.20, 0.20), p(0.36, 0.30), p(0.86, 0.50)], 7);
    drawRoad([p(0.07, 0.0), p(0.27, 0.30), p(0.43, 0.38), p(0.43, 0.78)], 6);
    drawRoad([p(0.86, 0.0), p(1.0, 0.08), p(0.91, 0.20), p(0.84, 0.34)], 6);
    drawRoad([p(0.0, 0.33), p(0.25, 0.45), p(0.58, 0.45), p(0.78, 0.56)], 5);
    drawRoad([p(0.56, 0.0), p(0.56, 0.18), p(0.68, 0.18), p(0.68, 0.32)], 5);

    final block = Paint()
      ..color = isDark ? const Color(0xFF8B8D8F) : const Color(0xFFB4B6B8);
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 5; col++) {
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * (0.45 + col * 0.08),
            size.height * (0.34 + row * 0.055),
            size.width * 0.055,
            size.height * 0.04,
          ),
          block,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ProjectSiteMapPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
