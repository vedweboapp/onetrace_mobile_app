import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/employee_role/jobs/application/employee_jobs_controller.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/presentation/widgets/employee_site_menu.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/application/employee_job_navigation.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_sheet_page.dart';
import 'package:red5/employee_role/reports/presentation/employee_reports_page.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/sites/presentation/employee_sites_page.dart';
import 'package:red5/employee_role/employee_home/employee_home_page.dart';

class EmployeeJobsPage extends ConsumerStatefulWidget {
  const EmployeeJobsPage({super.key});

  static const path = '/employee-role/jobs';
  static const name = 'employee-jobs';

  @override
  ConsumerState<EmployeeJobsPage> createState() => _EmployeeJobsPageState();
}

class _EmployeeJobsPageState extends ConsumerState<EmployeeJobsPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(child: EmployeeJobsContent(includeBottomNav: true)),
    );
  }
}

class EmployeeJobsContent extends ConsumerStatefulWidget {
  const EmployeeJobsContent({
    super.key,
    this.includeBottomNav = false,
    this.showHeader = true,
  });

  final bool includeBottomNav;

  /// When embedded in [RoleHomeScaffold], the scaffold provides the shared app bar.
  final bool showHeader;

  @override
  ConsumerState<EmployeeJobsContent> createState() =>
      _EmployeeJobsContentState();
}

class _EmployeeJobsContentState extends ConsumerState<EmployeeJobsContent> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(employeeJobsControllerProvider.notifier).load();
    });
  }

  void _openDetails(EmployeeJobSummary job) {
    openEmployeeJob(context, job: job);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeJobsControllerProvider);
    final controller = ref.read(employeeJobsControllerProvider.notifier);
    ref.watch(employeeJobSessionProvider);
    final session = ref.read(employeeJobSessionProvider.notifier);
    final visibleJobs = state.visibleJobsFor(session);

    return Column(
      children: [
        if (widget.showHeader)
          _JobsHeader(
            onSettings: () => context.push(
              EmployeeTechnicianSettingsRoutes.personalProfile,
            ),
          ),
        _JobsFilterTabs(
          selected: state.filter,
          onChanged: controller.setFilter,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              children: [
                const _FilterFields(),
                const SizedBox(height: 18),
                if (state.isLoading && state.jobs.isEmpty)
                  const AppSkeletonProjectsListBody(
                    includeSearchAndFilters: false,
                    cardCount: 5,
                  )
                else if (state.errorMessage != null)
                  _JobsErrorState(
                    message: state.errorMessage!,
                    onRetry: controller.load,
                  )
                else if (visibleJobs.isEmpty)
                  const _JobsEmptyState()
                else
                  for (final job in visibleJobs) ...[
                    _EmployeeJobCard(job: job, onTap: () => _openDetails(job)),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
          ),
        ),
        if (widget.includeBottomNav) const _EmployeeJobsBottomNav(),
      ],
    );
  }
}

class _JobsHeader extends StatelessWidget {
  const _JobsHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(
            'Jobs',
            style: AppFonts.titleLarge(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 22),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, size: 21),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onSettings,
            icon: const Icon(Icons.settings_rounded, size: 21),
          ),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFD8B48A),
            child: Icon(Icons.person, size: 16, color: AppColors.inkStrong),
          ),
        ],
      ),
    );
  }
}

class _JobsFilterTabs extends StatelessWidget {
  const _JobsFilterTabs({required this.selected, required this.onChanged});

