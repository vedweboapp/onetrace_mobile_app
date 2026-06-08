import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/bill_models.dart';
import 'package:red5/features/dashboard/presentation/views/bill_detail_page.dart';

class BillPreviewPage extends StatefulWidget {
  const BillPreviewPage({super.key, required this.billId});

  static const pathSuffix = '/preview';
  static const name = 'bill-preview';

  static String pathFor(String id) =>
      '${BillDetailPage.pathFor(id)}$pathSuffix';

  final String billId;

  @override
  State<BillPreviewPage> createState() => _BillPreviewPageState();
}

class _BillPreviewPageState extends State<BillPreviewPage> {
  bool _pdfBusy = false;

  static final _usd = NumberFormat.currency(symbol: r'$');
  static final _displayDate = DateFormat('MMMM d, yyyy');
  static final _qtyFormat = NumberFormat('#,##0.##');

  BillDetail get _detail => BillMockData.detailForId(widget.billId);

  Future<void> _onDownloadPdf() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _pdfBusy = false);
    context.showAppTopToast(
      title: 'PDF download API coming soon',
      type: AppTopToastType.info,
    );
  }

  Future<void> _onPrint() async {
    if (_pdfBusy) return;
    setState(() => _pdfBusy = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _pdfBusy = false);
    context.showAppTopToast(
      title: 'Print API coming soon',
      type: AppTopToastType.info,
    );
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

  Widget _addressColumn(String title, BillAddress address, String name) {
    final lines = <String>[
      address.street,
      '${address.city}, ${address.state} ${address.postalCode}'.trim(),
      address.country,
    ].where((line) => line.trim().isNotEmpty).toList();

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
        Text(
          name,
          style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        for (final line in lines)
          Text(
            line,
            style: AppFonts.bodySmall(color: AppColors.inkStrong),
          ),
      ],
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

  Widget _documentPreview(BillDetail detail) {
    final issue =
        detail.issueDate == null ? '—' : _displayDate.format(detail.issueDate!);
    final due =
        detail.dueDate == null ? '—' : _displayDate.format(detail.dueDate!);
    final subtotal = detail.subtotal;
    final tax = detail.billTax;
    final total = detail.grandTotal;

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
                        const SizedBox(height: 6),
                        Text(
                          detail.userName,
                          style: AppFonts.bodySmall(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w600),
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
                        detail.billNumber,
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
                      detail.userName,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _addressColumn(
                      'BILL TO',
                      detail.billingAddress,
                      detail.userName,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _metaCell('ISSUE DATE', issue),
                  _metaCell('DUE DATE', due),
                  _metaCell('PAYMENT TERMS', detail.paymentTerms),
                  _metaCell('PROJECT', detail.projectName),
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
              for (final item in detail.jobItems)
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
                              item.jobName,
                              style: AppFonts.bodySmall(
                                color: AppColors.inkStrong,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (item.location.trim().isNotEmpty)
                              Text(
                                item.location,
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
                          _usd.format(item.rate),
                          style: _tableCellStyle(),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _usd.format(item.lineTotal),
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
                      _summaryRow('Tax', _usd.format(tax)),
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final detail = _detail;

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
              child: _documentPreview(detail),
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
                  onPressed: _pdfBusy ? null : _onDownloadPdf,
                ),
                const SizedBox(height: 10),
                _actionButton(
                  label: 'Print',
                  onPressed: _pdfBusy ? null : _onPrint,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
