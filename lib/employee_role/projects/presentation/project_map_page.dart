import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/employee_role/projects/application/project_map_controller.dart';
import 'package:red5/employee_role/projects/data/project_map_job.dart';
import 'package:red5/employee_role/projects/presentation/widgets/project_map_overlays.dart';

class EmployeeProjectMapPage extends ConsumerStatefulWidget {
  const EmployeeProjectMapPage({
    super.key,
    this.projectName = 'Riverside Tower',
    this.activeSites = 3,
  });

  static const path = '/employee-role/projects/map';
  static const name = 'employee-project-map';

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
      ref.read(projectMapControllerProvider.notifier).loadJobs();
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
        projectName: widget.projectName,
        activeSites: mapState.jobs.isEmpty
            ? widget.activeSites
            : mapState.jobs.length,
        onSearch: _showSearchSheet,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: InbuiltProjectSiteMap(
              jobs: mapState.jobs,
              selectedJobId: mapState.selectedJobId,
              isDark: mapState.isDarkMap,
              onJobTap: _selectJob,
            ),
          ),
          Positioned(
            right: 12,
            top: MediaQuery.sizeOf(context).height * 0.40,
            child: ProjectMapFloatingButtons(
              onCurrentLocation: () {
                final selected =
                    mapState.selectedJob ?? mapState.jobs.firstOrNull;
                if (selected != null) _selectJob(selected);
              },
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
            onRefresh: () =>
                ref.read(projectMapControllerProvider.notifier).loadJobs(),
            onRetry: () {
              ref.read(projectMapControllerProvider.notifier).loadJobs();
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

class InbuiltProjectSiteMap extends StatelessWidget {
  const InbuiltProjectSiteMap({
    super.key,
    required this.jobs,
    required this.selectedJobId,
    required this.isDark,
    required this.onJobTap,
  });

  final List<ProjectMapJob> jobs;
  final int? selectedJobId;
  final bool isDark;
  final ValueChanged<ProjectMapJob> onJobTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _ProjectSiteMapPainter(isDark: isDark)),
            for (final job in jobs)
              _PositionedSitePin(
                job: job,
                canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
                selected: job.id == selectedJobId,
                onTap: () => onJobTap(job),
              ),
          ],
        );
      },
    );
  }
}

/// positioned site pin view
class _PositionedSitePin extends StatelessWidget {
  const _PositionedSitePin({
    required this.job,
    required this.canvasSize,
    required this.selected,
    required this.onTap,
  });

  final ProjectMapJob job;
  final Size canvasSize;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final point = _sitePointFor(job.id);
    final size = selected ? 42.0 : 32.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: point.dx * canvasSize.width - size / 2,
      top: point.dy * canvasSize.height - size / 2,
      child: _SiteMapPin(selected: selected, size: size, onTap: onTap),
    );
  }

  static Offset _sitePointFor(int jobId) {
    return switch (jobId) {
      101 => const Offset(0.56, 0.25),
      102 => const Offset(0.81, 0.19),
      103 => const Offset(0.28, 0.42),
      _ => const Offset(0.62, 0.34),
    };
  }
}

/// Site Map Pin view
class _SiteMapPin extends StatelessWidget {
  const _SiteMapPin({
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final bool selected;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: selected ? AppColors.inkStrong : AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.inkStrong, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.location_on_rounded,
            color: selected ? AppColors.white : AppColors.inkStrong,
            size: size * 0.48,
          ),
        ),
      ),
    );
  }
}

/// Project Site Map painter
class _ProjectSiteMapPainter extends CustomPainter {
  const _ProjectSiteMapPainter({required this.isDark});

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
  bool shouldRepaint(covariant _ProjectSiteMapPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}