  final EmployeeJobsFilter selected;
  final ValueChanged<EmployeeJobsFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          for (final filter in EmployeeJobsFilter.values)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(filter),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected == filter
                            ? AppColors.inkStrong
                            : AppColors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    filter.label,
                    style: AppFonts.labelSmall(
                      color: selected == filter
                          ? AppColors.inkStrong
                          : AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterFields extends ConsumerWidget {
  const _FilterFields();

  static final _dateLabelFormat = DateFormat('MMM d, yyyy');

  String _dateRangeLabel(EmployeeJobsState state) {
    final start = state.filterDateRangeStart;
    final end = state.filterDateRangeEnd;
    if (start == null || end == null) return 'All dates';
    if (_dateOnly(start) == _dateOnly(end)) {
      return _dateLabelFormat.format(start);
    }
    return '${_dateLabelFormat.format(start)} – ${_dateLabelFormat.format(end)}';
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<void> _pickDateRange(
    BuildContext context,
    WidgetRef ref,
    EmployeeJobsState state,
    EmployeeJobsController controller,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Choose date range',
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.of(context).pop('pick'),
              ),
              ListTile(
                title: Text(
                  'All dates',
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                trailing: !state.hasDateRangeFilter
                    ? const Icon(Icons.check_rounded, color: AppColors.inkStrong)
                    : null,
                onTap: () => Navigator.of(context).pop('all'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!context.mounted || action == null) return;

    if (action == 'all') {
      controller.clearDateRange();
      return;
    }

    final now = DateTime.now();
    final initialStart = state.filterDateRangeStart ?? now;
    final initialEnd = state.filterDateRangeEnd ?? now.add(const Duration(days: 7));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.inkStrong,
                  onSurface: AppColors.inkStrong,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (!context.mounted || picked == null) return;
    controller.setDateRange(start: picked.start, end: picked.end);
  }

  Future<void> _pickOption(
    BuildContext context, {
    required String title,
    required String allLabel,
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  title,
                  style: AppFonts.titleSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              ListTile(
                title: Text(
                  allLabel,
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                trailing: selected == null
                    ? const Icon(Icons.check_rounded, color: AppColors.inkStrong)
                    : null,
                onTap: () => Navigator.of(context).pop<String?>(null),
              ),
              for (final option in options)
                ListTile(
                  title: Text(
                    option,
                    style: AppFonts.bodyMedium(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: selected == option
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.inkStrong,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop<String?>(option),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!context.mounted || picked == selected) return;
    onSelected(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(employeeJobsControllerProvider);
    final controller = ref.read(employeeJobsControllerProvider.notifier);
    final siteLabel = state.selectedSiteName ?? 'All sites';
    final projectLabel = state.selectedProjectName ?? 'All projects';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE RANGE',
          style: AppFonts.labelSmall(
            color: AppColors.mutedLight,
          ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        const SizedBox(height: 7),
        _PillField(
          icon: Icons.calendar_today_rounded,
          label: _dateRangeLabel(state),
          onTap: () => _pickDateRange(context, ref, state, controller),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _FilterSelect(
                title: 'ACTIVE SITE LOCATION',
                value: siteLabel,
                onTap: () {
                  if (state.availableSiteNames.isEmpty) return;
                  _pickOption(
                    context,
                    title: 'Active site location',
                    allLabel: 'All sites',
                    options: state.availableSiteNames,
                    selected: state.selectedSiteName,
                    onSelected: controller.setSiteFilter,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FilterSelect(
                title: 'PROJECT',
                value: projectLabel,
                onTap: () {
                  if (state.availableProjectNames.isEmpty) return;
                  _pickOption(
                    context,
                    title: 'Project',
                    allLabel: 'All projects',
                    options: state.availableProjectNames,
                    selected: state.selectedProjectName,
                    onSelected: controller.setProjectFilter,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PillField extends StatelessWidget {
  const _PillField({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.bodySmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.inkStrong,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSelect extends StatelessWidget {
  const _FilterSelect({
    required this.title,
    required this.value,
    this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.labelSmall(
            color: AppColors.mutedLight,
          ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.4),
        ),
        const SizedBox(height: 7),
        Material(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.inkStrong,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmployeeJobCard extends StatelessWidget {
  const _EmployeeJobCard({required this.job, required this.onTap});

  final EmployeeJobSummary job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = job.status == EmployeeJobStatus.inProgress;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusChip(status: job.status),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Earning',
                    style: AppFonts.labelSmall(
                      color: AppColors.muted,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.earning,
                    style: AppFonts.titleSmall(
                      color: active
                          ? const Color(0xFF00A553)
                          : AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            job.title,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 18, height: 1.08),
          ),
          const SizedBox(height: 12),
          _MetaRow(icon: Icons.location_on_rounded, label: job.location),
          const SizedBox(height: 7),
          _MetaRow(icon: Icons.access_time_rounded, label: job.schedule),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkStrong,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                job.primaryActionLabel,
                style: AppFonts.titleSmall(
                  color: AppColors.white,
                ).copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final EmployeeJobStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      EmployeeJobStatus.inProgress => const Color(0xFF5E4BFF),
      EmployeeJobStatus.upcoming => const Color(0xFFE34D1C),
      EmployeeJobStatus.pending => AppColors.muted,
      EmployeeJobStatus.completed => const Color(0xFF0B8F49),
    };
    final background = switch (status) {
      EmployeeJobStatus.inProgress => const Color(0xFFF1EFFF),
      EmployeeJobStatus.upcoming => const Color(0xFFFFF0E8),
      EmployeeJobStatus.pending => AppColors.surfaceHigh,
      EmployeeJobStatus.completed => const Color(0xFFEAF8EF),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: AppFonts.labelSmall(
          color: color,
        ).copyWith(fontWeight: FontWeight.w900, fontSize: 9),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.muted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.bodySmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _JobsErrorState extends StatelessWidget {
  const _JobsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Text(message, style: AppFonts.bodyMedium(color: AppColors.error)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _JobsEmptyState extends StatelessWidget {
  const _JobsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          'No jobs found.',
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
      ),
    );
  }
}

class _EmployeeJobsBottomNav extends StatelessWidget {
  const _EmployeeJobsBottomNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomNavItem(
            icon: 'assets/images/homes.png',
            label: 'Home',
            onTap: () => TechnicianHomePage.go(context),
          ),
          const _BottomNavItem(
            icon: 'assets/images/jobs.png',
            label: 'Jobs',
            active: true,
          ),
          _BottomNavItem(
            icon: 'assets/images/files.png',
            label: 'Projects',
            onTap: () =>
                TechnicianHomePage.go(context, tab: EmployeeShellTab.projects),
          ),
          EmployeeSiteMenuButton(
            label: 'More',
            sections: EmployeeSiteMenu.buildSections(
              onJobSheet: () => context.push(EmployeeJobSheetPage.path),
              onReport: () => context.push(EmployeeReportsPage.path),
              onSite: () => context.push(EmployeeSitesPage.path),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final String icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.inkStrong : AppColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(icon, color: color, height: 22, width: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppFonts.labelSmall(
                color: color,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
