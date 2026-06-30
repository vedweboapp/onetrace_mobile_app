import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/purchase_order_models.dart';
import 'package:red5/features/dashboard/data/purchase_orders_api_client.dart';
import 'package:red5/features/dashboard/presentation/views/purchase_order_detail_page.dart';

class PurchaseOrderPreviewPage extends ConsumerStatefulWidget {
  const PurchaseOrderPreviewPage({super.key, required this.purchaseOrderId});

  static const pathSuffix = '/preview';
  static const name = 'purchase-order-preview';

  static String pathFor(String id) =>
      '${PurchaseOrderDetailPage.pathFor(id)}$pathSuffix';

  final String purchaseOrderId;

  @override
  ConsumerState<PurchaseOrderPreviewPage> createState() =>
      _PurchaseOrderPreviewPageState();
}

class _PurchaseOrderPreviewPageState
    extends ConsumerState<PurchaseOrderPreviewPage> {
  PurchaseOrderDetail? _detail;
  bool _loading = true;
  String? _error;

  static final _usd = NumberFormat.currency(symbol: r'$');
  static final _displayDate = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(purchaseOrdersApiClientProvider);
      final detail =
          await api.fetchPurchaseOrderDetail(widget.purchaseOrderId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load purchase order',
        );
      });
    }
  }

  Widget _actionButton({
    required String label,
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

  Widget _documentPreview(BuildContext context, PurchaseOrderDetail detail) {
    final issue = detail.issueDate == null
        ? '—'
        : _displayDate.format(detail.issueDate!);
    final due =
        detail.dueDate == null ? '—' : _displayDate.format(detail.dueDate!);
    final total = detail.grandTotal > 0 ? detail.grandTotal : 7950.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/Simho logo.jpg',
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Text(
                  'SimHo',
                  style: AppFonts.titleMedium(color: AppColors.inkStrong)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              Text(
                'PURCHASE ORDER',
                style: AppFonts.labelSmall(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            detail.purchaseOrderNumber,
            style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Issue: $issue  ·  Due: $due',
            style: AppFonts.bodySmall(color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _addressColumn(
                  'Bill To',
                  detail.billingAddress,
                  detail.vendorName,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _addressColumn(
                  'Ship To',
                  detail.shippingAddress,
                  detail.vendorName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB)),
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Description',
                    style: _tableHeaderStyle(),
                  ),
                ),
                Expanded(
                  child: Text('Qty', style: _tableHeaderStyle(), textAlign: TextAlign.right),
                ),
                Expanded(
                  child: Text('Rate', style: _tableHeaderStyle(), textAlign: TextAlign.right),
                ),
                Expanded(
                  child: Text('Amount', style: _tableHeaderStyle(), textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          for (final item in detail.lineItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      item.productName,
                      style: AppFonts.bodySmall(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.qty.toStringAsFixed(2),
                      style: _tableCellStyle(),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _usd.format(item.listPrice),
                      style: _tableCellStyle(),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _usd.format(item.total),
                      style: _tableCellStyle(),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Total Balance',
                  style: AppFonts.bodySmall(color: const Color(0xFF6B7280)),
                ),
                Text(
                  _usd.format(total),
                  style: AppFonts.titleLarge(color: AppColors.inkStrong).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          if (detail.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Notes',
              style: AppFonts.labelSmall(color: const Color(0xFF6B7280)).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail.notes,
              style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return AppFonts.labelSmall(color: const Color(0xFF6B7280)).copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 10,
    );
  }

  TextStyle _tableCellStyle() {
    return AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
  }

  Widget _addressColumn(
    String title,
    PurchaseOrderAddress address,
    String name,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppFonts.labelSmall(color: const Color(0xFF6B7280)).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          address.street,
          style: AppFonts.bodySmall(color: AppColors.inkStrong),
        ),
        Text(
          '${address.city}, ${address.state} ${address.postalCode}',
          style: AppFonts.bodySmall(color: AppColors.inkStrong),
        ),
        Text(
          address.country,
          style: AppFonts.bodySmall(color: AppColors.inkStrong),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: AppSkeletonScreenBody(
          style: AppSkeletonScreenBodyStyle.listRows,
        ),
      );
    }
    if (_error != null || _detail == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF3F4F6),
          foregroundColor: AppColors.inkStrong,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error ?? 'Purchase order not found',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadDetail,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final detail = _detail!;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F6),
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Preview Mode',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _documentPreview(context, detail),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              children: [
                _actionButton(
                  label: 'Close Preview',
                  onPressed: () => context.pop(),
                ),
                const SizedBox(height: 10),
                _actionButton(
                  label: 'Download PDF',
                  onPressed: () {
                    context.showAppTopToast(
                      title: 'PDF download coming soon',
                      type: AppTopToastType.info,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _actionButton(
                  label: 'Print',
                  onPressed: () {
                    context.showAppTopToast(
                      title: 'Print coming soon',
                      type: AppTopToastType.info,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
