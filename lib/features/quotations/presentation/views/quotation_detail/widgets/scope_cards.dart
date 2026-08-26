part of '../quotation_detail.dart';

class _ScopeSectionCard extends StatelessWidget {
  const _ScopeSectionCard({
    required this.section,
    required this.expanded,
    required this.onExpandedChanged,
    required this.formatMoney,
    required this.plotExpanded,
    required this.onPlotExpandedChanged,
  });

  final _QuoteSectionVm section;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final String Function(num) formatMoney;
  final bool Function(int plotIndex) plotExpanded;
  final void Function(int plotIndex, bool expanded) onPlotExpandedChanged;

  @override
  Widget build(BuildContext context) {
    return _ScopeCollapsibleCard(
      title: section.name,
      trailing: formatMoney(section.sectionTotal),
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      child: section.plots.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No plots in this block.',
                style: AppFonts.bodySmall(color: AppColors.muted),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                children: [
                  for (var pi = 0; pi < section.plots.length; pi++) ...[
                    if (pi > 0) const SizedBox(height: 8),
                    _ScopePlotCard(
                      plot: section.plots[pi],
                      expanded: plotExpanded(pi),
                      onExpandedChanged: (v) => onPlotExpandedChanged(pi, v),
                      formatMoney: formatMoney,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _ScopeBlockTotalsFooter(
                    subtotal: section.sectionTotal,
                    formatMoney: formatMoney,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScopePlotCard extends StatelessWidget {
  const _ScopePlotCard({
    required this.plot,
    required this.expanded,
    required this.onExpandedChanged,
    required this.formatMoney,
  });

  final _QuotePlotVm plot;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final String Function(num) formatMoney;

  @override
  Widget build(BuildContext context) {
    return _ScopeCollapsibleCard(
      title: plot.name,
      trailing: formatMoney(plot.plotTotal),
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      nested: true,
      child: plot.pins.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No quoted items in this plot.',
                style: AppFonts.bodySmall(color: AppColors.muted),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                children: [
                  for (var i = 0; i < plot.pins.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _ScopeQuotePinCard(
                      pin: plot.pins[i],
                      formatMoney: formatMoney,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _ScopePlotTotalsRow(
                    total: plot.plotTotal,
                    formatMoney: formatMoney,
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScopeCollapsibleCard extends StatelessWidget {
  const _ScopeCollapsibleCard({
    required this.title,
    required this.trailing,
    required this.expanded,
    required this.onExpandedChanged,
    required this.child,
    this.nested = false,
  });

  final String title;
  final String trailing;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Widget child;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final borderColor = nested ? const Color(0xFFE8E8E8) : AppColors.borderLight;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(nested ? 10 : 12),
        border: Border.all(color: borderColor),
        boxShadow: nested
            ? null
            : [
                BoxShadow(
                  color: AppColors.inkStrong.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.white,
            child: InkWell(
              onTap: () => onExpandedChanged(!expanded),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(nested ? 10 : 12),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: nested ? 10 : 12,
                  vertical: nested ? 10 : 12,
                ),
                child: Row(
                  children: [
                    if (!nested)
                      Icon(
                        Icons.drag_indicator,
                        color: AppColors.muted.withValues(alpha: 0.85),
                        size: 24,
                      ),
                    if (!nested) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        style: AppFonts.titleMedium(
                          color: AppColors.inkStrong,
                        ).copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: nested ? 15 : 16,
                        ),
                      ),
                    ),
                    Text(
                      trailing,
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: nested ? 14 : 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.inkStrong,
                      size: nested ? 22 : 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.borderLight.withValues(alpha: 0.9),
            ),
            child,
          ],
        ],
      ),
    );
  }
}

class _ScopeQuotePinCard extends StatelessWidget {
  const _ScopeQuotePinCard({
    required this.pin,
    required this.formatMoney,
  });

  final _QuotePinVm pin;
  final String Function(num) formatMoney;

  @override
  Widget build(BuildContext context) {
    const linkBlue = Color(0xFF1976D2);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pin.name,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          _ScopeMetricRow(
            label: 'Qty',
            value: pin.quantity.toString(),
            valueBlue: false,
          ),
          _ScopeMetricRow(
            label: 'Selling Price',
            value: formatMoney(pin.sellingPrice),
            valueBlue: false,
          ),
          _ScopeMetricRow(
            label: 'Total',
            value: formatMoney(pin.pinsTotal),
            valueBlue: true,
          ),
          if (pin.isComposite && pin.compositeItems.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'COMPOSITE ITEMS',
              style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in pin.compositeItems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· ${item.childItemName} (x${item.quantity})',
                  style: AppFonts.bodySmall(color: linkBlue).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ScopePlotTotalsRow extends StatelessWidget {
  const _ScopePlotTotalsRow({
    required this.total,
    required this.formatMoney,
  });

  final double total;
  final String Function(num) formatMoney;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'PLOT TOTAL',
              style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 10,
              ),
            ),
          ),
          Text(
            formatMoney(total),
            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeBlockTotalsFooter extends StatelessWidget {
  const _ScopeBlockTotalsFooter({
    required this.subtotal,
    required this.formatMoney,
  });

  final double subtotal;
  final String Function(num) formatMoney;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppFonts.labelMedium(color: AppColors.muted).copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      fontSize: 10,
    );
    final valueStyle = AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BLOCK TOTAL', style: labelStyle),
                const SizedBox(height: 4),
                Text(formatMoney(subtotal), style: valueStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeQuoteGrandSummary extends StatelessWidget {
  const _ScopeQuoteGrandSummary({
    required this.grandTotal,
    required this.formatMoney,
  });

  final double grandTotal;
  final String Function(num) formatMoney;

  @override
  Widget build(BuildContext context) {
    const linkBlue = Color(0xFF1976D2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Grand Total',
              style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            formatMoney(grandTotal),
            style: AppFonts.bodyMedium(color: linkBlue).copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
