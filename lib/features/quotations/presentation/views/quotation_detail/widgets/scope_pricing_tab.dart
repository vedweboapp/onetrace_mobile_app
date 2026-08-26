part of '../quotation_detail.dart';

/// Scope & pricing tab — project, collapsible quote sections / plots / pins.
class _ScopePricingTab extends StatefulWidget {
  const _ScopePricingTab({required this.detail});

  final QuotationDetailModel detail;

  @override
  State<_ScopePricingTab> createState() => _ScopePricingTabState();
}

class _ScopePricingTabState extends State<_ScopePricingTab> {
  static final NumberFormat _gbp = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
  );

  String _fmt(num n) => _gbp.format(n);

  final Set<int> _expandedSections = <int>{0};
  final Set<String> _expandedPlots = <String>{};

  String _plotKey(int sectionIndex, int plotIndex) =>
      '$sectionIndex-$plotIndex';

  @override
  Widget build(BuildContext context) {
    const labelGrey = Color(0xFF9CA3AF);

    final detail = widget.detail;
    final quoteSections = _parseQuoteSections(detail);
    final legacyBlocks = quoteSections.isEmpty
        ? _parseLegacyBlocks(detail)
        : const <_ScopeParsedBlock>[];

    final hasQuoteTree = quoteSections.isNotEmpty;
    final hasLegacy = legacyBlocks.isNotEmpty;

    final grandTotal = hasQuoteTree
        ? quoteSections.fold<double>(
            0,
            (sum, s) => sum + s.sectionTotal,
          )
        : _ScopeTotals.fromLineItems(_legacyLineItems(legacyBlocks)).grandTotal;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          'Project',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18, height: 1.2),
        ),
        const SizedBox(height: 8),
        Text(
          detail.projectLabel,
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 24),
        Text(
          'BLOCKS',
          style: AppFonts.labelMedium(color: labelGrey).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.55,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 10),
        if (!hasQuoteTree && !hasLegacy)
          Text(
            'No scope & pricing data for this quotation yet.',
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(fontSize: 15, height: 1.45),
          )
        else if (hasQuoteTree) ...[
          for (var si = 0; si < quoteSections.length; si++) ...[
            if (si > 0) const SizedBox(height: 12),
            _ScopeSectionCard(
              section: quoteSections[si],
              expanded: _expandedSections.contains(si),
              onExpandedChanged: (v) {
                setState(() {
                  if (v) {
                    _expandedSections.add(si);
                  } else {
                    _expandedSections.remove(si);
                  }
                });
              },
              formatMoney: _fmt,
              plotExpanded: (plotIndex) =>
                  _expandedPlots.contains(_plotKey(si, plotIndex)),
              onPlotExpandedChanged: (plotIndex, v) {
                setState(() {
                  final key = _plotKey(si, plotIndex);
                  if (v) {
                    _expandedPlots.add(key);
                  } else {
                    _expandedPlots.remove(key);
                  }
                });
              },
            ),
          ],
        ] else
          for (final pb in legacyBlocks) ...[
            for (final sec in pb.sections) ...[
              _ScopeQuotedItemsTitle(
                barColor: const Color(0xFF1976D2),
                title: _quotedItemsHeading(sec.name),
              ),
              const SizedBox(height: 12),
              if (sec.lines.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No line items in this section.',
                    style: AppFonts.bodySmall(color: AppColors.muted),
                  ),
                )
              else
                for (final line in sec.lines) ...[
                  _ScopeQuotedLineCard(line: line, formatMoney: _fmt),
                  const SizedBox(height: 12),
                ],
            ],
          ],
        if (hasQuoteTree || hasLegacy) ...[
          const SizedBox(height: 20),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderLight.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 4),
          if (hasQuoteTree)
            _ScopeQuoteGrandSummary(
              grandTotal: grandTotal,
              formatMoney: _fmt,
            )
          else
            _ScopePricingSummary(
              totals: _ScopeTotals.fromLineItems(_legacyLineItems(legacyBlocks)),
              formatMoney: _fmt,
              linkBlue: const Color(0xFF1976D2),
            ),
        ],
      ],
    );
  }

  static String _quotedItemsHeading(String sectionName) {
    final sec = sectionName.trim();
    if (sec.isEmpty) return 'Quoted Items — No Block';
    if (sec.toLowerCase() == 'no plot') return 'Quoted Items — No Block';
    return 'Quoted Items — $sec';
  }

  static List<Map<String, dynamic>> _legacyLineItems(
    List<_ScopeParsedBlock> blocks,
  ) {
    final allLineMaps = <Map<String, dynamic>>[];
    for (final pb in blocks) {
      for (final sec in pb.sections) {
        allLineMaps.addAll(sec.lines);
      }
    }
    return allLineMaps;
  }

  static List<_ScopeParsedBlock> _parseLegacyBlocks(QuotationDetailModel detail) {
    final parsedBlocks = <_ScopeParsedBlock>[];
    for (final raw in detail.rawBlocks) {
      final m = _scopeAsMap(raw);
      if (m.isEmpty) continue;
      parsedBlocks.add(_ScopeParsedBlock.fromMap(m));
    }
    return parsedBlocks;
  }

  static List<_QuoteSectionVm> _parseQuoteSections(QuotationDetailModel detail) {
    final sections = <_QuoteSectionVm>[];
    for (final raw in detail.quoteSectionsRaw) {
      final m = _scopeAsMap(raw);
      if (m.isEmpty) continue;
      sections.add(_QuoteSectionVm.fromMap(m));
    }
    sections.sort((a, b) => a.sectionOrder.compareTo(b.sectionOrder));
    return sections;
  }
}
