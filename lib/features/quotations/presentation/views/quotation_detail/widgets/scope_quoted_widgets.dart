part of '../quotation_detail.dart';

class _ScopeQuotedItemsTitle extends StatelessWidget {
  const _ScopeQuotedItemsTitle({required this.barColor, required this.title});

  final Color barColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2),
          ),
        ),
      ],
    );
  }
}

class _ScopeQuotedLineCard extends StatelessWidget {
  const _ScopeQuotedLineCard({required this.line, required this.formatMoney});

  final Map<String, dynamic> line;
  final String Function(num) formatMoney;

  String _productTitle() {
    for (final k in const [
      'product_name',
      'description',
      'name',
      'label',
      'title',
    ]) {
      final v = line[k];
      if (v != null && v is! Map && v is! List) {
        final t = v.toString().trim();
        if (t.isNotEmpty && t != 'null') return t;
      }
    }
    return 'Quoted item';
  }

  double _qty() {
    final q = _scopeParseDouble(line['quantity'] ?? line['qty']);
    return q > 0 ? q : 1;
  }

  double _listPrice() => _scopeParseDouble(
    line['list_price'] ?? line['listPrice'] ?? line['unit_price'],
  );

  double _amount() => _scopeParseDouble(line['amount'] ?? line['line_total']);

  double _discount() =>
      _scopeParseDouble(line['discount'] ?? line['discount_amount']);

  double _tax() => _scopeParseDouble(line['tax'] ?? line['tax_amount']);

  double _lineTotal() =>
      _scopeParseDouble(line['total'] ?? line['line_total'] ?? line['amount']);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            _productTitle(),
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _ScopeMetricRow(
            label: 'Qty',
            value: _qty().toStringAsFixed(2),
            valueBlue: false,
          ),
          _ScopeMetricRow(
            label: 'List Price',
            value: formatMoney(_listPrice()),
            valueBlue: false,
          ),
          _ScopeMetricRow(
            label: 'Amount',
            value: formatMoney(_amount()),
            valueBlue: true,
          ),
          _ScopeMetricRow(
            label: 'Discount',
            value: formatMoney(_discount()),
            valueBlue: true,
          ),
          _ScopeMetricRow(
            label: 'Tax',
            value: formatMoney(_tax()),
            valueBlue: true,
          ),
          _ScopeMetricRow(
            label: 'Total',
            value: formatMoney(_lineTotal()),
            valueBlue: true,
          ),
        ],
      ),
    );
  }
}

class _ScopeMetricRow extends StatelessWidget {
  const _ScopeMetricRow({
    required this.label,
    required this.value,
    required this.valueBlue,
  });

  final String label;
  final String value;
  final bool valueBlue;

  static const _linkBlue = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: AppFonts.bodyMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ),
          Text(
            value,
            style: AppFonts.bodyMedium(
              color: valueBlue ? _linkBlue : AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _ScopePricingSummary extends StatelessWidget {
  const _ScopePricingSummary({
    required this.totals,
    required this.formatMoney,
    required this.linkBlue,
  });

  final _ScopeTotals totals;
  final String Function(num) formatMoney;
  final Color linkBlue;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool grand = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: grand ? FontWeight.w800 : FontWeight.w500,
                  fontSize: grand ? 15 : 14,
                ),
              ),
            ),
            Text(
              value,
              style:
                  AppFonts.bodyMedium(
                    color: grand ? linkBlue : AppColors.inkStrong,
                  ).copyWith(
                    fontWeight: grand ? FontWeight.w800 : FontWeight.w600,
                    fontSize: grand ? 16 : 14,
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row('Sub Total', formatMoney(totals.subTotal)),
        row('Discount', formatMoney(totals.discount)),
        row('Tax', formatMoney(totals.tax)),
        row('Adjustment', formatMoney(totals.adjustment)),
        Divider(
          height: 1,
          thickness: 1,
          color: AppColors.borderLight.withValues(alpha: 0.9),
        ),
        row('Grand Total', formatMoney(totals.grandTotal), grand: true),
      ],
    );
  }
}

class _TagChipPill extends StatelessWidget {
  const _TagChipPill({required this.chip});

  final QuotationTagChip chip;

  @override
  Widget build(BuildContext context) {
    final initial = chip.name.isNotEmpty ? chip.name[0].toUpperCase() : '?';
    final url = chip.avatarUrl?.trim();
    final hasHttpAvatar =
        url != null &&
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: hasHttpAvatar ? NetworkImage(url) : null,
            child: !hasHttpAvatar
                ? Text(
                    initial,
                    style: AppFonts.labelMedium(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w800, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              chip.name,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.bodySmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.close,
            size: 16,
            color: AppColors.muted.withValues(alpha: 0.55),
          ),
        ],
      ),
    );
  }
}
