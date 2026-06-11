import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_user_avatar.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/features/dashboard/data/report_chart_config.dart';
import 'package:red5/features/dashboard/data/report_column_fields.dart';
import 'package:red5/features/dashboard/data/report_field_values.dart';
import 'package:red5/features/dashboard/data/report_models.dart';
import 'package:red5/features/dashboard/data/report_configure_state.dart';
import 'package:red5/features/dashboard/presentation/views/report_configure_page.dart';
import 'package:red5/features/dashboard/presentation/views/report_create_chart_page.dart';
import 'package:red5/features/dashboard/presentation/views/widgets/create_new_report_dialog.dart';
import 'package:red5/features/dashboard/presentation/views/widgets/report_chart_preview.dart';
import 'package:red5/features/dashboard/presentation/views/widgets/report_summary_widgets.dart';

class ReportSummaryRouteExtra {
  const ReportSummaryRouteExtra({
    this.primaryModule,
    this.columnKeys,
  });

  final ReportPrimaryModule? primaryModule;
  final List<String>? columnKeys;
}

/// Report summary table view (UI preview until reports API is available).
class ReportSummaryPage extends StatefulWidget {
  const ReportSummaryPage({
    super.key,
    required this.reportId,
    this.primaryModule,
    this.initialColumnKeys,
  });

  static const pathPrefix = '/reports';
  static const name = 'report-summary';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String reportId;
  final ReportPrimaryModule? primaryModule;
  final List<String>? initialColumnKeys;

  @override
  State<ReportSummaryPage> createState() => _ReportSummaryPageState();
}

