import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/features/dashboard/presentation/views/report_summary_page.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/features/dashboard/data/report_models.dart';

/// Admin reports list (UI preview until reports API is available).
class ReportsListPage extends StatefulWidget {
  const ReportsListPage({super.key});

  @override
  State<ReportsListPage> createState() => _ReportsListPageState();
}

class _ReportsListPageState extends State<ReportsListPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();

  static const _searchBg = Color(0xFFF5F5F5);
  static const _muted = Color(0xFF6B7280);
  static const _tagBg = Color(0xFFF3F4F6);
  static const _tagFg = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);

  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _allReports = ReportMockData.listItems;

  List<ReportListItem> _filtered = List.of(_allReports);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(_applySearch);
  }

  void _applySearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.of(_allReports);
        return;
      }
      _filtered = _allReports
          .where(
            (item) =>
                item.title.toLowerCase().contains(query) ||
                item.description.toLowerCase().contains(query) ||
                item.category.label.toLowerCase().contains(query),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onCreateReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create report is coming soon')),
    );
  }

  void _onReportTap(ReportListItem item) {
    context.push(ReportSummaryPage.pathFor(item.id));
  }

  void _onReportMenu(ReportListItem item, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action — ${item.title}')),
    );
  }

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
          hintText: 'Search reports...',
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

  Widget _categoryTag(ReportCategory category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _tagBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.label,
        style: AppFonts.labelMedium(color: _tagFg).copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _reportCard(ReportListItem item) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _onReportTap(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E8EA)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _categoryTag(item.category),
                  const Spacer(),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert,
                      color: Color(0xFF9CA3AF),
                      size: 22,
                    ),
                    onSelected: (value) => _onReportMenu(item, value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'Generate', child: Text('Generate')),
                      PopupMenuItem(value: 'Edit', child: Text('Edit')),
                      PopupMenuItem(value: 'Delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: AppFonts.bodyMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1, color: _divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 6, 14),
                child: Row(
                  children: [
                    Text(
                      'LAST GENERATED',
                      style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF))
                          .copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _dateFormat.format(item.lastGenerated),
                      style: AppFonts.bodyMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1F1F2),
                border: Border.all(color: const Color(0xFFE6E6E7)),
              ),
              child: const Icon(
                Icons.assessment_outlined,
                color: Color(0xFFB0B0B3),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'No reports found' : 'No reports yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search'
                  : 'Create your first report to get started',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: const Color(0xFF8A8A8A))
                  .copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: Column(
        children: [
          if (_filtered.isNotEmpty || _searchController.text.isNotEmpty)
            _searchBar(),
          Expanded(
            child: _filtered.isEmpty
                ? _emptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: _filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) =>
                        _reportCard(_filtered[index]),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'reports_create_fab',
        onPressed: _onCreateReport,
        backgroundColor: const Color(0xFF121212),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
