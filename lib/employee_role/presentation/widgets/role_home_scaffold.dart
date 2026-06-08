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
import 'package:red5/employee_role/data/app_role.dart';
import 'package:red5/employee_role/data/role_session.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_details_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_sheet_page.dart';
import 'package:red5/employee_role/reports/presentation/employee_reports_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_jobs_page.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/employee_site_menu.dart';
import 'package:red5/employee_role/sites/presentation/employee_sites_page.dart';
import 'package:red5/employee_role/projects/presentation/employee_project_details_page.dart';
import 'package:red5/employee_role/projects/presentation/project_map_page.dart';
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

  @override
  Widget build(BuildContext context) {
    final isProjectTab = _selectedTab == _EmployeeHomeTab.project;
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
                          child: _ProjectTabContent(),
                        )
                      else ...[
                        _ExpandableCalendarBand(
                          expanded: _calendarExpanded,
                          onToggleExpanded: () => setState(
                            () => _calendarExpanded = !_calendarExpanded,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: _SectionHeader(
                            title: "Today's Job",
                            actionLabel: 'View all',
                            onAction: () {},
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: _TodayJobCard(role: widget.role),
                        ),
                        const SizedBox(height: 30),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: _SectionHeader(title: 'This Week'),
                        ),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: _WeekTaskTile(
                            dayLabel: 'TUE',
                            dayNumber: '14',
                            title: 'HVAC Inspection',
                            subtitle: '08:30 · Site B',
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: _WeekTaskTile(
                            dayLabel: 'FRI',
                            dayNumber: '17',
                            title: 'Safety Audit',
                            subtitle: '11:00 · Site C',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const EmployeeJobsContent(showHeader: false),
                  const _EmployeeProjectsPage(),
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
  });

  final bool expanded;
  final VoidCallback onToggleExpanded;

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
                    )
                  : _CompactThreeWeekCalendarView(
                      key: const ValueKey('calendar_compact'),
                      anchor: DateTime.now(),
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
  const _CompactThreeWeekCalendarView({super.key, required this.anchor});

  final DateTime anchor;

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
              return Expanded(
                child: Center(
                  child: _CalendarDayChip(
                    date: date,
                    emphasized: inMonth,
                    isToday: isToday,
                    showDot: date.day % 9 == 1 && inMonth,
                    compact: true,
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
  const _FullMonthCalendarView({super.key, required this.month});

  final DateTime month;

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
              return Expanded(
                child: Center(
                  child: _CalendarDayChip(
                    date: date,
                    emphasized: inMonth,
                    isToday: isToday,
                    showDot: date.day % 7 == 0 && inMonth,
                    compact: false,
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

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _CalendarDayChip extends StatelessWidget {
  const _CalendarDayChip({
    required this.date,
    required this.emphasized,
    required this.isToday,
    required this.showDot,
    required this.compact,
  });

  final DateTime date;
  final bool emphasized;
  final bool isToday;
  final bool showDot;
  final bool compact;

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

class _TodayJobCard extends StatelessWidget {
  const _TodayJobCard({required this.role});

  final AppRole role;

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
                'ACTIVE JOB',
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
                  'IN PROGRESS',
                  style: AppFonts.labelSmall(
                    color: const Color(0xFF5E4BFF),
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _jobTitleForRole(role),
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
              Text(
                'Riverside Tower · Floor 7',
                style: AppFonts.bodyMedium(
                  color: AppColors.muted,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                context.push(
                  EmployeeJobDetailsPage.path,
                  extra: <String, Object?>{'jobId': 501},
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkStrong,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Open Job Details',
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

  static String _jobTitleForRole(AppRole role) {
    switch (role) {
      case AppRole.technician:
        return 'Install fire alarm units';
      case AppRole.operative:
        return 'Site operation check';
      case AppRole.sales:
        return 'Client follow-up';
      case AppRole.manager:
        return 'Review team schedule';
    }
  }
}

class _ProjectTabContent extends StatelessWidget {
  const _ProjectTabContent();

  @override
  Widget build(BuildContext context) {
    void openProjectMap(String projectName, int activeSites) {
      context.push(
        EmployeeProjectMapPage.path,
        extra: <String, Object?>{
          'projectName': projectName,
          'activeSites': activeSites,
        },
      );
    }

    void openProjectDetails(String projectName) {
      context.push(
        EmployeeProjectDetailsPage.path,
        extra: <String, Object?>{'projectName': projectName},
      );
    }

    return Column(
      children: [
        const SizedBox(height: 36),
        _SectionHeader(
          title: "Today's Projects",
          actionLabel: 'See Map',
          onAction: () => openProjectMap('Riverside Tower', 3),
        ),
        const SizedBox(height: 12),
        _ProjectCard(
          title: 'Riverside Tower',
          address: '1022 West River St.',
          status: 'IN PROGRESS',
          statusColor: const Color(0xFF5E4BFF),
          statusBg: const Color(0xFFF1EFFF),
          taskCount: 12,
          onTap: () => openProjectDetails('Riverside Tower'),
        ),
        const SizedBox(height: 16),
        _ProjectCard(
          title: 'Skyline Plaza',
          address: '45 Main Avenue',
          status: 'SCHEDULED',
          statusColor: AppColors.muted,
          statusBg: const Color(0xFFF7F7F8),
          taskCount: 8,
          onTap: () => openProjectDetails('Skyline Plaza'),
        ),
        const SizedBox(height: 16),
        _ProjectCard(
          title: 'Green Park Villas',
          address: 'East Lake Rd.',
          status: 'REVIEW',
          statusColor: AppColors.muted,
          statusBg: const Color(0xFFF7F7F8),
          taskCount: 3,
          onTap: () => openProjectDetails('Green Park Villas'),
        ),
      ],
    );
  }
}

enum _EmployeeProjectFilter { all, active, completed }

class _EmployeeProjectsPage extends StatefulWidget {
  const _EmployeeProjectsPage();

  @override
  State<_EmployeeProjectsPage> createState() => _EmployeeProjectsPageState();
}

class _EmployeeProjectsPageState extends State<_EmployeeProjectsPage> {
  _EmployeeProjectFilter _selectedFilter = _EmployeeProjectFilter.all;

  static const _projects = <_EmployeeProjectListItem>[
    _EmployeeProjectListItem(
      title: 'Foundation Reinforcement',
      status: 'ACTIVE',
      dueDate: 'Oct 24, 2023',
      client: 'City Infra Group',
      site: 'West-End Extension Block B',
      activeSites: 3,
      isCompleted: false,
    ),
    _EmployeeProjectListItem(
      title: 'Solar Array Installation',
      status: 'ACTIVE',
      dueDate: 'Nov 12, 2023',
      client: 'GreenEnergy Solutions',
      site: 'North Ridge Substation',
      activeSites: 2,
      isCompleted: false,
    ),
    _EmployeeProjectListItem(
      title: 'HVAC Maintenance',
      status: 'COMPLETED',
      dueDate: 'Oct 02, 2023',
      client: 'Prime Residential',
      site: 'Heritage Oaks Apts',
      activeSites: 1,
      isCompleted: true,
    ),
  ];

  List<_EmployeeProjectListItem> get _visibleProjects {
    return switch (_selectedFilter) {
      _EmployeeProjectFilter.all => _projects,
      _EmployeeProjectFilter.active =>
        _projects
            .where((project) => !project.isCompleted)
            .toList(growable: false),
      _EmployeeProjectFilter.completed =>
        _projects
            .where((project) => project.isCompleted)
            .toList(growable: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      clipBehavior: Clip.none,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      children: [
        const _EmployeeProjectsSearch(),
        const SizedBox(height: 14),
        _EmployeeProjectFilterChips(
          selectedFilter: _selectedFilter,
          onChanged: (filter) => setState(() => _selectedFilter = filter),
        ),
        const SizedBox(height: 18),
        for (final project in _visibleProjects) ...[
          _EmployeeProjectListCard(
            project: project,
            onTap: () {
              context.push(
                EmployeeProjectDetailsPage.path,
                extra: <String, Object?>{'projectName': project.title},
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _EmployeeProjectListItem {
  const _EmployeeProjectListItem({
    required this.title,
    required this.status,
    required this.dueDate,
    required this.client,
    required this.site,
    required this.activeSites,
    required this.isCompleted,
  });

  final String title;
  final String status;
  final String dueDate;
  final String client;
  final String site;
  final int activeSites;
  final bool isCompleted;
}

class _EmployeeProjectsSearch extends StatelessWidget {
  const _EmployeeProjectsSearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.muted, size: 24),
          const SizedBox(width: 10),
          Text(
            'Search projects...',
            style: AppFonts.bodyMedium(
              color: AppColors.mutedLight,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmployeeProjectFilterChips extends StatelessWidget {
  const _EmployeeProjectFilterChips({
    required this.selectedFilter,
    required this.onChanged,
  });

  final _EmployeeProjectFilter selectedFilter;
  final ValueChanged<_EmployeeProjectFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProjectFilterChip(
          label: 'All',
          selected: selectedFilter == _EmployeeProjectFilter.all,
          onTap: () => onChanged(_EmployeeProjectFilter.all),
        ),
        const SizedBox(width: 10),
        _ProjectFilterChip(
          label: 'Active',
          selected: selectedFilter == _EmployeeProjectFilter.active,
          onTap: () => onChanged(_EmployeeProjectFilter.active),
        ),
        const SizedBox(width: 10),
        _ProjectFilterChip(
          label: 'Completed',
          selected: selectedFilter == _EmployeeProjectFilter.completed,
          onTap: () => onChanged(_EmployeeProjectFilter.completed),
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

class _EmployeeProjectListCard extends StatelessWidget {
  const _EmployeeProjectListCard({required this.project, required this.onTap});

  final _EmployeeProjectListItem project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = project.isCompleted
        ? AppColors.muted
        : const Color(0xFF00A86B);
    final statusBg = project.isCompleted
        ? AppColors.surfaceHigh
        : const Color(0xFFE9FFF5);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 13, 17),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: AppFonts.titleLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w900, fontSize: 19),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            project.status,
                            style: AppFonts.labelSmall(color: statusColor)
                                .copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          'Due: ${project.dueDate}',
                          style: AppFonts.bodySmall(
                            color: AppColors.muted,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 17),
                    _EmployeeProjectMetaRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Client:',
                      value: project.client,
                    ),
                    const SizedBox(height: 11),
                    _EmployeeProjectMetaRow(
                      icon: Icons.location_on_rounded,
                      label: 'Site:',
                      value: project.site,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 39,
                height: 39,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.muted,
                  size: 27,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeProjectMetaRow extends StatelessWidget {
  const _EmployeeProjectMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.title,
    required this.address,
    required this.status,
    required this.statusColor,
    required this.statusBg,
    required this.taskCount,
    this.onTap,
  });

  final String title;
  final String address;
  final String status;
  final Color statusColor;
  final Color statusBg;
  final int taskCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppFonts.titleLarge(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w900, fontSize: 19),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 17,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.bodyMedium(
                                  color: AppColors.muted,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: AppFonts.labelSmall(color: statusColor).copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$taskCount Tasks',
                    style: AppFonts.titleSmall(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.inkStrong,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekTaskTile extends StatelessWidget {
  const _WeekTaskTile({
    required this.dayLabel,
    required this.dayNumber,
    required this.title,
    required this.subtitle,
  });

  final String dayLabel;
  final String dayNumber;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  title,
                  style: AppFonts.titleMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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