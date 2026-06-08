import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/dashboard/data/invoice_models.dart';
import 'package:red5/features/dashboard/data/invoices_api_client.dart';
import 'package:red5/features/dashboard/presentation/invoice_list_refresh.dart';
import 'package:red5/features/dashboard/presentation/views/invoice_detail_page.dart';

/// Admin invoices list from `GET /api/v1/invoice/`.
class InvoicesListPage extends ConsumerStatefulWidget {
  const InvoicesListPage({super.key});

  @override
  ConsumerState<InvoicesListPage> createState() => _InvoicesListPageState();
}

class _InvoicesListPageState extends ConsumerState<InvoicesListPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();

  static const _searchBg = Color(0xFFF5F5F5);
  static const _divider = Color(0xFFE8E8E8);
  static const _muted = Color(0xFF666666);

  static final _amountFormat = NumberFormat.currency(symbol: r'$');
  static final _dateFormat = DateFormat('MMM d, yyyy');

  final List<InvoiceListItem> _items = <InvoiceListItem>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchPage(reset: true);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(() => _fetchPage(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage({bool reset = false}) async {
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
      final api = ref.read(invoicesApiClientProvider);
      final nextPage = reset ? 1 : (_page + 1);
      final result = await api.fetchInvoicesPage(
        page: nextPage,
        pageSize: InvoicesApiClient.defaultPageSize,
        search: _searchController.text.trim(),
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
          genericFallback: 'Failed to load invoices',
        );
      });
    }
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
          hintText: 'Search invoices...',
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

  Widget _clientAvatar(InvoiceListItem item) {
    final url = item.clientAvatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 12,
        backgroundColor: const Color(0xFFE5E7EB),
        backgroundImage: NetworkImage(url),
      );
    }
    final initial = item.clientName.trim().isNotEmpty
        ? item.clientName.trim()[0].toUpperCase()
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

  Widget _invoiceTile(InvoiceListItem item) {
    final id = item.id.trim();
    final displayId =
        item.invoiceNumber.trim().isNotEmpty ? item.invoiceNumber : id;
    final canOpen = id.isNotEmpty;
    final status = item.listStatus;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !canOpen
            ? null
            : () => context.push(InvoiceDetailPage.pathFor(id)),
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
                      displayId,
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
                  _clientAvatar(item),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.clientName,
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
                      text: invoiceListStatusLabel(status),
                      style: TextStyle(
                        color: invoiceListStatusColor(status),
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
              hasQuery ? 'No invoices found' : 'No invoices yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search'
                  : 'Create an invoice to see it listed here',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _muted).copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scrollableBody({
    required Widget child,
    required Future<void> Function() onRefresh,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          color: const Color(0xFF121212),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.bodyMedium(color: _muted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _fetchPage(reset: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(invoiceListRefreshTickProvider, (previous, next) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchPage(reset: true);
        });
      }
    });

    final hasQuery = _searchController.text.trim().isNotEmpty;

    return ColoredBox(
      color: AppColors.white,
      child: Column(
        children: [
          if (!_isLoading && _error == null) _searchBar(),
          Expanded(
            child: _isLoading
                ? const AppSkeletonScreenBody(
                    style: AppSkeletonScreenBodyStyle.listRows,
                    listRowCount: 8,
                  )
                : _error != null
                ? _scrollableBody(
                    onRefresh: () => _fetchPage(reset: true),
                    child: _errorState(),
                  )
                : _items.isEmpty
                ? _scrollableBody(
                    onRefresh: () => _fetchPage(reset: true),
                    child: _emptyState(),
                  )
                : RefreshIndicator(
                    onRefresh: () => _fetchPage(reset: true),
                    color: const Color(0xFF121212),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _items.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          if (!hasQuery &&
                              !_isLoadingMore &&
                              _page < _totalPages) {
                            _fetchPage(reset: false);
                          }
                          if (_isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 12);
                        }
                        return _invoiceTile(_items[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
