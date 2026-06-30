import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';

/// One child line inside a composite pin (for display + create payload).
@immutable
class QuotationCompositeChildPin {
  const QuotationCompositeChildPin({
    required this.childItemName,
    required this.quantity,
    this.childItemId,
  });

  final String childItemName;
  final int quantity;
  final int? childItemId;

  Map<String, dynamic> toPayloadMap() => <String, dynamic>{
        if (childItemId != null) 'child_item_id': childItemId,
        'child_item_name': childItemName,
        'quantity': quantity,
      };
}

/// One pin from design / level API (`plots[].pins[]`) for display in the map sheet.
@immutable
class QuotationDesignPin {
  const QuotationDesignPin({
    required this.id,
    required this.itemName,
    this.sku,
    this.quantity = 1,
    this.statusLabel,
    this.statusBgHex,
    this.statusTextHex,
    this.sellingPrice,
    this.compositeItemId,
    this.isComposite = false,
    this.compositeItems = const [],
  });

  final String id;
  final String itemName;
  final String? sku;
  final int quantity;
  final String? statusLabel;
  final String? statusBgHex;
  final String? statusTextHex;
  final double? sellingPrice;
  /// `composite_item_id` for quotation create payload (from pin `item_detail` / API).
  final int? compositeItemId;
  final bool isComposite;
  final List<QuotationCompositeChildPin> compositeItems;

  double get lineTotal {
    final sp = sellingPrice ?? 0;
    final qty = quantity < 1 ? 1 : quantity;
    return sp * qty;
  }
}

/// Block / plot preview opened from a map line with a pin count.
Future<void> showQuotationMapBlockSheet(
  BuildContext context, {
  required TextEditingController blockNameController,
  required String plotGroupName,
  required int pinCount,
  String? sheetTitle,
  List<QuotationDesignPin> designPins = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _QuotationMapBlockSheetBody(
      blockNameController: blockNameController,
      plotGroupName: plotGroupName,
      pinCount: pinCount,
      sheetTitle: sheetTitle ?? 'Quotation Map',
      designPins: designPins,
    ),
  );
}

class _QuotationMapBlockSheetBody extends StatelessWidget {
  const _QuotationMapBlockSheetBody({
    required this.blockNameController,
    required this.plotGroupName,
    required this.pinCount,
    required this.sheetTitle,
    required this.designPins,
  });

  final TextEditingController blockNameController;
  final String plotGroupName;
  final int pinCount;
  final String sheetTitle;
  final List<QuotationDesignPin> designPins;

