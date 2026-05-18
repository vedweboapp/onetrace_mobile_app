import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/composite_items/presentation/view/add_composite_item_page.dart';
import 'package:red5/features/items/data/item_models.dart';
import 'package:red5/features/items/data/items_api_client.dart';
import 'package:red5/features/items/presentation/views/add_item_page.dart';
import 'package:red5/features/items/presentation/views/item_detail_page.dart';

/// Detail for one composite catalog row — Overview + Items tabs after
/// `GET /api/v1/item/{id}/`.
class CompositeItemDetailsPage extends ConsumerStatefulWidget {
  const CompositeItemDetailsPage({super.key, required this.itemId});

  static const pathPrefix = '/catalog/composite-items';
  static const name = 'composite-item-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String itemId;

  @override
  ConsumerState<CompositeItemDetailsPage> createState() =>
      _CompositeItemDetailsPageState();
}

class _CompositeItemDetailsPageState extends ConsumerState<CompositeItemDetailsPage>
    with SingleTickerProviderStateMixin {
  ItemDetailModel? _item;
  bool _isLoading = true;
  String? _error;
  late final TabController _tabController;
  final _itemsSearchController = TextEditingController();

  static const _labelGrey = Color(0xFF9CA3AF);
  static const _searchBg = Color(0xFFEFEEF0);
  static const _badgeBg = Color(0xFFF5F3FF);
  static const _badgeBorder = Color(0xFFE9E5FF);
  static const _badgeText = Color(0xFF5B21B6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _itemsSearchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemsSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.itemId.trim();
    if (id.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid item id';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(itemsApiClientProvider);
      final data = await api.fetchItemDetail(id);
      if (!mounted) return;
      setState(() {
        _item = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load composite item',
        );
      });
    }
  }

  String _fmtQty(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    return q.toString();
  }

  String _fmtMoney(double v) => v.toStringAsFixed(2);

  Future<void> _onEditTap() async {
    final item = _item;
    if (item == null) return;
    if (item.isComposite) {
      await context.push<Object?>(
        AddCompositeItemPage.pathForEdit(widget.itemId),
        extra: item,
      );
    } else {
      await context.push<Object?>(
        AddItemPage.pathForEdit(widget.itemId),
        extra: item,
      );
    }
    if (mounted) await _load();
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
      style: AppFonts.bodyMedium(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w500, fontSize: 16, height: 1.35),
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

  Widget _compositeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _badgeBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _badgeBorder),
      ),
      child: Text(
        'Composite item',
        style: AppFonts.bodySmall(color: _badgeText).copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _recordBlock(String label, String line1, {String? line2}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          const SizedBox(height: 5),
          _fieldValue(line1),
          if (line2 != null && line2.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              line2.trim(),
              style: AppFonts.bodyMedium(
                color: AppColors.muted,
              ).copyWith(fontWeight: FontWeight.w500, fontSize: 15, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _overviewBody(ItemDetailModel d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _compositeBadge(),
        const SizedBox(height: 20),
        _fullRow('Composite items name', d.name),
        _fullRow('SKU', d.sku),
        _fullRow('Reorder quantity', _fmtQty(d.reorderQuantity)),
        _fullRow('Quantity', _fmtQty(d.quantity)),
        _fullRow('Item type', d.itemTypeLabel),
        _fullRow('Cost price', _fmtMoney(d.costPrice)),
        _fullRow('Selling price', _fmtMoney(d.sellPrice)),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 16),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
        _fullRow('Created at', d.createdAtDisplay),
        _fullRow('Updated at', d.updatedAtDisplay),
        _recordBlock(
          'Created by',
          d.createdByUsername.isNotEmpty ? d.createdByUsername : '—',
          line2: d.createdByEmail.isNotEmpty ? d.createdByEmail : null,
        ),
        _recordBlock(
          'Modified by',
          d.hasModifiedBy
              ? (d.modifiedByUsername.isNotEmpty
                    ? d.modifiedByUsername
                    : (d.modifiedByEmail.isNotEmpty ? d.modifiedByEmail : '—'))
              : '—',
          line2: d.hasModifiedBy &&
                  d.modifiedByUsername.isNotEmpty &&
                  d.modifiedByEmail.isNotEmpty
              ? d.modifiedByEmail
              : null,
        ),
      ],
    );
  }

  List<ItemComponentLine> _filteredComponents(ItemDetailModel d) {
    final q = _itemsSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return d.components;
    return d.components.where((c) {
      final name = c.itemName.toLowerCase();
      final sku = c.sku.toLowerCase();
      final id = c.itemId.toLowerCase();
      return name.contains(q) || sku.contains(q) || id.contains(q);
    }).toList();
  }

  String _componentTitle(ItemComponentLine c) {
    final name = c.itemName.trim();
    if (name.isNotEmpty) return name;
    final id = c.itemId.trim();
    if (id.isNotEmpty) return 'Item #$id';
    return 'Item';
  }

  Widget _itemsSearchField() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _itemsSearchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong).copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search Items...',
          hintStyle: AppFonts.bodyMedium(color: AppColors.muted).copyWith(fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8A8A8A), size: 22),
        ),
      ),
    );
  }

  Widget _componentTile(ItemComponentLine c) {
    final id = c.itemId.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: id.isEmpty ? null : () => context.push(ItemDetailPage.pathFor(id)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E1))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _componentTitle(c),
                      style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Text(
                        'Qty ${_fmtQty(c.quantity)}',
                        style: AppFonts.labelMedium(color: AppColors.inkStrong).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.muted.withValues(alpha: 0.75),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemsBody(ItemDetailModel d) {
    final rows = _filteredComponents(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _itemsSearchField(),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      d.components.isEmpty
                          ? 'No component items in this composite yet.'
                          : 'No items match your search.',
                      textAlign: TextAlign.center,
                      style: AppFonts.bodyMedium(color: AppColors.muted).copyWith(
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: rows.map(_componentTile).toList(),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _item?.name.isNotEmpty == true ? _item!.name : 'Item';
    final hasData = !_isLoading && _error == null && _item != null;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: const Color(0xFFF1F1F2),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _isLoading || _item == null ? null : _onEditTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/edit_icon.png',
                    height: 18,
                    width: 18,
                    color: AppColors.inkStrong,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(hasData ? 50 : 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasData)
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.inkStrong,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.inkStrong,
                  indicatorWeight: 2.2,
                  labelStyle: AppFonts.labelMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                  unselectedLabelStyle: AppFonts.labelMedium(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Items'),
                  ],
                ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: AppSkeletonScreenBody(
                scrollable: false,
                toastBlockCount: 4,
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: AppFonts.bodyMedium(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _item == null
          ? const SizedBox.shrink()
          : TabBarView(
              controller: _tabController,
              children: [
                _overviewBody(_item!),
                _itemsBody(_item!),
              ],
            ),
    );
  }
}
