import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/quotations/presentation/widgets/quotation_map_block_sheet.dart';

/// One selectable line inside a plot / section row.
@immutable
class QuotationPlotLine {
  const QuotationPlotLine({
    this.selected = true,
    required this.label,
    this.quantityMultiplier,
    this.amount = 0,
    this.designPins = const [],
    this.plotId,
  });

  final bool selected;
  final String label;
  /// When non-null, label is shown as `Label (xN)` in the UI (pin count from level API).
  final int? quantityMultiplier;
  final double amount;
  /// Pins from `project/{id}/level/` for this plot (shown in the map bottom sheet).
  final List<QuotationDesignPin> designPins;
  /// Plot PK from level API (`plots[].id`).
  final String? plotId;

  QuotationPlotLine copyWith({
    bool? selected,
    String? label,
    int? quantityMultiplier,
    double? amount,
    List<QuotationDesignPin>? designPins,
    String? plotId,
  }) {
    return QuotationPlotLine(
      selected: selected ?? this.selected,
      label: label ?? this.label,
      quantityMultiplier: quantityMultiplier ?? this.quantityMultiplier,
      amount: amount ?? this.amount,
      designPins: designPins ?? this.designPins,
      plotId: plotId ?? this.plotId,
    );
  }
}

/// A named group under a block (e.g. "No Plot").
@immutable
class QuotationPlotGroup {
  const QuotationPlotGroup({
    required this.name,
    required this.lines,
    this.levelId,
  });

  final String name;
  final List<QuotationPlotLine> lines;
  /// Level PK from `GET project/{id}/level/` when this block was built from API data.
  final String? levelId;

  QuotationPlotGroup copyWith({
    String? name,
    List<QuotationPlotLine>? lines,
    String? levelId,
  }) {
    return QuotationPlotGroup(
      name: name ?? this.name,
      lines: lines ?? this.lines,
      levelId: levelId ?? this.levelId,
    );
  }
}

/// Section name row + one expandable card per [QuotationPlotGroup] (e.g. one API level = one block).
class QuotationBlockSectionsPanel extends StatelessWidget {
  const QuotationBlockSectionsPanel({
    super.key,
    required this.blockNameController,
    required this.sectionNameController,
    required this.plotGroups,
    required this.blockExpandedList,
    required this.onBlockExpandedAt,
    required this.onAddSection,
    required this.onLineSelectionChanged,
    required this.onRemovePlotGroup,
    required this.submitting,
  });

  final TextEditingController blockNameController;
  final TextEditingController sectionNameController;
  final List<QuotationPlotGroup> plotGroups;
  /// Length must match [plotGroups]; each entry is the expanded flag for that block card.
  final List<bool> blockExpandedList;
  final void Function(int blockIndex, bool expanded) onBlockExpandedAt;
  final VoidCallback onAddSection;
  final void Function(int groupIndex, int lineIndex, bool selected) onLineSelectionChanged;
  final ValueChanged<int> onRemovePlotGroup;
  final bool submitting;

  static final NumberFormat _gbp = NumberFormat.currency(locale: 'en_GB', symbol: '£');

  static List<QuotationPlotGroup> defaultPlotGroups() {
    return const [
      QuotationPlotGroup(
        name: 'No Plot',
        lines: [
          QuotationPlotLine(
            label: 'Quotation Map',
            quantityMultiplier: 4,
            amount: 0,
          ),
          QuotationPlotLine(label: 'Quotation Map', amount: 0),
          QuotationPlotLine(label: 'Quotation Map', amount: 0),
        ],
      ),
    ];
  }

  static QuotationPlotGroup emptyGroupFromSectionName(String name) {
    return QuotationPlotGroup(
      name: name.trim().isEmpty ? 'Section' : name.trim(),
      lines: const [
        QuotationPlotLine(label: 'Quotation Map', amount: 0),
      ],
    );
  }

  static double _sumSelectedForGroup(QuotationPlotGroup g) {
    var sum = 0.0;
    for (final l in g.lines) {
      if (l.selected) sum += l.amount;
    }
    return sum;
  }

