import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/invoice_models.dart';
import 'package:red5/features/dashboard/data/invoices_api_client.dart';
import 'package:red5/features/dashboard/presentation/views/invoice_detail_page.dart';

class InvoicePreviewPage extends ConsumerStatefulWidget {
  const InvoicePreviewPage({super.key, required this.invoiceId});

  static const pathSuffix = '/preview';
  static const name = 'invoice-preview';

  static String pathFor(String id) =>
      '${InvoiceDetailPage.pathFor(id)}$pathSuffix';

  final String invoiceId;

  @override
  ConsumerState<InvoicePreviewPage> createState() => _InvoicePreviewPageState();
}

class _InvoicePreviewPageState extends ConsumerState<InvoicePreviewPage> {
  InvoiceDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _pdfBusy = false;

  static final _usd = NumberFormat.currency(symbol: r'$');
  static final _displayDate = DateFormat('MMMM d, yyyy');
  static final _qtyFormat = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final id = widget.invoiceId.trim();
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Invalid invoice id';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await ref.read(invoicesApiClientProvider).fetchInvoiceDetail(id);
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
          genericFallback: 'Failed to load invoice',
        );
      });
    }
  }

  Future<void> _onDownloadPdf() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      await ref
          .read(invoicesApiClientProvider)
          .downloadInvoicePdf(widget.invoiceId);
      if (!mounted) return;
      context.showAppTopToast(
        title: 'PDF downloaded',
        type: AppTopToastType.success,
      );
    } on InvoicePdfNotAvailableException {
      if (!mounted) return;
      context.showAppTopToast(
        title: 'PDF download API coming soon',
        type: AppTopToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      context.showAppTopToast(
        title: ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to download PDF',
        ),
        type: AppTopToastType.error,
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _onPrint() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      await ref.read(invoicesApiClientProvider).printInvoice(widget.invoiceId);
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Print dialog opened',
        type: AppTopToastType.success,
      );
    } on InvoicePdfNotAvailableException {
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Print API coming soon',
        type: AppTopToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      context.showAppTopToast(
        title: ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to print invoice',
        ),
        type: AppTopToastType.error,
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Widget _actionButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF111111),
          foregroundColor: AppColors.white,
          disabledBackgroundColor: const Color(0xFF6B7280),
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

  TextStyle _tableHeaderStyle() {
    return AppFonts.labelSmall(color: const Color(0xFF6B7280)).copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 9,
      letterSpacing: 0.4,
    );
  }

  TextStyle _tableCellStyle() {
    return AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
  }

  Widget _metaCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _tableHeaderStyle()),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressColumn(
    String title,
    InvoiceAddress address,
    String name, {
    String? attn,
    String? email,
    String? phone,
  }) {
    final lines = <String>[
      if (address.addressLine1.trim().isNotEmpty) address.addressLine1,
      if (address.addressLine2.trim().isNotEmpty) address.addressLine2,
      if (address.city.trim().isNotEmpty ||
          address.state.trim().isNotEmpty ||
          address.postalCode.trim().isNotEmpty)
        [
          address.city,
          address.state,
          address.postalCode,
        ].where((part) => part.trim().isNotEmpty).join(', '),
      if (address.country.trim().isNotEmpty) address.country,
      if (phone != null && phone.trim().isNotEmpty) phone,
      if (email != null && email.trim().isNotEmpty) email,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppFonts.labelSmall(color: const Color(0xFF6B7280)).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        if (name.trim().isNotEmpty)
          Text(
            name,
            style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        if (attn != null && attn.trim().isNotEmpty)
          Text(
            'Attn: $attn',
            style: AppFonts.bodySmall(color: AppColors.inkStrong),
          ),
        for (final line in lines)
          Text(
            line,
            style: AppFonts.bodySmall(color: AppColors.inkStrong),
          ),
      ],
    );
  }

  Widget _documentPreview(InvoiceDetail detail) {
    final issue =
        detail.issueDate == null ? '—' : _displayDate.format(detail.issueDate!);
    final due =
        detail.dueDate == null ? '—' : _displayDate.format(detail.dueDate!);
    final paymentTerms =
        detail.paymentTerms.trim().isEmpty ? '—' : detail.paymentTerms;
    final project =
        detail.projectName.trim().isEmpty ? '—' : detail.projectName;
    final subtotal = detail.subtotal;
    final adjustment = detail.adjustment;
    final total = detail.grandTotal;
    final invoiceNo =
        detail.invoiceNumber.trim().isEmpty ? detail.id : detail.invoiceNumber;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          radius: const Radius.circular(4),
          color: const Color(0xFFD1D5DB),
          strokeWidth: 1.2,
          dashPattern: const [6, 4],
          padding: const EdgeInsets.all(0),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: AppColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/images/Simho logo.jpg',
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Text(
                            'SimHo',
                            style: AppFonts.titleMedium(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'INVOICE',
                        style: AppFonts.labelSmall(color: AppColors.inkStrong)
                            .copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        invoiceNo,
                        style: AppFonts.titleMedium(color: AppColors.inkStrong)
                            .copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _addressColumn(
                      'SHIP TO',
                      detail.shippingAddress,
                      detail.clientName,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _addressColumn(
                      'BILL TO',
                      detail.billingAddress,
                      detail.clientName,
                      attn: detail.contactPerson,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _metaCell('ISSUE DATE', issue),
                  _metaCell('DUE DATE', due),
                  _metaCell('PAYMENT TERMS', paymentTerms),
                  _metaCell('PROJECT', project),
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
                      flex: 4,
                      child: Text('DESCRIPTION', style: _tableHeaderStyle()),
                    ),
                    Expanded(
                      child: Text(
                        'QTY',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'UNIT',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'RATE',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'AMOUNT',
                        style: _tableHeaderStyle(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              if (detail.productItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No line items',
                    style: AppFonts.bodySmall(color: const Color(0xFF6B7280)),
                  ),
                )
              else
                for (final item in detail.productItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: AppFonts.bodySmall(
                                  color: AppColors.inkStrong,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (item.groupName != null &&
                                  item.groupName!.trim().isNotEmpty)
                                Text(
                                  item.groupName!,
                                  style: AppFonts.bodySmall(
                                    color: const Color(0xFF6B7280),
                                  ).copyWith(fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _qtyFormat.format(item.qty),
                            style: _tableCellStyle(),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '—',
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
                            _usd.format(
                              item.total > 0 ? item.total : item.amount,
                            ),
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
                child: SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _summaryRow('Sub Total', _usd.format(subtotal)),
                      const SizedBox(height: 6),
                      _summaryRow('Adjustment', _usd.format(adjustment)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EEF4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Balance',
                              style: AppFonts.bodySmall(
                                color: const Color(0xFF6B7280),
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _usd.format(total),
                              style: AppFonts.titleLarge(
                                color: AppColors.inkStrong,
                              ).copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.bodySmall(color: const Color(0xFF6B7280)).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _bodyContent() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: AppSkeletonBox(height: 280, width: double.infinity),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: AppColors.inkStrong),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadDetail,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: _documentPreview(detail),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final actionsEnabled = !_loading && _error == null && !_pdfBusy;

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
          Expanded(child: _bodyContent()),
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
                  onPressed: actionsEnabled ? _onDownloadPdf : null,
                ),
                const SizedBox(height: 10),
                _actionButton(
                  label: 'Print',
                  onPressed: actionsEnabled ? _onPrint : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
