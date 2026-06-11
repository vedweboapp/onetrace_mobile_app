import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/auth/auth_redirect_notifier.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/employee_role/data/app_role.dart';
import 'package:red5/employee_role/data/role_session.dart';
import 'package:red5/employee_role/jobs/application/employee_jobs_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/application/employee_job_navigation.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_sheet_page.dart';
import 'package:red5/employee_role/reports/presentation/employee_reports_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_jobs_page.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/employee_site_menu.dart';
import 'package:red5/employee_role/sites/presentation/employee_sites_page.dart';
import 'package:red5/employee_role/projects/presentation/widgets/employee_projects_list_content.dart';
import 'package:red5/features/login/presentation/views/login_page.dart';

enum _EmployeeHomeTab { calendar, project }

enum _EmployeeNavPage { home, jobs, projects }

class RoleHomeScaffold extends ConsumerStatefulWidget {
  const RoleHomeScaffold({
    super.key,
    required this.role,
    required this.primaryActions,
  });

  final AppRole role;
  final List<RoleActionItem> primaryActions;

  @override
  ConsumerState<RoleHomeScaffold> createState() => _RoleHomeScaffoldState();
}

class _RoleHomeScaffoldState extends ConsumerState<RoleHomeScaffold> {
  final PageController _pageController = PageController();
  _EmployeeHomeTab _selectedTab = _EmployeeHomeTab.calendar;
  _EmployeeNavPage _selectedPage = _EmployeeNavPage.home;
  bool _calendarExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(employeeJobsControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(localStorageProvider);
    await storage.remove(LocalStorageKeys.authAccessToken);
    await storage.remove(LocalStorageKeys.authRefreshToken);
    await storage.remove(LocalStorageKeys.authUserId);
    await RoleSession.clearRole(storage);
    sl<AuthRedirectNotifier>().notifyAuthChanged();
    if (context.mounted) context.go(LoginPage.path);
  }

  void _selectPage(_EmployeeNavPage page) {
    setState(() => _selectedPage = page);
    _pageController.animateToPage(
      page.index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String _titleForPage(_EmployeeNavPage page) {
    return switch (page) {
      _EmployeeNavPage.home => 'Home',
      _EmployeeNavPage.jobs => 'Jobs',
      _EmployeeNavPage.projects => 'Projects',
    };
  }

  static String _jobsSectionTitle(DateTime date) {
    final today = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    if (day == todayDay) return "Today's Jobs";
    return DateFormat('EEEE, MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isProjectTab = _selectedTab == _EmployeeHomeTab.project;
    final jobsState = ref.watch(employeeJobsControllerProvider);
    final jobsController = ref.read(employeeJobsControllerProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _EmployeeSiteAppBar(
              title: _titleForPage(_selectedPage),
              onLogout: () => _logout(context, ref),
              onOpenSettings: () => context.push(
                EmployeeTechnicianSettingsRoutes.personalProfile,
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(
                    () => _selectedPage = _EmployeeNavPage.values[index],
                  );
                },
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _EmployeeHomeWelcomeHeader(role: widget.role),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _EmployeeCalendarSwitch(
                          selectedTab: _selectedTab,
                          onChanged: (tab) =>
                              setState(() => _selectedTab = tab),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (isProjectTab)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: EmployeeProjectsHomePreview(),
                        )
                      else ...[
                        _ExpandableCalendarBand(
                          expanded: _calendarExpanded,
                          onToggleExpanded: () => setState(
                            () => _calendarExpanded = !_calendarExpanded,
                          ),
                          datesWithJobs: jobsState.jobDates,
                          selectedDate: jobsState.effectiveSelectedDate,
                          onDateSelected: jobsController.selectCalendarDate,
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: _SectionHeader(
                            title: _jobsSectionTitle(jobsState.effectiveSelectedDate),
                            actionLabel: 'View all',
                            onAction: () => _selectPage(_EmployeeNavPage.jobs),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: _SelectedDateJobsPanel(
                            isLoading: jobsState.isLoading,
                            errorMessage: jobsState.errorMessage,
                            jobs: jobsState.selectedDateJobs,
                            onRetry: jobsController.load,
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: _SectionHeader(title: 'This Week'),
                        ),
                        const SizedBox(height: 12),
                        if (jobsState.weekJobs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              'No jobs scheduled this week.',
                              style: AppFonts.bodyMedium(color: AppColors.muted),
                            ),
                          )
                        else
                          for (final job in jobsState.weekJobs) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: _WeekTaskTile(job: job),
                            ),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ],
                  ),
                  const EmployeeJobsContent(showHeader: false),
                  const EmployeeProjectsListContent(),
                ],
              ),
            ),
            _EmployeeBottomNav(
              selectedPage: _selectedPage,
              onSelected: _selectPage,
            ),
          ],
        ),
      ),
    );
  }
}

