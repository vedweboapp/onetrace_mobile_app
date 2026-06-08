import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/features/dashboard/data/bill_models.dart';
import 'package:red5/features/dashboard/presentation/views/bill_detail_page.dart';

/// Admin bill order list (UI preview until bill API is available).
class BillsListPage extends StatefulWidget {
  const BillsListPage({super.key});

  @override
  State<BillsListPage> createState() => _BillsListPageState();
}

class _BillsListPageState extends State<BillsListPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();

  static const _searchBg = Color(0xFFF5F5F5);
  static const _divider = Color(0xFFE8E8E8);
  static const _muted = Color(0xFF666666);

  static final _amountFormat = NumberFormat.currency(symbol: r'$');
  static final _dateFormat = DateFormat('MMM d, yyyy');

  static final _allBills = BillMockData.listItems;

  List<BillListItem> _filtered = List.of(_allBills);

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
        _filtered = List.of(_allBills);
        return;
      }
      _filtered = _allBills
          .where(
            (item) =>
                item.id.toLowerCase().contains(query) ||
                item.vendorName.toLowerCase().contains(query),
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

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.bodyLarge(
          color: AppColors.inkStrong,
        ).copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search bill ...',
          hintStyle: AppFonts.bodyLarge(color: const Color(0xFF9CA3AF))
              .copyWith(fontSize: 16, fontWeight: FontWeight.w400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
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

  Widget _vendorAvatar(BillListItem item) {
    final url = item.vendorAvatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: const Color(0xFFE5E7EB),
        backgroundImage: NetworkImage(url),
      );
    }
    final initial = item.vendorName.trim().isNotEmpty
        ? item.vendorName.trim()[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 12,
      backgroundColor: const Color(0xFFE5E7EB),
      child: Text(
        initial,
        style: AppFonts.labelMedium(color: _muted).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _billTile(BillListItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(BillDetailPage.pathFor(item.id)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.id,
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.2,
                          ),
                    ),
                  ),
                  Text(
                    _amountFormat.format(item.amount),
                    style: AppFonts.titleMedium(color: AppColors.inkStrong)
                        .copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.2,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _vendorAvatar(item),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.vendorName,
                      style: AppFonts.bodyMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: AppFonts.bodyMedium(color: _muted).copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    height: 1.25,
                  ),
                  children: [
                    TextSpan(text: _dateFormat.format(item.date)),
                    const TextSpan(text: '  •  '),
                    TextSpan(
                      text: billListStatusLabel(item.status),
                      style: TextStyle(
                        color: billListStatusColor(item.status),
                        fontWeight: FontWeight.w600,
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
                Icons.receipt_long_outlined,
                color: Color(0xFFB0B0B3),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'No bills found' : 'No bills yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search'
                  : 'Create a bill to see it listed here',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _muted).copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white,
      child: Column(
        children: [
          _searchBar(),
          Expanded(
            child: _filtered.isEmpty
                ? _emptyState()
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) => _billTile(_filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
