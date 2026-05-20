import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';

/// One row in the Jobs / project documents list (design: thumb + title + meta + chevron).
class ProjectJobListItem {
  const ProjectJobListItem({
    required this.title,
    required this.subtitle,
    required this.lastUpdatedAt,
    required this.thumbIcon,
    required this.thumbBg,
    this.pinCount,
  });

  final String title;
  /// e.g. "Level 02", "Foundation", "All Levels"
  final String subtitle;
  final DateTime lastUpdatedAt;
  final IconData thumbIcon;
  final Color thumbBg;
  /// When non-null, a pin badge with this count is drawn on the thumbnail.
  final int? pinCount;

  bool matchesQuery(String q) {
    if (q.isEmpty) return true;
    final s = q.toLowerCase();
    return title.toLowerCase().contains(s) ||
        subtitle.toLowerCase().contains(s) ||
        _relativeUpdateLabel(lastUpdatedAt).toLowerCase().contains(s);
  }
}

String _relativeUpdateLabel(DateTime updated) {
  final now = DateTime.now();
  var diff = now.difference(updated);
  if (diff.isNegative) diff = Duration.zero;

  if (diff.inMinutes < 1) return 'Last updated just now';
  if (diff.inHours < 1) {
    final m = diff.inMinutes;
    return 'Last updated $m minute${m == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'Last updated $h hour${h == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return 'Last updated $d day${d == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 14) return 'Last updated 1 week ago';
  final w = (diff.inDays / 7).floor();
  return 'Last updated $w week${w == 1 ? '' : 's'} ago';
}

/// Document-style jobs list for [ProjectDetailsPage] (thumbnail + pin count + lines + chevron).
class ProjectJobsTab extends StatefulWidget {
  const ProjectJobsTab({super.key});

  @override
  State<ProjectJobsTab> createState() => _ProjectJobsTabState();
}

class _ProjectJobsTabState extends State<ProjectJobsTab> {
  final TextEditingController _searchController = TextEditingController();

  /// Demo rows — replace with API when available.
  List<ProjectJobListItem> get _demoJobs {
    final now = DateTime.now();
    return <ProjectJobListItem>[
      ProjectJobListItem(
        title: 'A101 - Floor Plan - Ground',
        subtitle: 'Level 02',
        lastUpdatedAt: now.subtract(const Duration(days: 2)),
        thumbIcon: Icons.architecture_rounded,
        thumbBg: const Color(0xFFE8EDF2),
        pinCount: 10,
      ),
      ProjectJobListItem(
        title: 'S202 - Column Schedule',
        subtitle: 'Foundation',
        lastUpdatedAt: now.subtract(const Duration(days: 3)),
        thumbIcon: Icons.view_column_rounded,
        thumbBg: const Color(0xFFF0EDE8),
      ),
      ProjectJobListItem(
        title: 'E305 - Power Layout',
        subtitle: 'Level 02',
        lastUpdatedAt: now.subtract(const Duration(days: 5)),
        thumbIcon: Icons.electrical_services_rounded,
        thumbBg: const Color(0xFFFFF8E6),
      ),
      ProjectJobListItem(
        title: 'P401 - Sanitary Details',
        subtitle: 'All Levels',
        lastUpdatedAt: now.subtract(const Duration(days: 7)),
        thumbIcon: Icons.water_drop_outlined,
        thumbBg: const Color(0xFFE8F4FC),
      ),
      ProjectJobListItem(
        title: 'A205 - Wall Sections',
        subtitle: 'Level 01',
        lastUpdatedAt: now.subtract(const Duration(days: 8)),
        thumbIcon: Icons.square_foot_rounded,
        thumbBg: const Color(0xFFEDEAF5),
      ),
      ProjectJobListItem(
        title: 'M102 - HVAC Layout',
        subtitle: 'Level 02',
        lastUpdatedAt: now.subtract(const Duration(days: 14)),
        thumbIcon: Icons.air_rounded,
        thumbBg: const Color(0xFFE6F4EF),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProjectJobListItem> get _filtered {
    final q = _searchController.text.trim();
    return _demoJobs.where((e) => e.matchesQuery(q)).toList(growable: false);
  }

  void _onAddJob() {
    context.showTopSnackBar(
      const SnackBar(
        content: Text('Add sheet will connect to your API when available.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onRowTap(ProjectJobListItem job) {
    context.showTopSnackBar(
      SnackBar(
        content: Text('${job.title} — open detail when wired.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

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
                    hintText: 'Search documents...',
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
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No documents match your search',
                          style: AppFonts.bodyMedium(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(0, 4, 0, 88 + bottomPad),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFE5E7EB),
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final job = _filtered[index];
                          return Material(
                            color: AppColors.white,
                            child: InkWell(
                              onTap: () => _onRowTap(job),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _DocumentThumb(
                                      icon: job.thumbIcon,
                                      background: job.thumbBg,
                                      pinCount: job.pinCount,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            job.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.titleMedium(
                                              color: AppColors.inkStrong,
                                            ).copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            job.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.bodyMedium(
                                              color: const Color(0xFF6B7280),
                                            ).copyWith(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _relativeUpdateLabel(
                                              job.lastUpdatedAt,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppFonts.bodySmall(
                                              color: const Color(0xFF9CA3AF),
                                            ).copyWith(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: const Color(0xFFCBD5E1),
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

/// Square thumbnail with optional pin + count (top centre), like the design reference.
class _DocumentThumb extends StatelessWidget {
  const _DocumentThumb({
    required this.icon,
    required this.background,
    this.pinCount,
  });

  final IconData icon;
  final Color background;
  final int? pinCount;

  static const double _size = 58;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: background,
              child: Center(
                child: Icon(
                  icon,
                  size: 28,
                  color: const Color(0xFF4B5563).withValues(alpha: 0.85),
                ),
              ),
            ),
            if (pinCount != null && pinCount! > 0)
              Positioned(
                top: 2,
                left: 0,
                right: 0,
                child: Center(child: _PinCountBadge(count: pinCount!)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PinCountBadge extends StatelessWidget {
  const _PinCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const pinH = 30.0;
    const pinW = 26.0;
    final label = count > 99 ? '99+' : '$count';
    final circleW = label.length >= 3 ? 22.0 : (label.length >= 2 ? 19.0 : 15.0);

    return SizedBox(
      width: pinW,
      height: pinH + 4,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            child: Icon(
              Icons.push_pin_rounded,
              size: pinH,
              color: const Color(0xFF111216),
            ),
          ),
          Positioned(
            top: 2,
            child: Container(
              width: circleW,
              height: circleW,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF111216),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: label.length >= 3
                      ? 8.5
                      : (label.length >= 2 ? 9.5 : 10.5),
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