  static const _linkBlue = Color(0xFF1976D2);
  static final NumberFormat _gbp = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
  );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final labelSmall = AppFonts.labelMedium(
      color: AppColors.mutedLight,
    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5, fontSize: 10);

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
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
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
                      sheetTitle,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _linkBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$pinCount pins',
                        style: AppFonts.labelMedium(
                          color: _linkBlue,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 12),
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
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        hintText: 'Block name',
                        hintStyle: AppFonts.bodyMedium(color: AppColors.muted),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.borderLight.withValues(alpha: 0.9),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppColors.borderLight.withValues(alpha: 0.9),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _linkBlue,
                            width: 1.4,
                          ),
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
                            'Design pins — $plotGroupName · $sheetTitle',
                            style:
                                AppFonts.bodyMedium(
                                  color: AppColors.inkStrong,
                                ).copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (designPins.isEmpty) ...[
                      _PlaceholderProductLineCard(formatMoney: _gbp.format),
                      const SizedBox(height: 12),
                    ] else
                      ...designPins.map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DesignPinLineCard(
                            pin: p,
                            formatMoney: _gbp.format,
                          ),
                        ),
                      ),
                    if (designPins.isNotEmpty) const SizedBox(height: 4),
                    CustomPaint(
                      painter: _DottedBorderPainter(
                        color: AppColors.borderLight.withValues(alpha: 0.9),
                        borderRadius: 10,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _linkBlue,
                          side: BorderSide.none, // ← remove built-in border
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 20, color: _linkBlue),
                        label: Text(
                          'Add row',
                          style: AppFonts.labelMedium(
                            color: _linkBlue,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
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

Color? _parseHexColour(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return Color(v);
}

/// One pin row from the level API (item / qty / status / list price).
class _DesignPinLineCard extends StatelessWidget {
  const _DesignPinLineCard({
    required this.pin,
    required this.formatMoney,
  });

  final QuotationDesignPin pin;
  final String Function(num) formatMoney;

  static const _linkBlue = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final rowStyle = AppFonts.bodySmall(
      color: AppColors.muted,
    ).copyWith(fontSize: 13);
    final valueStyle = AppFonts.bodySmall(
      color: AppColors.inkStrong,
    ).copyWith(fontWeight: FontWeight.w600, fontSize: 13);
    final totalValueStyle = valueStyle.copyWith(
      color: _linkBlue,
      fontWeight: FontWeight.w800,
    );

    Widget row(String k, String v, {TextStyle? valueStyleOverride}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 2,
              child: Text(k, style: rowStyle),
            ),
            Flexible(
              flex: 3,
              child: Text(
                v,
                textAlign: TextAlign.end,
                style: valueStyleOverride ?? valueStyle,
              ),
            ),
          ],
        ),
      );
    }

    final listPrice = pin.sellingPrice ?? 0;
    final statusBg = _parseHexColour(pin.statusBgHex);
    final statusFg = _parseHexColour(pin.statusTextHex);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  pin.itemName,
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              if (pin.statusLabel != null && pin.statusLabel!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (statusBg ?? _linkBlue.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pin.statusLabel!.trim(),
                      style: AppFonts.labelMedium(
                        color: statusFg ?? _linkBlue,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                ),
              PopupMenuButton<void>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.muted.withValues(alpha: 0.9),
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem<void>(child: Text('Line options')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pin #${pin.id}',
            style: AppFonts.bodySmall(color: AppColors.muted).copyWith(fontSize: 11),
          ),
          if (pin.sku != null && pin.sku!.trim().isNotEmpty)
            Text(
              'SKU ${pin.sku}',
              style: AppFonts.bodySmall(color: AppColors.muted).copyWith(fontSize: 12),
            ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Qty', pin.quantity.toString()),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('List Price', formatMoney(listPrice)),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Amount', formatMoney(pin.lineTotal)),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Discount', formatMoney(0)),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Tax', formatMoney(0)),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          row('Total', formatMoney(pin.lineTotal), valueStyleOverride: totalValueStyle),
          if (pin.isComposite && pin.compositeItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'COMPOSITE ITEMS',
              style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            for (final child in pin.compositeItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· ${child.childItemName} (x${child.quantity})',
                  style: AppFonts.bodySmall(color: _linkBlue).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PlaceholderProductLineCard extends StatelessWidget {
  const _PlaceholderProductLineCard({required this.formatMoney});

  final String Function(num) formatMoney;

  static const _linkBlue = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    final rowStyle = AppFonts.bodySmall(
      color: AppColors.muted,
    ).copyWith(fontSize: 13);
    final valueStyle = AppFonts.bodySmall(
      color: AppColors.inkStrong,
    ).copyWith(fontWeight: FontWeight.w600, fontSize: 13);
    final totalValueStyle = valueStyle.copyWith(
      color: _linkBlue,
      fontWeight: FontWeight.w800,
    );

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
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product Name',
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              PopupMenuButton<void>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.muted.withValues(alpha: 0.9),
                ),
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
    final label = AppFonts.bodySmall(
      color: AppColors.muted,
    ).copyWith(fontSize: 14);
    final value = AppFonts.bodySmall(
      color: AppColors.inkStrong,
    ).copyWith(fontWeight: FontWeight.w600, fontSize: 14);
    final grandLabel = AppFonts.bodyMedium(
      color: AppColors.inkStrong,
    ).copyWith(fontWeight: FontWeight.w800, fontSize: 15);
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

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  const _DottedBorderPainter({required this.color, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }
 
  @override
  bool shouldRepaint(_DottedBorderPainter old) =>
      old.color != color || old.borderRadius != borderRadius;
}
