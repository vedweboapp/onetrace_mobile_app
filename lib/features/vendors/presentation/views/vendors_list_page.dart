import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';
import 'package:red5/features/vendors/data/vendors_api_client.dart';
import 'package:red5/features/vendors/presentation/views/add_vendor_page.dart';
import 'package:red5/features/vendors/presentation/views/vendor_detail_page.dart';

class VendorsListPage extends ConsumerStatefulWidget {
  const VendorsListPage({super.key});

  @override
  ConsumerState<VendorsListPage> createState() => _VendorsListPageState();
}

class _VendorsListPageState extends ConsumerState<VendorsListPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();
  final List<VendorModel> _vendors = <VendorModel>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchVendors(reset: true);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(() => _fetchVendors(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVendors({bool reset = false}) async {
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
      final api = ref.read(vendorsApiClientProvider);
      final nextPage = reset ? 1 : (_page + 1);
      final result = await api.fetchVendorsPage(
        page: nextPage,
        pageSize: VendorsApiClient.defaultPageSize,
        search: _searchController.text.trim(),
        isActive: true,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _vendors
            ..clear()
            ..addAll(result.items);
        } else {
          _vendors.addAll(result.items);
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
        _error = _truncateErrorMessage(
          ApiResponseMessage.fromAnyError(
            e,
            genericFallback: 'Failed to load vendors',
          ),
        );
      });
    }
  }

  static String _truncateErrorMessage(String message, {int maxLen = 320}) {
    final trimmed = message.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen)}…';
  }

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEEF0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong)
            .copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search vendors...',
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFF8A8A8A), size: 20),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => _searchController.clear(),
                  icon: const Icon(
                    Icons.cancel,
                    color: Color(0xFF8A8A8A),
                    size: 18,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _vendorRow(VendorModel vendor) {
    return InkWell(
      onTap: () async {
        final changed = await context.push<bool?>(VendorDetailPage.pathFor(vendor.id));
        if (changed == true) _fetchVendors(reset: true);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE0E0E1))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
                    style: AppFonts.titleMedium(color: AppColors.inkStrong)
                        .copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                  if (vendor.typeName != null &&
                      vendor.typeName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      vendor.typeName!,
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF8B8B8B),
                      ).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/inperson.png',
                        height: 15,
                        width: 15,
                        color: const Color(0xFF8B8B8B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vendor.displayContact,
                          style: AppFonts.bodySmall(
                            color: const Color(0xFF8B8B8B),
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/call.png',
                        height: 15,
                        width: 15,
                        color: const Color(0xFF8B8B8B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vendor.displayPhone,
                          style: AppFonts.bodySmall(
                            color: const Color(0xFF8B8B8B),
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: vendorStatusBg(vendor.isActive),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: vendorStatusFg(vendor.isActive).withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                vendor.isActive ? 'ACTIVE' : 'INACTIVE',
                style: AppFonts.labelMedium(
                  color: vendorStatusFg(vendor.isActive),
                ).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  fontSize: 10,
                ),
              ),
            ),
          ],
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
                Icons.storefront_outlined,
                color: Color(0xFFB0B0B3),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'No vendors found' : 'No vendors yet',
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
                  : 'Create your first vendor to get started',
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
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: Column(
        children: [
          if (_vendors.isNotEmpty || hasQuery) _searchBar(),
          if (hasQuery)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE0E0E1))),
              ),
              child: Text(
                'SEARCH RESULTS (${_vendors.length})',
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
                ? const Center(
                    child: AppSkeletonScreenBody(
                      style: AppSkeletonScreenBodyStyle.listRows,
                      listRowCount: 10,
                    ),
                  )
                : _error != null
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Color(0xFFB0B0B3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.bodyMedium(
                            color: const Color(0xFF8A8A8A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _fetchVendors(reset: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _vendors.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: () => _fetchVendors(reset: true),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _vendors.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _vendors.length) {
                          if (!hasQuery &&
                              !_isLoadingMore &&
                              _page < _totalPages) {
                            _fetchVendors(reset: false);
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
                          return const SizedBox.shrink();
                        }
                        return _vendorRow(_vendors[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'vendors_add_fab',
        onPressed: () async {
          final created = await context.push<bool?>(AddVendorPage.path);
          if (created == true) _fetchVendors(reset: true);
        },
        backgroundColor: const Color(0xFF121212),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