  String _lineTitle(QuotationPlotLine line) {
    if (line.quantityMultiplier != null && line.quantityMultiplier! > 0) {
      return 'Quotation Map (x${line.quantityMultiplier})';
    }
    return 'Quotation Map';
  }

  @override
  Widget build(BuildContext context) {
    final expandedFlags = blockExpandedList.length == plotGroups.length
        ? blockExpandedList
        : List<bool>.filled(plotGroups.length, true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Block Name'),
        const SizedBox(height: 8),
        AppTextField(
          controller: blockNameController,
          hintText: 'Block name',
          textInputAction: TextInputAction.next,
          enabled: !submitting,
        ),
        const SizedBox(height: 16),
        _label('Section Name'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: sectionNameController,
                hintText: 'Section name',
                textInputAction: TextInputAction.done,
                enabled: !submitting,
                onSubmitted: (_) => onAddSection(),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: TextButton(
                onPressed: submitting ? null : onAddSection,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                child: Text(
                  '+ ADD',
                  style: AppFonts.labelMedium(color: const Color(0xFF1976D2)).copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (plotGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              'No plots with pins found for this project. Add pins on the project drawing levels first.',
              style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
                fontSize: 13,
                height: 1.4,
              ),
            ),
          )
        else
        for (var i = 0; i < plotGroups.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final g = plotGroups[i];
              final subtotal = _sumSelectedForGroup(g);
              const tax = 0.0;
              final total = subtotal + tax;
              return _BlockCard(
                blockNameController: blockNameController,
                headerTitleOverride: g.name.trim().isEmpty ? null : g.name.trim(),
                expanded: expandedFlags[i],
                onExpandedChanged: (v) => onBlockExpandedAt(i, v),
                plotGroups: [g],
                submitting: submitting,
                onLineSelectionChanged: (localGi, li, sel) =>
                    onLineSelectionChanged(i, li, sel),
                onRemovePlotGroup: (_) => onRemovePlotGroup(i),
                lineTitle: _lineTitle,
                formatMoney: _gbp.format,
                subtotal: subtotal,
                tax: tax,
                total: total,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.blockNameController,
    this.headerTitleOverride,
    required this.expanded,
    required this.onExpandedChanged,
    required this.plotGroups,
    required this.submitting,
    required this.onLineSelectionChanged,
    required this.onRemovePlotGroup,
    required this.lineTitle,
    required this.formatMoney,
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  final TextEditingController blockNameController;
  /// When set, shown as the card title instead of [blockNameController] text.
  final String? headerTitleOverride;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final List<QuotationPlotGroup> plotGroups;
  final bool submitting;
  final void Function(int groupIndex, int lineIndex, bool selected) onLineSelectionChanged;
  final ValueChanged<int> onRemovePlotGroup;
  final String Function(QuotationPlotLine) lineTitle;
  final String Function(num) formatMoney;
  final double subtotal;
  final double tax;
  final double total;

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: AppColors.borderLight);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: border,
        boxShadow: [
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
              onTap: submitting ? null : () => onExpandedChanged(!expanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.drag_indicator,
                      color: AppColors.muted.withValues(alpha: 0.85),
                      size: 26,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: headerTitleOverride != null
                          ? Text(
                              headerTitleOverride!.isEmpty
                                  ? (blockNameController.text.trim().isEmpty
                                        ? 'Block Name'
                                        : blockNameController.text.trim())
                                  : headerTitleOverride!,
                              textAlign: TextAlign.center,
                              style: AppFonts.titleMedium(
                                color: AppColors.inkStrong,
                              ).copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: (headerTitleOverride!.isEmpty &&
                                        blockNameController.text.trim().isEmpty)
                                    ? AppColors.muted
                                    : AppColors.inkStrong,
                              ),
                            )
                          : AnimatedBuilder(
                              animation: blockNameController,
                              builder: (context, _) {
                                final t = blockNameController.text.trim();
                                return Text(
                                  t.isEmpty ? 'Block Name' : t,
                                  textAlign: TextAlign.center,
                                  style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: t.isEmpty ? AppColors.muted : AppColors.inkStrong,
                                  ),
                                );
                              },
                            ),
                    ),
                    PopupMenuButton<void>(
                      enabled: !submitting,
                      icon: Icon(Icons.more_vert, color: AppColors.muted.withValues(alpha: 0.9)),
                      padding: EdgeInsets.zero,
                      itemBuilder: (context) => const [
                        PopupMenuItem<void>(
                          child: Text('Block options'),
                        ),
                      ],
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.inkStrong,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, thickness: 1, color: AppColors.borderLight.withValues(alpha: 0.9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var gi = 0; gi < plotGroups.length; gi++) ...[
                        if (gi > 0)
                          Divider(
                            height: 1,
                            color: AppColors.borderLight.withValues(alpha: 0.7),
                          ),
                        for (var li = 0; li < plotGroups[gi].lines.length; li++) ...[
                          if (li > 0)
                            Divider(
                              height: 1,
                              color: AppColors.borderLight.withValues(alpha: 0.5),
                            ),
                          _PlotHeader(
                            name: plotGroups[gi].lines[li].label,
                            canRemove: false,
                            submitting: submitting,
                            onRemove: () {},
                          ),
                          _LineRow(
                            selected: plotGroups[gi].lines[li].selected,
                            title: lineTitle(plotGroups[gi].lines[li]),
                            line: plotGroups[gi].lines[li],
                            plotGroupName: plotGroups[gi].name,
                            blockNameController: blockNameController,
                            amount: plotGroups[gi].lines[li].amount,
                            formatMoney: formatMoney,
                            enabled: !submitting,
                            onChanged: (v) => onLineSelectionChanged(gi, li, v),
                          ),
                        ],
                        if (plotGroups[gi].lines.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No plots on this level yet.',
                              style: AppFonts.bodySmall(color: AppColors.muted),
                            ),
                          ),
                      ],
                      _TotalsFooter(
                        subtotal: subtotal,
                        tax: tax,
                        total: total,
                        formatMoney: formatMoney,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlotHeader extends StatelessWidget {
  const _PlotHeader({
    required this.name,
    required this.canRemove,
    required this.submitting,
    required this.onRemove,
  });

  final String name;
  final bool canRemove;
  final bool submitting;
  final VoidCallback onRemove;

  static const _linkBlue = Color(0xFF1976D2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Material(
            color: _linkBlue,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: (!canRemove || submitting) ? null : onRemove,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.remove,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.selected,
    required this.title,
    required this.line,
    required this.plotGroupName,
    required this.blockNameController,
    required this.amount,
    required this.formatMoney,
    required this.enabled,
    required this.onChanged,
  });

  final bool selected;
  final String title;
  final QuotationPlotLine line;
  final String plotGroupName;
  final TextEditingController blockNameController;
  final double amount;
  final String Function(num) formatMoney;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  static const _linkBlue = Color(0xFF1976D2);

  bool get _lineHasPins => (line.quantityMultiplier ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppFonts.bodyMedium(color: _linkBlue).copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );
    final titleWidget = Text(title, style: titleStyle);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: selected,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return _linkBlue;
                return null;
              }),
              checkColor: AppColors.white,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          Expanded(
            child: _lineHasPins
                ? Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: enabled
                          ? () {
                              showQuotationMapBlockSheet(
                                context,
                                blockNameController: blockNameController,
                                plotGroupName: plotGroupName,
                                pinCount: line.quantityMultiplier!,
                                sheetTitle: line.label,
                                designPins: line.designPins,
                              );
                            }
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: titleWidget,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: titleWidget,
                  ),
          ),
          Text(
            formatMoney(amount),
            style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsFooter extends StatelessWidget {
  const _TotalsFooter({
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.formatMoney,
  });

  final double subtotal;
  final double tax;
  final double total;
  final String Function(num) formatMoney;

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppFonts.labelMedium(color: AppColors.muted).copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      fontSize: 10,
    );
    final valueStyle = AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );
    final totalStyle = valueStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 15);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border(
          top: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.85)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SUB TOTAL', style: labelStyle),
                const SizedBox(height: 4),
                Text(formatMoney(subtotal), style: valueStyle),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('TAX', style: labelStyle),
                const SizedBox(height: 4),
                Text(formatMoney(tax), style: valueStyle),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('TOTAL', style: labelStyle),
                const SizedBox(height: 4),
                Text(formatMoney(total), style: totalStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
