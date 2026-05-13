import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// Block editor preview opened from a **Quotation Map (N)** line; **N** is the pin count.
Future<void> showQuotationMapBlockSheet(
  BuildContext context, {
  required TextEditingController blockNameController,
  required String plotGroupName,
  required int pinCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuotationMapBlockSheetBody(
      blockNameController: blockNameController,
      plotGroupName: plotGroupName,
      pinCount: pinCount,
    ),
  );
}

class _QuotationMapBlockSheetBody extends StatelessWidget {
  const _QuotationMapBlockSheetBody({
    required this.blockNameController,
    required this.plotGroupName,
    required this.pinCount,
  });

  final TextEditingController blockNameController;
  final String plotGroupName;
  final int pinCount;

  static const _linkBlue = Color(0xFF1976D2);
  static final NumberFormat _gbp = NumberFormat.currency(locale: 'en_GB', symbol: '£');

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final labelSmall = AppFonts.labelMedium(color: AppColors.mutedLight).copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      fontSize: 10,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Quotation Map',
                      style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _linkBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$pinCount pins',
                        style: AppFonts.labelMedium(color: _linkBlue).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
                  children: [
                    Text('BLOCK NAME', style: labelSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: blockNameController,
                      style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        hintText: 'Block name',
                        hintStyle: AppFonts.bodyMedium(color: AppColors.muted),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.9)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.9)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _linkBlue, width: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 4,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.inkStrong,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Quoted Items — $plotGroupName',
                            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ProductLineCard(formatMoney: _gbp.format),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _linkBlue,
                        side: BorderSide(
                          color: AppColors.borderLight.withValues(alpha: 0.9),
                          style: BorderStyle.solid,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 20, color: _linkBlue),
                      label: Text(
                        'Add row',
                        style: AppFonts.labelMedium(color: _linkBlue).copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _TotalsBlock(formatMoney: _gbp.format),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductLineCard extends StatelessWidget {
  const _ProductLineCard({required this.formatMoney});

  final String Function(num) formatMoney;

  static const _linkBlue = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final rowStyle = AppFonts.bodySmall(color: AppColors.muted).copyWith(fontSize: 13);
    final valueStyle = AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    final totalValueStyle = valueStyle.copyWith(color: _linkBlue, fontWeight: FontWeight.w800);

    Widget row(String k, String v, {TextStyle? valueStyleOverride}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: rowStyle),
            Text(v, style: valueStyleOverride ?? valueStyle),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product Name',
                  style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              PopupMenuButton<void>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_vert, color: AppColors.muted.withValues(alpha: 0.9)),
                itemBuilder: (context) => const [
                  PopupMenuItem<void>(child: Text('Line options')),
                ],
              ),
            ],
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Qty', '1.00'),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('List Price', formatMoney(0)),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Amount', formatMoney(0)),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Discount', formatMoney(0)),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Tax', formatMoney(0)),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Total', formatMoney(0), valueStyleOverride: totalValueStyle),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TotalsBlock extends StatelessWidget {
  const _TotalsBlock({required this.formatMoney});

  final String Function(num) formatMoney;

  static const _linkBlue = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final label = AppFonts.bodySmall(color: AppColors.muted).copyWith(fontSize: 14);
    final value = AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );
    final grandLabel = AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );
    final grandValue = grandLabel.copyWith(color: _linkBlue);

    Widget line(String k, String v, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: bold ? grandLabel : label),
            Text(v, style: bold ? grandValue : value),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line('Sub Total', formatMoney(0)),
        line('Discount', formatMoney(0)),
        line('Tax', formatMoney(0)),
        line('Adjustment', formatMoney(0)),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        const SizedBox(height: 12),
        line('Grand Total', formatMoney(0), bold: true),
      ],
    );
  }
}
