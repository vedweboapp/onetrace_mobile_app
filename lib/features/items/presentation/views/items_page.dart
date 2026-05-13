import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/items/data/item_models.dart';
import 'package:red5/features/items/data/items_api_client.dart';
import 'package:red5/features/items/presentation/views/add_item_page.dart';
import 'package:red5/features/items/presentation/views/item_detail_page.dart';

/// Non-composite **Items** list for the dashboard body (`GET /item/?is_composite=false`).
///
/// Shown inside [DashboardPage] [IndexedStack] — no separate route or app bar.
class ItemsPage extends ConsumerStatefulWidget {
  const ItemsPage({super.key});

  @override
  ConsumerState<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends ConsumerState<ItemsPage> {
  final _searchController = TextEditingController();
  final List<ItemModel> _items = <ItemModel>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  static const _inkMuted = Color(0xFF8B8B8B);
  static const _searchBg = Color(0xFFEFEEF0);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchItems(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ItemModel> _filtered(List<ItemModel> all) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.sku.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _fetchItems({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }
    try {
      final api = ref.read(itemsApiClientProvider);
      final nextPage = reset ? 1 : (_page + 1);
      final result = await api.fetchItemsPage(
        page: nextPage,
        pageSize: ItemsApiClient.defaultPageSize,
        isComposite: false,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }
        _page = result.currentPage;
        _totalPages = result.totalPages;
        _isLoading = false;
        _isLoadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load items',
        );
      });
    }
  }

  String _fmtQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }

  String _fmtMoney(double v) => v.toStringAsFixed(2);

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong).copyWith(
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8A8A8A), size: 20),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => _searchController.clear(),
                  icon: const Icon(Icons.cancel, color: Color(0xFF8A8A8A), size: 18),
                )
              : null,
        ),
      ),
    );
  }

  Widget _itemRow(ItemModel item) {
    final skuLine = item.sku.isEmpty ? 'SKU: —' : 'SKU: ${item.sku}';
    final detail =
        'Qty: ${_fmtQty(item.quantity)} · Cost: ${_fmtMoney(item.costPrice)} · Sell: ${_fmtMoney(item.sellPrice)}';
    final id = item.id.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: id.isEmpty
            ? null
            : () => context.push(ItemDetailPage.pathFor(id)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E1))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                skuLine,
                style: AppFonts.bodySmall(color: _inkMuted).copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: AppFonts.bodySmall(color: _inkMuted).copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
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
                Icons.inventory_2_outlined,
                color: Color(0xFFB0B0B3),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No items yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Items from your catalog will appear here',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _inkMuted).copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered(_items);
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: Column(
        children: [
          if (_items.isNotEmpty) _searchBar(),
          if (hasQuery && _items.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE0E0E1))),
              ),
              child: Text(
                'SEARCH RESULTS (${filtered.length})',
                style: AppFonts.labelLarge(color: const Color(0xFF8A8A8A))
                    .copyWith(
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: const AppSkeletonScreenBody(
                      style: AppSkeletonScreenBodyStyle.listRows,
                      listRowCount: 10,
                    ),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppFonts.bodyMedium(color: _inkMuted),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _fetchItems(reset: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                ? RefreshIndicator(
                    onRefresh: () => _fetchItems(reset: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.65,
                        child: _emptyState(),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _fetchItems(reset: true),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length + 1,
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          if (_searchController.text.trim().isEmpty &&
                              !_isLoadingMore &&
                              _page < _totalPages) {
                            _fetchItems(reset: false);
                          }
                          if (_isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          return const SizedBox(height: 12);
                        }
                        return _itemRow(filtered[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'items_add_fab',
        onPressed: () async {
          final created = await context.push<ItemModel>(AddItemPage.path);
          if (!mounted) return;
          if (created != null) {
            await _fetchItems(reset: true);
          }
        },
        backgroundColor: const Color(0xFF121212),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
