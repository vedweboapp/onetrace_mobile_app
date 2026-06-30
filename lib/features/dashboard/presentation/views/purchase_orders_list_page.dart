import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/dashboard/data/purchase_order_models.dart';
import 'package:red5/features/dashboard/data/purchase_orders_api_client.dart';
import 'package:red5/features/dashboard/presentation/purchase_order_list_refresh.dart';
import 'package:red5/features/dashboard/presentation/views/purchase_order_detail_page.dart';

class PurchaseOrdersListPage extends ConsumerStatefulWidget {
  const PurchaseOrdersListPage({super.key});

  @override
  ConsumerState<PurchaseOrdersListPage> createState() =>
      _PurchaseOrdersListPageState();
}

class _PurchaseOrdersListPageState extends ConsumerState<PurchaseOrdersListPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();
  final List<PurchaseOrderListItem> _orders = <PurchaseOrderListItem>[];

  static const _searchBg = Color(0xFFF5F5F5);
  static const _divider = Color(0xFFE8E8E8);
  static const _muted = Color(0xFF666666);
  static const _categoryMuted = Color(0xFF9CA3AF);

  static final _amountFormat = NumberFormat.currency(symbol: r'$');
  static final _dateFormat = DateFormat('MMM d, yyyy');

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchOrders(reset: true);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(() => _fetchOrders(reset: true));
  }

  Future<void> _fetchOrders({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      if (_isLoadingMore || _page >= _totalPages) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final api = ref.read(purchaseOrdersApiClientProvider);
      final nextPage = reset ? 1 : (_page + 1);
      final result = await api.fetchPurchaseOrdersPage(
        page: nextPage,
        pageSize: PurchaseOrdersApiClient.defaultPageSize,
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _orders
            ..clear()
            ..addAll(result.items);
        } else {
          _orders.addAll(result.items);
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
          genericFallback: 'Failed to load purchase orders',
        );
      });
    }
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
          hintText: 'Search purchase orders...',
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

  Widget _vendorAvatar(PurchaseOrderListItem item) {
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

  Widget _orderTile(PurchaseOrderListItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(PurchaseOrderDetailPage.pathFor(item.id)),
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
                      item.purchaseOrderNumber,
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
              Text(
                item.category,
                style: AppFonts.bodyMedium(color: _categoryMuted).copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.25,
                ),
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
                      text: purchaseOrderListStatusLabel(item.status),
                      style: TextStyle(
                        color: purchaseOrderListStatusColor(item.status),
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
                Icons.shopping_cart_outlined,
                color: Color(0xFFB0B0B3),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'No purchase orders found' : 'No purchase orders yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search'
                  : 'Create a purchase order to see it listed here',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _muted).copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'Failed to load purchase orders',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _fetchOrders(reset: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(purchaseOrderListRefreshTickProvider, (previous, next) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchOrders(reset: true);
        });
      }
    });

    return ColoredBox(
      color: AppColors.white,
      child: Column(
        children: [
          _searchBar(),
          Expanded(
            child: _isLoading && _orders.isEmpty
                ? const AppSkeletonScreenBody(
                    style: AppSkeletonScreenBodyStyle.listRows,
                  )
                : _error != null && _orders.isEmpty
                ? _errorState()
                : _orders.isEmpty
                ? _emptyState()
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.pixels >=
                              notification.metrics.maxScrollExtent - 200 &&
                          !_isLoadingMore &&
                          _page < _totalPages) {
                        _fetchOrders();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _orders.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _orderTile(_orders[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
