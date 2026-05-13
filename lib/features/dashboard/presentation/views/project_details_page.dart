import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/app_under_development_view.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_page.dart';
import 'package:red5/features/dashboard/presentation/views/upload_drawing_page.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

String? _absoluteDrawingFileUrl(String drawingFileFromApi) {
  final raw = drawingFileFromApi.trim();
  if (raw.isEmpty) return null;
  final parsed = Uri.tryParse(raw);
  if (parsed != null &&
      parsed.hasScheme &&
      (parsed.scheme == 'http' || parsed.scheme == 'https')) {
    return raw;
  }
  return Uri.parse(
    AppApiUrls.baseUrl,
  ).resolve(raw.startsWith('/') ? raw : '/$raw').toString();
}

class ProjectDetailsPage extends ConsumerStatefulWidget {
  const ProjectDetailsPage({super.key, required this.project});

  static const pathPrefix = '/project-details';
  static const name = 'project-details';

  final QuoteSummary project;

  static String pathFor(String projectId) => '$pathPrefix/$projectId';

  @override
  ConsumerState<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends ConsumerState<ProjectDetailsPage> {
  bool _expandedDescription = false;
  final TextEditingController _drawingSearchController =
      TextEditingController();
  final List<_DrawingItem> _drawings = <_DrawingItem>[];
  bool _isLoadingDrawings = false;
  String? _drawingsError;

  @override
  void initState() {
    super.initState();
    _loadProjectDrawings();
  }

  @override
  void dispose() {
    _drawingSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectDrawings() async {
    final projectId = widget.project.id.trim();
    if (projectId.isEmpty) return;
    setState(() {
      _isLoadingDrawings = true;
      _drawingsError = null;
    });
    try {
      final api = ref.read(quoteProjectApiClientProvider);
      final levels = await api.fetchProjectLevels(projectId: projectId);
      if (!mounted) return;
      final next = levels.asMap().entries.map((entry) {
        final index = entry.key;
        final level = entry.value;
        final title = level.name.trim().isEmpty
            ? 'Drawing ${index + 1}'
            : level.name.trim();
        final meta =
            'Level • ${level.name.trim().isEmpty ? 'N/A' : level.name.trim()}';
        final code = level.id.trim().isEmpty
            ? 'L${(index + 1).toString().padLeft(3, '0')}'
            : level.id.trim();
        return _DrawingItem(
          code: code,
          title: title,
          meta: meta,
          updated: 'Synced from API',
          accent: _accentForDrawing('$title|$code'),
          localFilePath: null,
          remoteDrawingUrl: _absoluteDrawingFileUrl(level.drawingFile),
          levelName: level.name.trim().isEmpty ? null : level.name.trim(),
          projectId: projectId,
          levelId: level.id.trim().isEmpty ? null : level.id.trim(),
        );
      }).toList();
      setState(() {
        _drawings
          ..clear()
          ..addAll(next);
        _isLoadingDrawings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingDrawings = false;
        _drawingsError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load project drawings',
        );
      });
    }
  }

  String _displayDate(String? isoDate) {
    if (isoDate == null || isoDate.trim().isEmpty) return '--';
    final parsed = DateTime.tryParse(isoDate.trim());
    if (parsed == null) return isoDate;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AppFonts.headlineSmall(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w700, fontSize: 24),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppFonts.labelMedium(
        color: AppColors.muted,
      ).copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w700),
    );
  }

  Widget _overviewTab() {
    final description = (widget.project.description ?? '').trim().isEmpty
        ? 'Project details will appear here once description data is available.'
        : widget.project.description!.trim();
    final start = _displayDate(widget.project.startDate);
    final end = _displayDate(widget.project.endDate);

    final showReadMore = description.length > 140;
    final descText = _expandedDescription || !showReadMore
        ? description
        : '${description.substring(0, 140)}...';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Basic Info'),
          const SizedBox(height: 14),
          _label('PROJECT NAME'),
          const SizedBox(height: 4),
          Text(
            widget.project.quoteName,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          const SizedBox(height: 18),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 18),
          _sectionTitle('Description'),
          const SizedBox(height: 10),
          Text(
            descText,
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(height: 1.5, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          if (showReadMore)
            TextButton(
              onPressed: () =>
                  setState(() => _expandedDescription = !_expandedDescription),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkStrong,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _expandedDescription ? 'Read less' : 'Read more',
                style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          const SizedBox(height: 18),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 18),
          _sectionTitle('Timeline'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('START DATE'),
                    const SizedBox(height: 4),
                    Text(
                      start,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 17),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('END DATE'),
                    const SizedBox(height: 4),
                    Text(
                      end,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 17),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9E9EA)),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFECECED),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: AppColors.border,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Additional features coming',
                  style: AppFonts.titleMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'More insights and analytics for this project are currently under development.',
                  textAlign: TextAlign.center,
                  style: AppFonts.bodySmall(
                    color: AppColors.muted,
                  ).copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderTab(String title) {
    return const AppUnderDevelopmentView(
      title: 'Working on this page',
      message: 'This section is under development.\nCheck back soon for updates.',
    );
  }

  List<_DrawingItem> get _filteredDrawings {
    final q = _drawingSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _drawings;
    return _drawings
        .where(
          (d) =>
              d.code.toLowerCase().contains(q) ||
              d.title.toLowerCase().contains(q) ||
              d.meta.toLowerCase().contains(q),
        )
        .toList();
  }

  Color _accentForDrawing(String seed) {
    const palette = <Color>[
      Color(0xFFF2F2F3),
      Color(0xFFDCE9F1),
      Color(0xFFECECEC),
      Color(0xFFF7F7F8),
      Color(0xFF24272B),
      Color(0xFF1E7DD8),
    ];
    return palette[seed.hashCode.abs() % palette.length];
  }

  Future<void> _openUploadDrawing() async {
    final result = await context.push<dynamic>(
      UploadDrawingPage.path,
      extra: <String, dynamic>{'projectId': widget.project.id},
    );
    if (!mounted) return;
    if (result is! Map) return;

    final map = Map<String, dynamic>.from(result);
    final uploadCount = DrawingCanvasArgs.uploadCountFromResult(map);

    if (uploadCount > 0 && _drawingSearchController.text.trim().isNotEmpty) {
      // Clear any active search so newly uploaded drawings are visible.
      setState(() => _drawingSearchController.clear());
    }

    // Always refresh from API so every uploaded level appears in the list.
    await _loadProjectDrawings();
    if (!mounted) return;

    if (uploadCount > 1) {
      return;
    }

    final args = DrawingCanvasArgs.fromUploadResult(
      map,
      projectName: widget.project.quoteName,
      projectId: widget.project.id,
    );
    if (args.title.trim().isEmpty || (args.filePath ?? '').trim().isEmpty) {
      return;
    }
    await DrawingCanvasPage.push(context, args);
  }

  Future<void> _openDrawingCanvas(_DrawingItem item) async {
    final result = await DrawingCanvasPage.push(
      context,
      DrawingCanvasArgs(
        title: item.title,
        filePath: item.localFilePath,
        remoteDrawingUrl: item.remoteDrawingUrl,
        levelName: item.levelName,
        projectName: widget.project.quoteName,
        projectId: (item.projectId ?? widget.project.id).trim(),
        levelId: item.levelId,
      ),
    );
    if (!mounted) return;
    if (result == true) {
      await _loadProjectDrawings();
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Selection and pins saved successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _drawingTab() {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Project Drawings',
                    style: AppFonts.headlineSmall(
                      color: AppColors.inkStrong,
                    ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _openUploadDrawing,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE9E9EA),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppColors.inkStrong,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: AppTextField(
                controller: _drawingSearchController,
                hintText: 'Search drawings...',
                prefixIcon: Icons.search,
                onChanged: (_) => setState(() {}),
                fillColor: const Color(0xFFEFEFF0),
                borderRadius: 10,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadProjectDrawings,
                child: _isLoadingDrawings
                    ? Center(
                        child: const AppSkeletonScreenBody(
                          style: AppSkeletonScreenBodyStyle.listRows,
                          listRowCount: 10,
                        ),
                      )
                    : _drawingsError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            _drawingsError!,
                            textAlign: TextAlign.center,
                            style: AppFonts.bodyMedium(color: AppColors.muted),
                          ),
                        ),
                      )
                    : _filteredDrawings.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          Center(
                            child: Text(
                              'No levels found for this project',
                              style: AppFonts.bodyMedium(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: _filteredDrawings.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: Color(0xFFE3E3E4)),
                        itemBuilder: (context, index) {
                          final item = _filteredDrawings[index];
                          final darkTile = item.accent.computeLuminance() < 0.2;
                          return InkWell(
                            onTap: () async => _openDrawingCanvas(item),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: item.accent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFE2E2E4),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        item.code.substring(0, 1),
                                        style: AppFonts.titleMedium(
                                          color: darkTile
                                              ? AppColors.white
                                              : AppColors.muted,
                                        ).copyWith(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item.code} - ${item.title}',
                                          style:
                                              AppFonts.titleMedium(
                                                color: AppColors.inkStrong,
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.meta,
                                          style:
                                              AppFonts.bodyMedium(
                                                color: AppColors.muted,
                                              ).copyWith(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.updated,
                                          style:
                                              AppFonts.bodySmall(
                                                color: AppColors.mutedLight,
                                              ).copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.border,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'drawing_add_fab',
            backgroundColor: const Color(0xFF111111),
            foregroundColor: AppColors.white,
            onPressed: _openUploadDrawing,
            child: const Icon(Icons.add, size: 30),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.project.quoteName;

    return DefaultTabController(
      length: 9,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F7F8),
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
          ),
          titleSpacing: 0,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.headlineSmall(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 36),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.muted,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_displayDate(widget.project.startDate)} – ${_displayDate(widget.project.endDate)}',
                        style: AppFonts.bodySmall(
                          color: AppColors.muted,
                        ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.inkStrong,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.inkStrong,
              indicatorWeight: 2.5,
              labelStyle: AppFonts.titleSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: AppFonts.titleSmall(
                color: AppColors.muted,
              ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Jobs'),
                Tab(text: 'Job Sheet'),
                Tab(text: 'Approval'),
                Tab(text: 'Drawing'),
                Tab(text: 'Location'),
                Tab(text: 'Specification'),
                Tab(text: 'Documents'),
                Tab(text: 'Docs & Files'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _overviewTab(),
                  _placeholderTab('Jobs'),
                  _placeholderTab('Job Sheet'),
                  _placeholderTab('Approval'),
                  _drawingTab(),
                  _placeholderTab('Location'),
                  _placeholderTab('Specification'),
                  _placeholderTab('Documents'),
                  _placeholderTab('Docs & Files'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingItem {
  const _DrawingItem({
    required this.code,
    required this.title,
    required this.meta,
    required this.updated,
    required this.accent,
    this.localFilePath,
    this.remoteDrawingUrl,
    this.levelName,
    this.projectId,
    this.levelId,
  });

  final String code;
  final String title;
  final String meta;
  final String updated;
  final Color accent;
  final String? localFilePath;
  final String? remoteDrawingUrl;
  final String? levelName;
  final String? projectId;
  final String? levelId;
}
