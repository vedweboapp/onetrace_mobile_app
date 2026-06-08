import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';
import 'package:red5/features/vendors/presentation/views/add_vendor_page.dart';
import 'package:red5/features/vendors/presentation/views/vendor_detail_page.dart';

class VendorsListPage extends StatefulWidget {
  const VendorsListPage({super.key});

  @override
  State<VendorsListPage> createState() => _VendorsListPageState();
}

class _VendorsListPageState extends State<VendorsListPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();

  static final _allVendors = VendorMockData.listItems;
  List<VendorListItem> _filtered = List.of(_allVendors);

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
        _filtered = List.of(_allVendors);
        return;
      }
      _filtered = _allVendors
          .where(
            (v) =>
                v.name.toLowerCase().contains(query) ||
                v.contactPerson.toLowerCase().contains(query) ||
                v.phone.toLowerCase().contains(query),
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

  Widget _vendorRow(VendorListItem vendor) {
    return InkWell(
      onTap: () => context.push(VendorDetailPage.pathFor(vendor.id)),
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
                          vendor.contactPerson,
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
                          vendor.phone,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: Column(
        children: [
          if (_filtered.isNotEmpty || _searchController.text.isNotEmpty)
            _searchBar(),
          Expanded(
            child: _filtered.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) =>
                        _vendorRow(_filtered[index]),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'vendors_add_fab',
        onPressed: () => context.push(AddVendorPage.path),
        backgroundColor: const Color(0xFF121212),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
