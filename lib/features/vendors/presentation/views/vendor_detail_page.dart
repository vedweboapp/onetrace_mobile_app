import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';
import 'package:red5/features/vendors/data/vendors_api_client.dart';

class VendorDetailPage extends ConsumerStatefulWidget {
  const VendorDetailPage({super.key, required this.vendorId});

  static const pathPrefix = '/vendors';
  static const name = 'vendor-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String vendorId;

  @override
  ConsumerState<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends ConsumerState<VendorDetailPage>
    with SingleTickerProviderStateMixin {
  static const _labelGrey = Color(0xFF9CA3AF);
  static const _divider = Color(0xFFE5E7EB);
  static const _searchBg = Color(0xFFEFEEF0);

  late final TabController _tabController;
  final _contactSearchController = TextEditingController();
  final _projectSearchController = TextEditingController();

  VendorModel? _vendor;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _contactSearchController.addListener(() => setState(() {}));
    _projectSearchController.addListener(() => setState(() {}));
    _loadVendor();
  }

  Future<void> _loadVendor() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final vendor = await ref
          .read(vendorsApiClientProvider)
          .fetchVendorDetail(widget.vendorId);
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load vendor',
        );
      });
    }
  }

  Future<void> _confirmDelete() async {
    final vendor = _vendor;
    if (vendor == null || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete vendor?'),
        content: Text(
          'This will permanently delete "${vendor.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(vendorsApiClientProvider).deleteVendor(vendor.id);
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Vendor deleted',
        type: AppTopToastType.success,
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Could not delete vendor',
        subtitle: ApiResponseMessage.fromAnyError(e),
        type: AppTopToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contactSearchController.dispose();
    _projectSearchController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: AppFonts.labelMedium(color: _labelGrey).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.55,
        fontSize: 10,
      ),
    );
  }

  Widget _fieldValue(String text) {
    return Text(
      text.trim().isEmpty ? '—' : text.trim(),
      style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.35,
      ),
    );
  }

  Widget _fullRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          const SizedBox(height: 5),
          _fieldValue(value),
        ],
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F5E9) : const Color(0xFFF1F1F2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: AppFonts.labelMedium(
          color: active ? const Color(0xFF2E7D32) : const Color(0xFF6B6B70),
        ).copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.65,
        ),
      ),
    );
  }

  Widget _addressCard(VendorAddressModel address, {required int index}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Address ${index + 1}',
                style: AppFonts.labelMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (address.isPrimary) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'PRIMARY',
                    style: AppFonts.labelSmall(
                      color: const Color(0xFF2E7D32),
                    ).copyWith(fontWeight: FontWeight.w800, fontSize: 9),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _fieldValue(address.fullLine),
        ],
      ),
    );
  }

  Widget _overviewTab(VendorModel vendor) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _sectionTitle('Basic Info'),
        _statusBadge(vendor.isActive),
        const SizedBox(height: 14),
        _fullRow('Vendor name', vendor.name),
        if (vendor.typeName != null && vendor.typeName!.trim().isNotEmpty)
          _fullRow('Type', vendor.typeName!),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
        _sectionTitle('Contact'),
        _fullRow('Email', vendor.email ?? '—'),
        _fullRow('Phone', vendor.displayPhone),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
        _sectionTitle('Addresses'),
        if (vendor.addresses.isEmpty)
          _fieldValue('No addresses on file')
        else
          for (var i = 0; i < vendor.addresses.length; i++)
            _addressCard(vendor.addresses[i], index: i),
      ],
    );
  }

  Widget _searchBar(TextEditingController controller, String hint) {
    final hasQuery = controller.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong)
            .copyWith(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppFonts.bodyLarge(color: const Color(0xFF9CA3AF))
              .copyWith(fontSize: 15),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 22),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => controller.clear(),
                  icon: const Icon(Icons.cancel, color: Color(0xFF9CA3AF)),
                )
              : null,
        ),
      ),
    );
  }

  Widget _emptyTab({
    required String title,
    required String message,
    required TextEditingController searchController,
    required String searchHint,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _sectionTitle(title),
        _searchBar(searchController, searchHint),
        const SizedBox(height: 24),
        Center(
          child: Text(
            message,
            style: AppFonts.bodyMedium(color: _labelGrey),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendor = _vendor;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          vendor?.name ?? 'Vendor',
          style: AppFonts.titleLarge(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (vendor != null)
            PopupMenuButton<String>(
              enabled: !_isDeleting,
              onSelected: (value) {
                if (value == 'delete') _confirmDelete();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete vendor',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
        ],
        bottom: vendor == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(49),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.inkStrong,
                      unselectedLabelColor: _labelGrey,
                      indicatorColor: AppColors.inkStrong,
                      indicatorWeight: 2.5,
                      labelStyle: AppFonts.labelMedium(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                      unselectedLabelStyle: AppFonts.labelMedium(color: _labelGrey)
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Contacts'),
                        Tab(text: 'Projects'),
                      ],
                    ),
                    const Divider(height: 1, thickness: 1, color: _divider),
                  ],
                ),
              ),
      ),
      body: _isLoading
          ? const Center(
              child: AppSkeletonScreenBody(
                style: AppSkeletonScreenBodyStyle.listRows,
                listRowCount: 6,
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppFonts.bodyMedium(color: _labelGrey),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadVendor,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : vendor == null
          ? const SizedBox.shrink()
          : TabBarView(
              controller: _tabController,
              children: [
                _overviewTab(vendor),
                _emptyTab(
                  title: 'Contacts',
                  message: 'No contacts linked to this vendor yet.',
                  searchController: _contactSearchController,
                  searchHint: 'Search contacts...',
                ),
                _emptyTab(
                  title: 'Projects',
                  message: 'No projects linked to this vendor yet.',
                  searchController: _projectSearchController,
                  searchHint: 'Search projects...',
                ),
              ],
            ),
    );
  }
}
