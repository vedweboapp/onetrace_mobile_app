import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/employee_role/projects/application/employee_projects_controller.dart';
import 'package:red5/employee_role/projects/data/employee_project_detail.dart';
import 'package:red5/employee_role/projects/presentation/employee_project_details_page.dart';
import 'package:red5/employee_role/projects/presentation/project_map_page.dart';
import 'package:red5/employee_role/projects/presentation/widgets/employee_project_card.dart';

class EmployeeProjectsListContent extends ConsumerStatefulWidget {
  const EmployeeProjectsListContent({super.key});

  @override
  ConsumerState<EmployeeProjectsListContent> createState() =>
      _EmployeeProjectsListContentState();
}

class _EmployeeProjectsListContentState
    extends ConsumerState<EmployeeProjectsListContent> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(employeeProjectsControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openProject(EmployeeProjectSummary project) {
    context.push(
      EmployeeProjectDetailsPage.path,
      extra: <String, Object?>{
        'projectId': project.id,
        'projectName': project.title,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeProjectsControllerProvider);
    final controller = ref.read(employeeProjectsControllerProvider.notifier);
    final projects = state.visibleProjects;

    if (state.isLoading && state.projects.isEmpty) {
      return const AppSkeletonProjectsListBody();
    }

    if (state.errorMessage != null && state.projects.isEmpty) {
      return _ProjectsErrorState(
        message: state.errorMessage!,
        onRetry: () => controller.load(force: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.load(force: true),
      child: ListView(
        clipBehavior: Clip.none,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        children: [
          _EmployeeProjectsSearchField(
            controller: _searchController,
            onChanged: controller.setSearchQuery,
          ),
          const SizedBox(height: 14),
          _EmployeeProjectFilterChips(
            selectedFilter: state.filter,
            onChanged: controller.setFilter,
          ),
          const SizedBox(height: 18),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: AppColors.borderLight,
                color: AppColors.inkStrong,
              ),
            ),
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
            for (final project in projects) ...[
              EmployeeProjectCard(
                project: project,
                onTap: () => _openProject(project),
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }
}

class EmployeeProjectsHomePreview extends ConsumerStatefulWidget {
  const EmployeeProjectsHomePreview({super.key});

  @override
  ConsumerState<EmployeeProjectsHomePreview> createState() =>
      _EmployeeProjectsHomePreviewState();
}

class _EmployeeProjectsHomePreviewState
    extends ConsumerState<EmployeeProjectsHomePreview> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_ensureLoaded);
  }

  void _ensureLoaded() {
    final state = ref.read(employeeProjectsControllerProvider);
    if (!state.isLoading && state.projects.isEmpty) {
      ref.read(employeeProjectsControllerProvider.notifier).load();
    }
  }

  void _openProject(EmployeeProjectSummary project) {
    context.push(
      EmployeeProjectDetailsPage.path,
      extra: <String, Object?>{
        'projectId': project.id,
        'projectName': project.title,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeProjectsControllerProvider);
    final controller = ref.read(employeeProjectsControllerProvider.notifier);
    final preview = state.projects.take(3).toList(growable: false);

    if (state.isLoading && preview.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProjectsSectionHeader(
            title: "Today's Projects",
            actionLabel: 'See Map',
          ),
          SizedBox(height: 12),
          AppSkeletonProjectCard(),
          SizedBox(height: 16),
          AppSkeletonProjectCard(),
          SizedBox(height: 16),
          AppSkeletonProjectCard(),
        ],
      );
    }

    if (state.errorMessage != null && preview.isEmpty) {
      return _ProjectsErrorState(
        message: state.errorMessage!,
        onRetry: () => controller.load(force: true),
        compact: true,
      );
    }

    if (preview.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ProjectsSectionHeader(
            title: "Today's Projects",
            actionLabel: 'See Map',
          ),
          const SizedBox(height: 12),
          Text(
            'No projects assigned yet.',
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
        ],
      );
    }

    final first = preview.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProjectsSectionHeader(
          title: "Today's Projects",
          actionLabel: 'See Map',
          onAction: () {
            context.push(
              EmployeeProjectMapPage.path,
              extra: <String, Object?>{
                'projectId': first.id,
                'projectName': first.title,
                'activeSites': first.activeSites,
              },
            );
          },
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < preview.length; i++) ...[
          EmployeeProjectCard(
            project: preview[i],
            onTap: () => _openProject(preview[i]),
          ),
          if (i < preview.length - 1) const SizedBox(height: 16),
        ],
      ],
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

class _EmployeeProjectsSearchField extends StatelessWidget {
  const _EmployeeProjectsSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search projects...',
        hintStyle: AppFonts.bodyMedium(
          color: AppColors.mutedLight,
        ).copyWith(fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.inkStrong),
        ),
      ),
    );
  }
}

class _EmployeeProjectFilterChips extends StatelessWidget {
  const _EmployeeProjectFilterChips({
    required this.selectedFilter,
    required this.onChanged,
  });

  final EmployeeProjectFilter selectedFilter;
  final ValueChanged<EmployeeProjectFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProjectFilterChip(
          label: 'All',
          selected: selectedFilter == EmployeeProjectFilter.all,
          onTap: () => onChanged(EmployeeProjectFilter.all),
        ),
        const SizedBox(width: 10),
        _ProjectFilterChip(
          label: 'Active',
          selected: selectedFilter == EmployeeProjectFilter.active,
          onTap: () => onChanged(EmployeeProjectFilter.active),
        ),
        const SizedBox(width: 10),
        _ProjectFilterChip(
          label: 'Completed',
          selected: selectedFilter == EmployeeProjectFilter.completed,
          onTap: () => onChanged(EmployeeProjectFilter.completed),
        ),
      ],
    );
  }
}

class _ProjectFilterChip extends StatelessWidget {
  const _ProjectFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.inkStrong : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppFonts.labelLarge(
            color: selected ? AppColors.white : AppColors.muted,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _ProjectsSectionHeader extends StatelessWidget {
  const _ProjectsSectionHeader({
    required this.title,
    required this.actionLabel,
    this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppFonts.titleLarge(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
          ),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: Text(
              actionLabel,
              style: AppFonts.labelLarge(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          )
        else
          Text(
            actionLabel,
            style: AppFonts.labelLarge(
              color: AppColors.mutedLight,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
      ],
    );
  }
}
