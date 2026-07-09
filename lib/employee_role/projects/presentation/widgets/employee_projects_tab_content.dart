import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/employee_role/projects/application/employee_projects_controller.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';
import 'package:red5/employee_role/projects/data/operative_map_geocoder.dart';
import 'package:red5/employee_role/projects/data/operative_map_pins_cache.dart';
import 'package:red5/employee_role/projects/presentation/operative_site_route_page.dart';
import 'package:red5/employee_role/projects/presentation/project_map_page.dart';
import 'package:red5/employee_role/projects/presentation/widgets/employee_project_card.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_site_action_sheet.dart';
import 'package:red5/employee_role/projects/presentation/widgets/operative_site_google_map.dart';

enum EmployeeProjectViewMode { map, list }

/// Operative project tab — map or project list with pin action card.
class EmployeeProjectsTabContent extends ConsumerStatefulWidget {
  const EmployeeProjectsTabContent({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  ConsumerState<EmployeeProjectsTabContent> createState() =>
      _EmployeeProjectsTabContentState();
}

class _EmployeeProjectsTabContentState
    extends ConsumerState<EmployeeProjectsTabContent> {
  EmployeeProjectViewMode _viewMode = EmployeeProjectViewMode.map;
  int? _selectedProjectId;
  var _isDarkMap = false;

  @override
  void initState() {
    super.initState();
    if (!widget.embedded) {
      Future.microtask(() {
        ref.read(employeeProjectsControllerProvider.notifier).ensureLoaded();
      });
    }
  }

  void _selectProject(int projectId) {
    setState(() => _selectedProjectId = projectId);
  }

  void _clearProjectSelection() {
    if (_selectedProjectId == null) return;
    setState(() => _selectedProjectId = null);
  }

  Future<void> _openRouteFor(
    EmployeeProjectSummary project,
    List<EmployeeProjectSummary> projects,
  ) async {
    double? latitude;
    double? longitude;
    final pinCache = ref.read(operativeMapPinsCacheProvider);
    var pins = pinCache.cachedProjectPins(projects);
    pins ??= await resolveProjectMapPins(
      projects: projects,
      geocoder: ref.read(operativeMapGeocoderProvider),
    );
    for (final pin in pins) {
      if (pin.id == 'project-${project.id}') {
        latitude = pin.position.latitude;
        longitude = pin.position.longitude;
        break;
      }
    }
    if (!mounted) return;
    await OperativeSiteRoutePage.open(
      context,
      title: project.title,
      subtitle: project.address,
      stableId: project.id,
      latitude: latitude,
      longitude: longitude,
    );
  }

  void _openRoute(List<EmployeeProjectSummary> projects) {
    final project = _selectedProject(projects);
    if (project == null) return;
    unawaited(_openRouteFor(project, projects));
  }

  void _openProjectMapFor(EmployeeProjectSummary project) {
    context.push(
      EmployeeProjectMapPage.path,
      extra: <String, Object?>{
        'projectId': project.id,
        'projectName': project.title,
        'activeSites': project.activeSites,
      },
    );
  }

  void _openProjectMap(List<EmployeeProjectSummary> projects) {
    final project = _selectedProject(projects);
    if (project == null) return;
    _openProjectMapFor(project);
  }

  Future<void> _onProjectListTap(
    EmployeeProjectSummary project,
    List<EmployeeProjectSummary> projects,
  ) async {
    final action = await showOperativeSiteActionSheet(
      context,
      title: project.title,
      subtitle: project.address,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case OperativeSiteAction.drawings:
        _openProjectMapFor(project);
      case OperativeSiteAction.showRoutes:
        unawaited(_openRouteFor(project, projects));
    }
  }

  EmployeeProjectSummary? _selectedProject(
    List<EmployeeProjectSummary> projects,
  ) {
    final id = _selectedProjectId;
    if (id == null) return null;
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeProjectsControllerProvider);
    final controller = ref.read(employeeProjectsControllerProvider.notifier);
    final projects = state.visibleProjects;

    if (state.isLoading && state.projects.isEmpty) {
      return widget.embedded
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: AppSkeletonBox(width: 88, height: 40, borderRadius: 20),
                ),
                SizedBox(height: 12),
                AppSkeletonBox(height: 380, borderRadius: 16),
              ],
            )
          : const AppSkeletonProjectsListBody();
    }

    if (state.errorMessage != null && state.projects.isEmpty) {
      return _ProjectsErrorState(
        message: state.errorMessage!,
        onRetry: controller.load,
        compact: widget.embedded,
      );
    }

    final listSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (projects.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No projects found.',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
          )
        else
          for (var i = 0; i < projects.length; i++) ...[
            EmployeeProjectCard(
              project: projects[i],
              onTap: () => _onProjectListTap(projects[i], projects),
            ),
            if (i < projects.length - 1) const SizedBox(height: 16),
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
              child: _ProjectMapListIconToggle(
                value: _viewMode,
                onChanged: (mode) => setState(() => _viewMode = mode),
              ),
            ),
            const SizedBox(height: 12),
            if (_viewMode == EmployeeProjectViewMode.list) listSection,
            Offstage(
              offstage: _viewMode != EmployeeProjectViewMode.map,
              child: SizedBox(
                height: mapHeight,
                child: OperativeProjectsMapLoader(
                  projects: projects,
                  selectedProjectId: _selectedProjectId,
                  onProjectSelected: _selectProject,
                  onDrawings: () => _openProjectMap(projects),
                  onShowRoutes: () => _openRoute(projects),
                  onClearSelection: _clearProjectSelection,
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

class _ProjectMapListIconToggle extends StatelessWidget {
  const _ProjectMapListIconToggle({
    required this.value,
    required this.onChanged,
  });

  final EmployeeProjectViewMode value;
  final ValueChanged<EmployeeProjectViewMode> onChanged;

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
            selected: value == EmployeeProjectViewMode.list,
            onTap: () => onChanged(EmployeeProjectViewMode.list),
          ),
          _IconToggleSegment(
            icon: Icons.location_on_rounded,
            selected: value == EmployeeProjectViewMode.map,
            onTap: () => onChanged(EmployeeProjectViewMode.map),
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

class _ProjectsErrorState extends StatelessWidget {
  const _ProjectsErrorState({
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
