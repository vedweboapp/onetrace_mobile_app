import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/purchase_order_models.dart';
import 'package:red5/features/dashboard/presentation/views/add_purchase_order_page.dart';
import 'package:red5/features/dashboard/presentation/views/purchase_order_preview_page.dart';

class PurchaseOrderDetailPage extends StatefulWidget {
  const PurchaseOrderDetailPage({super.key, required this.purchaseOrderId});

  static const pathPrefix = '/purchase-orders';
  static const name = 'purchase-order-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String purchaseOrderId;

  @override
  State<PurchaseOrderDetailPage> createState() =>
      _PurchaseOrderDetailPageState();
}

class _PurchaseOrderDetailPageState extends State<PurchaseOrderDetailPage>
    with SingleTickerProviderStateMixin {
  static const _labelGrey = Color(0xFF9CA3AF);
  static const _divider = Color(0xFFE5E7EB);
  static const _searchBg = Color(0xFFF5F5F5);
  static const _amountBlue = Color(0xFF2563EB);

  late final TabController _tabController;
  final _itemsSearchController = TextEditingController();
  late final PurchaseOrderDetail _detail;

  static final _displayDate = DateFormat('MMM d, yyyy');
  static final _qtyFormat = NumberFormat('#,##0.00');
  static final _gbp = NumberFormat.currency(locale: 'en_GB', symbol: '£');

  @override
  void initState() {
    super.initState();
    _detail = PurchaseOrderMockData.detailForId(widget.purchaseOrderId);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _itemsSearchController.addListener(() => setState(() {}));
  }

  String _formatDate(DateTime? value) =>
      value == null ? '—' : _displayDate.format(value);

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _itemsSearchController.dispose();
    super.dispose();
  }

  String _formatGbp(double value) => _gbp.format(value);

  void _onEdit() => context.push(AddPurchaseOrderPage.path);

  void _onSend() {
    context.showAppTopToast(
      title: 'Purchase order sent (preview)',
      type: AppTopToastType.success,
    );
  }

  void _onPreview() {
    context.push(PurchaseOrderPreviewPage.pathFor(widget.purchaseOrderId));
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: AppFonts.labelSmall(color: AppColors.inkStrong).copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _subsectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        text,
        style: AppFonts.titleSmall(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: AppFonts.labelSmall(color: _labelGrey).copyWith(
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _value(String text, {bool semibold = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: semibold ? FontWeight.w600 : FontWeight.w500,
          fontSize: 15,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _twoColumnRow({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(leftLabel),
              _value(leftValue),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(rightLabel),
              _value(rightValue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusHeader(PurchaseOrderDetail detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              detail.purchaseOrderNumber,
              style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: detail.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            detail.statusLabel,
            style: AppFonts.titleMedium(color: detail.statusColor).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressBlock(PurchaseOrderAddress address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Address'),
        _value(address.street),
        _twoColumnRow(
          leftLabel: 'City',
          leftValue: address.city,
          rightLabel: 'State/Province',
          rightValue: address.state,
        ),
        _twoColumnRow(
          leftLabel: 'Postal Code',
          leftValue: address.postalCode,
          rightLabel: 'Country',
          rightValue: address.country,
        ),
      ],
    );
  }

  Widget _notesBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _overviewTab(PurchaseOrderDetail detail) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _sectionTitle('Purchase Details'),
        _label('Vendor Name'),
        _value(detail.vendorName),
        _label('Contact Person'),
        _value(detail.contactPerson),
        _label('Project Name'),
        _value(detail.projectName),
        _label('Category Name'),
        _value(detail.categoryName),
        _twoColumnRow(
          leftLabel: 'Issue Date',
          leftValue: _formatDate(detail.issueDate),
          rightLabel: 'Due Date',
          rightValue: _formatDate(detail.dueDate),
        ),
        _label('Payment Terms'),
        _value(detail.paymentTerms),
        _subsectionTitle('Billing Address'),
        _addressBlock(detail.billingAddress),
        _subsectionTitle('Shipping Address'),
        _addressBlock(detail.shippingAddress),
        _sectionTitle('Notes & Terms'),
        _notesBox(detail.notes.trim().isEmpty ? '—' : detail.notes),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _itemsSearchBar() {
    final hasQuery = _itemsSearchController.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _itemsSearchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong)
            .copyWith(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search Items...',
          hintStyle: AppFonts.bodyLarge(color: const Color(0xFF9CA3AF))
              .copyWith(fontSize: 15, fontWeight: FontWeight.w400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF9CA3AF),
            size: 22,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => _itemsSearchController.clear(),
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

  Widget _productMetricRow(
    String label,
    String value, {
    bool valueIsBlue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: AppFonts.bodyMedium(
              color: valueIsBlue ? _amountBlue : AppColors.inkStrong,
            ).copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(PurchaseOrderLineItem item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName,
            style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _productMetricRow('Qty', _qtyFormat.format(item.qty)),
          _productMetricRow('List Price', _formatGbp(item.listPrice)),
          _productMetricRow(
            'Amount',
            _formatGbp(item.amount),
            valueIsBlue: true,
          ),
          _productMetricRow(
            'Discount',
            _formatGbp(item.discount),
            valueIsBlue: true,
          ),
          _productMetricRow(
            'Tax',
            _formatGbp(item.tax),
            valueIsBlue: true,
          ),
          _productMetricRow(
            'Total',
            _formatGbp(item.total),
            valueIsBlue: true,
          ),
        ],
      ),
    );
  }

  List<PurchaseOrderLineItem> _filteredItems(PurchaseOrderDetail detail) {
    final query = _itemsSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return detail.lineItems;
    return detail.lineItems
        .where((i) => i.productName.toLowerCase().contains(query))
        .toList();
  }

  Widget _itemsSummaryRow(
    String label,
    String value, {
    bool bold = false,
    bool valueBlue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.bodyMedium(
                color: bold ? AppColors.inkStrong : _labelGrey,
              ).copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 15 : 14,
              ),
            ),
          ),
          Text(
            value,
            style: AppFonts.bodyMedium(
              color: valueBlue ? _amountBlue : AppColors.inkStrong,
            ).copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsTab(PurchaseOrderDetail detail) {
    final products = _filteredItems(detail);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        Text(
          'Items',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 12),
        _itemsSearchBar(),
        const SizedBox(height: 14),
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No items match your search',
                style: AppFonts.bodyMedium(color: _labelGrey),
              ),
            ),
          )
        else
          for (final item in products) _productCard(item),
        const SizedBox(height: 8),
        _itemsSummaryRow('Sub Total', _formatGbp(detail.subtotal)),
        _itemsSummaryRow('Discount', _formatGbp(detail.orderDiscount)),
        _itemsSummaryRow('Tax', _formatGbp(detail.orderTax)),
        _itemsSummaryRow('Adjustment', _formatGbp(detail.adjustment)),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, color: _divider),
        ),
        _itemsSummaryRow(
          'Grand Total',
          _formatGbp(detail.grandTotal),
          bold: true,
          valueBlue: true,
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData? leadingIcon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF111111),
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 18),
              const SizedBox(width: 10),
            ] else
              const SizedBox(width: 28),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppFonts.titleMedium(color: AppColors.white).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Purchase Order Details',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            onPressed: _onEdit,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.inkStrong,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
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
                labelStyle: AppFonts.labelMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle: AppFonts.labelMedium(
                  color: _labelGrey,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Items'),
                ],
              ),
              const Divider(height: 1, thickness: 1, color: _divider),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_tabController.index == 0) _statusHeader(detail),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _overviewTab(detail),
                _itemsTab(detail),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: _divider)),
            ),
            child: Column(
              children: [
                _actionButton(
                  label: 'Send Purchase Order',
                  leadingIcon: Icons.send_outlined,
                  onPressed: _onSend,
                ),
                const SizedBox(height: 10),
                _actionButton(
                  label: 'Preview Purchase Order',
                  leadingIcon: null,
                  onPressed: _onPreview,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