class RoleActionItem {
  const RoleActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
}

/// Shared top bar for Home / Jobs / Projects bottom tabs (title only changes).
class _EmployeeSiteAppBar extends StatelessWidget {
  const _EmployeeSiteAppBar({
    required this.title,
    required this.onLogout,
    required this.onOpenSettings,
  });

  final String title;
  final VoidCallback onLogout;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
      child: Row(
        children: [
          Text(
            title,
            style: AppFonts.headlineSmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 24),
          ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppColors.inkStrong,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_rounded),
            color: AppColors.inkStrong,
          ),
          PopupMenuButton<String>(
            tooltip: 'Profile',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFD8B48A),
              child: Icon(Icons.person, size: 20, color: AppColors.inkStrong),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeHomeWelcomeHeader extends StatelessWidget {
  const _EmployeeHomeWelcomeHeader({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.inkStrong,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(
                  _initialsForRole(role),
                  style: AppFonts.titleMedium(
                    color: AppColors.white,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: AppFonts.bodySmall(
                    color: AppColors.mutedLight,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _nameForRole(role),
                  style: AppFonts.headlineSmall(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900, fontSize: 23),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.timer_outlined, size: 17, color: AppColors.muted),
            const SizedBox(width: 4),
            Text(
              '10:03:02',
              style: AppFonts.bodyMedium(
                color: AppColors.muted,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  static String _initialsForRole(AppRole role) {
    switch (role) {
      case AppRole.technician:
        return 'AK';
      case AppRole.operative:
        return 'OP';
      case AppRole.sales:
        return 'SA';
      case AppRole.manager:
        return 'MG';
    }
  }

  static String _nameForRole(AppRole role) {
    switch (role) {
      case AppRole.technician:
        return 'Alex Khan';
      case AppRole.operative:
        return 'Operative';
      case AppRole.sales:
        return 'Sales User';
      case AppRole.manager:
        return 'Manager';
    }
  }
}

class _EmployeeCalendarSwitch extends StatelessWidget {
  const _EmployeeCalendarSwitch({
    required this.selectedTab,
    required this.onChanged,
  });

  final _EmployeeHomeTab selectedTab;
  final ValueChanged<_EmployeeHomeTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchSegment(
              label: 'Calendar',
              selected: selectedTab == _EmployeeHomeTab.calendar,
              onTap: () => onChanged(_EmployeeHomeTab.calendar),
            ),
          ),
          Expanded(
            child: _SwitchSegment(
              label: 'Project',
              selected: selectedTab == _EmployeeHomeTab.project,
              onTap: () => onChanged(_EmployeeHomeTab.project),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchSegment extends StatelessWidget {
  const _SwitchSegment({
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: double.infinity,
        decoration: BoxDecoration(
          color: selected ? AppColors.inkStrong : AppColors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style:
                AppFonts.titleSmall(
                  color: selected ? AppColors.white : AppColors.muted,
                ).copyWith(
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

/// Edge-to-edge calendar on the home surface; expands to full month.
class _ExpandableCalendarBand extends StatelessWidget {
  const _ExpandableCalendarBand({
    required this.expanded,
    required this.onToggleExpanded,
    required this.datesWithJobs,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;
  final Set<DateTime> datesWithJobs;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  static const double _pagePadding = 18;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderLight),
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _pagePadding,
          10,
          _pagePadding,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CalendarBandHeader(
              expanded: expanded,
              onToggleExpanded: onToggleExpanded,
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: expanded
                  ? _FullMonthCalendarView(
                      key: const ValueKey('calendar_full'),
                      month: DateTime.now(),
                      datesWithJobs: datesWithJobs,
                      selectedDate: selectedDate,
                      onDateSelected: onDateSelected,
                    )
                  : _CompactThreeWeekCalendarView(
                      key: const ValueKey('calendar_compact'),
                      anchor: DateTime.now(),
                      datesWithJobs: datesWithJobs,
                      selectedDate: selectedDate,
                      onDateSelected: onDateSelected,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarBandHeader extends StatelessWidget {
  const _CalendarBandHeader({
    required this.expanded,
    required this.onToggleExpanded,
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthLabel = DateFormat.yMMMM().format(now);
    return Row(
      children: [
        if (expanded)
          Text(
            monthLabel,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 17),
          )
        else
          Text(
            'Calendar',
            style: AppFonts.labelLarge(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.6),
          ),
        const Spacer(),
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(10),
            canRequestFocus: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expanded ? 'Collapse' : 'Expand',
                    style: AppFonts.labelLarge(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 22,
                    color: AppColors.inkStrong,
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

class _WeekdayLabelsRow extends StatelessWidget {
  const _WeekdayLabelsRow({this.compact = false});

  final bool compact;

  static const List<String> _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final h = compact ? 26.0 : 28.0;
    return Row(
      children: _labels
          .map(
            (label) => Expanded(
              child: SizedBox(
                height: h,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppFonts.labelLarge(color: AppColors.muted).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 11 : 12,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Three weeks around the current week (collapsed).
class _CompactThreeWeekCalendarView extends StatelessWidget {
  const _CompactThreeWeekCalendarView({
    super.key,
    required this.anchor,
    required this.datesWithJobs,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime anchor;
  final Set<DateTime> datesWithJobs;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  static List<List<DateTime>> _weeksAround(DateTime now) {
    final local = DateTime(now.year, now.month, now.day);
    final daysFromSunday = local.weekday % 7;
    final sunday = local.subtract(Duration(days: daysFromSunday));
    return List.generate(3, (w) {
      return List.generate(7, (d) => sunday.add(Duration(days: w * 7 + d)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _weeksAround(anchor);
    final today = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _WeekdayLabelsRow(compact: true),
        const SizedBox(height: 4),
        for (var r = 0; r < weeks.length; r++) ...[
          Row(
            children: List.generate(7, (i) {
              final date = weeks[r][i];
              final isToday = _isSameDate(date, today);
              final inMonth =
                  date.month == today.month && date.year == today.year;
              final dateOnly = _dateOnly(date);
              return Expanded(
                child: Center(
                  child: _CalendarDayChip(
                    date: date,
                    emphasized: inMonth,
                    isToday: isToday,
                    isSelected: _isSameDate(date, selectedDate),
                    showDot: datesWithJobs.contains(dateOnly),
                    compact: true,
                    onTap: () => onDateSelected(date),
                  ),
                ),
              );
            }),
          ),
          if (r < weeks.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

/// Full month grid (expanded).
class _FullMonthCalendarView extends StatelessWidget {
  const _FullMonthCalendarView({
    super.key,
    required this.month,
    required this.datesWithJobs,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime month;
  final Set<DateTime> datesWithJobs;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  static List<List<DateTime?>> _monthGrid(DateTime forMonth) {
    final first = DateTime(forMonth.year, forMonth.month, 1);
    final lastDay = DateTime(forMonth.year, forMonth.month + 1, 0).day;
    final leading = first.weekday % 7;
    final cells = <DateTime?>[];
    for (var i = 0; i < leading; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= lastDay; d++) {
      cells.add(DateTime(forMonth.year, forMonth.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final weeks = <List<DateTime?>>[];
    for (var i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, i + 7));
    }
    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _monthGrid(month);
    final today = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _WeekdayLabelsRow(compact: false),
        const SizedBox(height: 6),
        for (var r = 0; r < weeks.length; r++) ...[
          Row(
            children: List.generate(7, (i) {
              final date = weeks[r][i];
              if (date == null) {
                return const Expanded(child: SizedBox(height: 40));
              }
              final isToday = _isSameDate(date, today);
              final inMonth =
                  date.month == month.month && date.year == month.year;
              final dateOnly = _dateOnly(date);
              return Expanded(
                child: Center(
                  child: _CalendarDayChip(
                    date: date,
                    emphasized: inMonth,
                    isToday: isToday,
                    isSelected: _isSameDate(date, selectedDate),
                    showDot: datesWithJobs.contains(dateOnly),
                    compact: false,
                    onTap: () => onDateSelected(date),
                  ),
                ),
              );
            }),
          ),
          if (r < weeks.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CalendarDayChip extends StatelessWidget {
  const _CalendarDayChip({
    required this.date,
    required this.emphasized,
    required this.isToday,
    required this.isSelected,
    required this.showDot,
    required this.compact,
    this.onTap,
  });

  final DateTime date;
  final bool emphasized;
  final bool isToday;
  final bool isSelected;
  final bool showDot;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final day = date.day;
    final textColor = isToday
        ? AppColors.white
        : (emphasized ? AppColors.inkStrong : const Color(0xFFB8BFC7));
    final decoration = isToday
        ? BoxDecoration(
            color: AppColors.inkStrong,
            borderRadius: BorderRadius.circular(10),
          )
        : isSelected
        ? BoxDecoration(
            color: const Color(0xFFF1EFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF5E4BFF), width: 1.4),
          )
        : (!emphasized
              ? null
              : _isPastNonToday(date)
              ? BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowCard,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                )
              : null);

    final outerH = compact ? 40.0 : 40.0;
    final inner = compact ? 32.0 : 34.0;

    return SizedBox(
      width: 36,
      height: outerH,
      child: Center(
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: inner,
              height: inner,
              decoration: decoration,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$day',
                    style: AppFonts.bodyMedium(color: textColor).copyWith(
                      fontWeight: (isToday || _isPastNonToday(date)) && emphasized
                          ? FontWeight.w800
                          : FontWeight.w500,
                      height: 1,
                      fontSize: compact ? 13 : 14,
                    ),
                  ),
                  if (showDot && !isToday)
                    Positioned(
                      bottom: compact ? 4 : 5,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF5E4BFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static bool _isPastNonToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return d.isBefore(today) && d != today;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction ?? () {},
            child: Text(
              actionLabel!,
              style: AppFonts.labelLarge(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _SelectedDateJobsPanel extends StatelessWidget {
  const _SelectedDateJobsPanel({
    required this.isLoading,
    required this.errorMessage,
    required this.jobs,
    required this.onRetry,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<EmployeeJobSummary> jobs;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeletonProjectCard(),
          SizedBox(height: 12),
          AppSkeletonProjectCard(),
        ],
      );
    }
    if (errorMessage != null) {
      return Column(
        children: [
          Text(
            errorMessage!,
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    }
    if (jobs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          'No jobs assigned for this date.',
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < jobs.length; i++) ...[
          _HomeJobCard(job: jobs[i]),
          if (i < jobs.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HomeJobCard extends StatelessWidget {
  const _HomeJobCard({required this.job});

  final EmployeeJobSummary job;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                job.status.label,
                style: AppFonts.labelMedium(
                  color: AppColors.muted,
                ).copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.6),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  job.schedule,
                  style: AppFonts.labelSmall(
                    color: const Color(0xFF5E4BFF),
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            job.title,
            style: AppFonts.titleLarge(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 19),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 18,
                color: AppColors.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  job.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.bodyMedium(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                openEmployeeJob(context, job: job);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkStrong,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
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

class _WeekTaskTile extends StatelessWidget {
  const _WeekTaskTile({required this.job});

  final EmployeeJobSummary job;

  @override
  Widget build(BuildContext context) {
    final start = job.startDate?.toLocal();
    final dayLabel = start == null
        ? '—'
        : DateFormat('EEE').format(start).toUpperCase();
    final dayNumber = start == null ? '—' : '${start.day}';

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => openEmployeeJob(context, job: job),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayLabel,
                      style: AppFonts.labelSmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      dayNumber,
                      style: AppFonts.titleSmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${job.schedule} · ${job.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodySmall(
                        color: AppColors.muted,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.border),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeBottomNav extends StatelessWidget {
  const _EmployeeBottomNav({
    required this.selectedPage,
    required this.onSelected,
  });

  final _EmployeeNavPage selectedPage;
  final ValueChanged<_EmployeeNavPage> onSelected;

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
            icon: "assets/images/homes.png",
            label: 'Home',
            active: selectedPage == _EmployeeNavPage.home,
            onTap: () => onSelected(_EmployeeNavPage.home),
          ),
          _BottomNavItem(
            icon: "assets/images/jobs.png",
            label: 'Jobs',
            active: selectedPage == _EmployeeNavPage.jobs,
            onTap: () => onSelected(_EmployeeNavPage.jobs),
          ),
          _BottomNavItem(
            icon: "assets/images/files.png",
            label: 'Projects',
            active: selectedPage == _EmployeeNavPage.projects,
            onTap: () => onSelected(_EmployeeNavPage.projects),
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