class _ReportSummaryPageState extends State<ReportSummaryPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();

  static const _searchBg = Color(0xFFF5F5F5);
  static const _muted = Color(0xFF6B7280);
  static const _headerBg = Color(0xFFF9FAFB);
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);

  late final ReportListItem _report;
  late final List<ReportListCardItem> _allCards;
  late List<String> _selectedColumnKeys;
  List<ReportTableRow> _filtered = const [];
  List<ReportListCardItem> _filteredCards = const [];
  ReportSummaryViewMode _viewMode = ReportSummaryViewMode.list;
  ReportChartConfig? _savedChart;

  List<ReportTableColumn> get _tableColumns =>
      ReportColumnCatalog.tableColumnsFor(_selectedColumnKeys);

  List<ReportFieldDefinition> get _selectedFields =>
      ReportColumnCatalog.resolveSelected(_selectedColumnKeys);

  List<ReportTableRow> get _tableRows =>
      _allCards.map((card) => card.toTableRow(_selectedColumnKeys)).toList();

  String get _pageTitle {
    if (ReportMockData.isNewReport(widget.reportId) &&
        widget.primaryModule != null) {
      return '${widget.primaryModule!.label} Report';
    }
    return _report.title;
  }

  @override
  void initState() {
    super.initState();
    _report = ReportMockData.isNewReport(widget.reportId)
        ? ReportListItem(
            id: ReportMockData.newReportId,
            title: widget.primaryModule != null
                ? '${widget.primaryModule!.label} Report'
                : 'New Report',
            description: 'Custom report preview',
            category: ReportCategory.projects,
            lastGenerated: DateTime.now(),
          )
        : ReportMockData.detailForId(widget.reportId);
    _allCards = ReportMockData.isNewReport(widget.reportId)
        ? ReportMockData.cardsForNewReport()
        : ReportMockData.listCardsFor(widget.reportId);
    _selectedColumnKeys = List.of(
      widget.initialColumnKeys ?? ReportColumnCatalog.defaultSelectedKeys,
    );
    _filtered = List.of(_tableRows);
    _filteredCards = List.of(_allCards);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(_applySearch);
  }

  void _applySearch() {
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.of(_tableRows);
        _filteredCards = List.of(_allCards);
        return;
      }
      _filtered = _tableRows.where((row) => row.matchesQuery(query)).toList();
      _filteredCards = _allCards
          .where((card) => card.matchesQueryWithFields(query, _selectedColumnKeys))
          .toList();
    });
  }

  void _rebuildTableData() {
    _filtered = List.of(_tableRows);
    _applySearch();
  }

  Future<void> _onEditReport() async {
    final result = await context.push<ReportConfigureState?>(
      ReportConfigurePage.pathFor(widget.reportId),
      extra: ReportConfigureRouteExtra(
        primaryModule: widget.primaryModule ?? ReportPrimaryModule.leads,
        initialState: ReportConfigureState(
          visibleColumnKeys: _selectedColumnKeys,
        ),
        replaceOnGenerate: false,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedColumnKeys = result.visibleColumnKeys;
      _rebuildTableData();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _showPlaceholder(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action is coming soon')),
    );
  }

  Future<void> _onChartAction() async {
    final result = await context.push<ReportChartConfig?>(
      ReportCreateChartPage.pathFor(widget.reportId),
      extra: _savedChart,
    );
    if (!mounted || result == null) return;
    setState(() {
      _savedChart = result;
      _viewMode = ReportSummaryViewMode.table;
    });
  }

  ReportChartSeries get _chartSeries =>
      _savedChart?.seriesFor(_allCards) ??
      const ReportChartSeries(labels: [], values: []);

  double get _tableMinWidth {
    var width = 0.0;
    for (final column in _tableColumns) {
      width += column.minWidth ?? 120;
    }
    return width;
  }

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong)
            .copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: _report.category.searchHint,
          hintStyle: AppFonts.bodyLarge(color: const Color(0xFF9CA3AF))
              .copyWith(fontSize: 16, fontWeight: FontWeight.w400),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF9CA3AF),
            size: 22,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => _searchController.clear(),
                  icon: const Icon(
                    Icons.cancel,
                    color: Color(0xFF9CA3AF),
                    size: 18,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _outlinedActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkStrong,
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppColors.white,
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _actionRow() {
    if (_savedChart != null) {
      return Row(
        children: [
          Expanded(
            child: _outlinedActionButton(
              icon: Icons.filter_list_rounded,
              label: 'Filters',
              onPressed: () => _showPlaceholder('Filters'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _outlinedActionButton(
              icon: Icons.file_download_outlined,
              label: 'Export',
              onPressed: () => _showPlaceholder('Export'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _outlinedActionButton(
            icon: Icons.file_download_outlined,
            label: 'Export',
            onPressed: () => _showPlaceholder('Export'),
          ),
        ),
        const SizedBox(width: 10),
        ReportSummaryViewToggle(
          mode: _viewMode,
          onChanged: (mode) => setState(() => _viewMode = mode),
        ),
      ],
    );
  }

  Widget _chartPreviewCard() {
    final chart = _savedChart;
    if (chart == null) return const SizedBox.shrink();

    return ReportChartPreview(
      series: _chartSeries,
      chartType: chart.chartType,
      onChartTypeChanged: (type) {
        setState(() => _savedChart = chart.copyWith(chartType: type));
      },
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    );
  }

  TextStyle get _headerTextStyle => AppFonts.labelMedium(
        color: const Color(0xFF9CA3AF),
      ).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        fontSize: 11,
      );

  Widget _headerCell(ReportTableColumn column) {
    return SizedBox(
      width: column.minWidth,
      child: Text(
        column.label,
        style: _headerTextStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _dataCell(ReportTableColumn column, ReportTableCell? cell) {
    final value = cell;
    if (value == null) {
      return SizedBox(
        width: column.minWidth,
        child: Text('—', style: AppFonts.bodyMedium(color: _muted)),
      );
    }

    switch (column.kind) {
      case ReportTableCellKind.stackedText:
        return SizedBox(
          width: column.minWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.primary,
                style: AppFonts.titleMedium(color: AppColors.inkStrong)
                    .copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.2,
                ),
              ),
              if (value.secondary != null && value.secondary!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  value.secondary!,
                  style: AppFonts.bodyMedium(color: _muted).copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        );
      case ReportTableCellKind.text:
        return SizedBox(
          width: column.minWidth,
          child: Text(
            value.primary,
            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              height: 1.25,
            ),
          ),
        );
      case ReportTableCellKind.avatar:
        return SizedBox(
          width: column.minWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _avatarCell(value),
          ),
        );
    }
  }

  Widget _avatarCell(ReportTableCell cell) {
    return AppUserAvatar(
      name: cell.primary,
      imageUrl: cell.avatarUrl,
      radius: 16,
      foregroundColor: _muted,
      fontSize: 11,
    );
  }

  Widget _tableHeaderRow(double width) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: _headerBg,
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          for (var i = 0; i < _tableColumns.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              flex: _tableColumns[i].flex,
              child: _headerCell(_tableColumns[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tableRow(ReportTableRow row, double width) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _tableColumns.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(
              flex: _tableColumns[i].flex,
              child: _dataCell(
                _tableColumns[i],
                row.cellFor(_tableColumns[i].key),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dataTable({double? height}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = height ?? constraints.maxHeight;
        final width = constraints.maxWidth < _tableMinWidth
            ? _tableMinWidth
            : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: maxH,
            child: Column(
              children: [
                _tableHeaderRow(width),
                Expanded(
                  child: _filtered.isEmpty
                      ? ListView(children: [_emptyResults()])
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) =>
                              _tableRow(_filtered[index], width),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double get _embeddedTableHeight {
    if (_filtered.isEmpty) return 180;
    return 48 + _filtered.length * 68.0;
  }

  Widget _embeddedTableCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: _embeddedTableHeight,
            child: _dataTable(height: _embeddedTableHeight),
          ),
        ),
      ),
    );
  }

  Widget _listView() {
    if (_filteredCards.isEmpty) {
      return ListView(children: [_emptyResults()]);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      itemCount: _filteredCards.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => ReportSummaryListCard(
        item: _filteredCards[index],
        selectedFields: _selectedFields,
      ),
    );
  }

  Widget _summaryContent() {
    if (_savedChart != null) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          _chartPreviewCard(),
          _embeddedTableCard(),
        ],
      );
    }

    if (_viewMode == ReportSummaryViewMode.list) {
      return _listView();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _dataTable(),
        ),
      ),
    );
  }

  Widget _emptyResults() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: Color(0xFFB0B0B3),
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: AppFonts.bodyMedium(color: _muted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.inkStrong,
        ),
        title: Text(
          _pageTitle,
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _onEditReport,
            icon: const Icon(Icons.edit_outlined, size: 22),
            color: AppColors.inkStrong,
            tooltip: 'Configure report',
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _divider),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: _searchBar(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _actionRow(),
          ),
          Expanded(child: _summaryContent()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _onChartAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF121212),
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _savedChart == null ? 'Create Chart' : 'Update Chart',
                    style: AppFonts.titleMedium(color: AppColors.white).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
