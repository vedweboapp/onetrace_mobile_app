import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_const_widget.dart';
import 'package:red5/employee_role/projects/data/project_map_job.dart';

class ProjectMapTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ProjectMapTopBar({
    super.key,
    required this.projectName,
    required this.activeSites,
    required this.onSearch,
  });

  final String projectName;
  final int activeSites;
  final VoidCallback onSearch;

  @override
  Size get preferredSize => const Size.fromHeight(42);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.inkStrong,
      elevation: 1,
      scrolledUnderElevation: 0,
      toolbarHeight: preferredSize.height,
      leadingWidth: 40,
      titleSpacing: 12,
      leading: IconButton(
        onPressed: () {
          if (context.canPop()) context.pop();
        },
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            projectName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          Text(
            '$activeSites active job sites',
            style: AppFonts.labelSmall(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          vGap(10),
        ],
      ),
      actions: [
        IconButton(onPressed: onSearch, icon: const Icon(Icons.search_rounded)),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ],
    );
  }
}

class ProjectMapFloatingButtons extends StatelessWidget {
  const ProjectMapFloatingButtons({
    super.key,
    required this.onCurrentLocation,
    required this.onToggleTheme,
  });

  final VoidCallback onCurrentLocation;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FloatingMapButton(
            icon: Icons.my_location_rounded,
            onTap: onCurrentLocation,
          ),
          const SizedBox(height: 14),
          _FloatingMapButton(icon: Icons.layers_rounded, onTap: onToggleTheme),
        ],
      ),
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  const _FloatingMapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 6,
      shadowColor: AppColors.shadowElevated,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: AppColors.inkStrong, size: 23),
        ),
      ),
    );
  }
}

class ProjectJobsDraggableSheet extends StatelessWidget {
  const ProjectJobsDraggableSheet({
    super.key,
    required this.jobs,
    required this.selectedJobId,
    required this.isLoading,
    required this.errorMessage,
    required this.searchQuery,
    required this.onRefresh,
    required this.onRetry,
    required this.onSearchChanged,
    required this.onJobTap,
  });

  final List<ProjectMapJob> jobs;
  final int? selectedJobId;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProjectMapJob> onJobTap;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final minSize = isWide ? 0.24 : 0.34;
    final initialSize = isWide ? 0.38 : 0.49;
    final maxSize = isWide ? 0.62 : 0.72;
    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      snap: true,
      snapSizes: <double>[minSize, initialSize, maxSize],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowElevated,
                blurRadius: 28,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 96),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SheetHeader(resultCount: jobs.length),
                const SizedBox(height: 16),
                if (isLoading)
                  const _SheetLoading()
                else if (errorMessage != null)
                  _SheetError(message: errorMessage!, onRetry: onRetry)
                else if (jobs.isEmpty)
                  const _SheetEmpty()
                else
                  for (final job in jobs) ...[
                    ProjectJobCard(
                      job: job,
                      selected: job.id == selectedJobId,
                      onTap: () => onJobTap(job),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.resultCount});

  final int resultCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Project Jobs',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(
            '$resultCount results',
            style: AppFonts.labelSmall(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class ProjectJobCard extends StatelessWidget {
  const ProjectJobCard({
    super.key,
    required this.job,
    required this.selected,
    required this.onTap,
  });

  final ProjectMapJob job;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.inkStrong : AppColors.borderLight,
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: AppColors.shadowCard,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.inkStrong : AppColors.surface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: selected ? AppColors.white : AppColors.muted,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.titleSmall(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w900, height: 1.18),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        job.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.bodySmall(
                          color: AppColors.muted,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFF1EFFF)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        job.status,
                        style: AppFonts.labelSmall(
                          color: selected
                              ? const Color(0xFF5E4BFF)
                              : AppColors.muted,
                        ).copyWith(fontWeight: FontWeight.w900, fontSize: 9),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      job.distanceLabel,
                      style: AppFonts.labelLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetLoading extends StatelessWidget {
  const _SheetLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _SheetEmpty extends StatelessWidget {
  const _SheetEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'No mapped jobs found.',
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
      ),
    );
  }
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppFonts.bodyMedium(color: AppColors.error),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class ProjectMapBottomNav extends StatelessWidget {
  const ProjectMapBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _BottomNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: true,
                ),
                _BottomNavItem(icon: Icons.work_rounded, label: 'Jobs'),
                _BottomNavItem(icon: Icons.folder_rounded, label: 'Projects'),
                _BottomNavAvatar(label: 'More'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.inkStrong : AppColors.muted;
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppFonts.labelSmall(
              color: color,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _BottomNavAvatar extends StatelessWidget {
  const _BottomNavAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 11,
            backgroundColor: Color(0xFFD8B48A),
            child: Icon(Icons.person, size: 14, color: AppColors.inkStrong),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppFonts.labelSmall(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
