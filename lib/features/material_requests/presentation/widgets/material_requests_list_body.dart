import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';
import 'package:red5/features/material_requests/presentation/views/material_request_detail_page.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_request_widgets.dart';

/// Searchable material requests list used by admin dashboard and operative site.
class MaterialRequestsListBody extends StatefulWidget {
  const MaterialRequestsListBody({
    super.key,
    this.alwaysShowSearch = false,
    this.listBottomPadding = 88,
    this.searchHorizontalPadding = 16,
  });

  final bool alwaysShowSearch;
  final double listBottomPadding;
  final double searchHorizontalPadding;

  @override
  State<MaterialRequestsListBody> createState() =>
      _MaterialRequestsListBodyState();
}

class _MaterialRequestsListBodyState extends State<MaterialRequestsListBody> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();

  static const _searchBg = Color(0xFFF5F5F5);
  static const _muted = Color(0xFF6B7280);
  static const _border = Color(0xFFE8E8EA);

  static final _allItems = MaterialRequestMockData.listItems;
  List<MaterialRequestListItem> _filtered = List.of(_allItems);

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
    final query = _searchController.text.trim();
    setState(() {
      _filtered = query.isEmpty
          ? List.of(_allItems)
          : _allItems.where((item) => item.matchesQuery(query)).toList();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  bool get _showSearch =>
      widget.alwaysShowSearch ||
      _filtered.isNotEmpty ||
      _searchController.text.isNotEmpty;

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: EdgeInsets.fromLTRB(
        widget.searchHorizontalPadding,
        8,
        widget.searchHorizontalPadding,
        12,
      ),
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong)
            .copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search requests...',
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

  Widget _requestCard(MaterialRequestListItem item) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push(MaterialRequestDetailPage.pathFor(item.id)),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.requestCode,
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  MaterialRequestStatusBadge(status: item.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.jobCode,
                style: AppFonts.bodyMedium(color: _muted).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: _muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.requesterName,
                      style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.inventory_2_outlined, size: 16, color: _muted),
                  const SizedBox(width: 4),
                  Text(
                    '${item.itemCount} Items',
                    style: AppFonts.bodyMedium(color: _muted).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
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
            const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFFB0B0B3),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No requests found' : 'No material requests yet',
              style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Create your first material request',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_showSearch) _searchBar(),
        Expanded(
          child: _filtered.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    widget.searchHorizontalPadding,
                    0,
                    widget.searchHorizontalPadding,
                    widget.listBottomPadding,
                  ),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _requestCard(_filtered[index]),
                ),
        ),
      ],
    );
  }
}
