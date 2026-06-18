import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/quotations/data/quotation_models.dart';
import 'package:red5/features/quotations/data/quotations_api_client.dart';
import 'package:url_launcher/url_launcher.dart';

/// `GET /api/v1/quotations/{id}/` — read-only detail (Overview + Scope & pricing).
class QuotationDetailPage extends ConsumerStatefulWidget {
  const QuotationDetailPage({super.key, required this.quotationId});

  static const pathPrefix = '/quotations';
  static const name = 'quotation-detail';

  static String pathFor(String id) =>
      '$pathPrefix/${Uri.encodeComponent(id.trim())}';

  final String quotationId;

  @override
  ConsumerState<QuotationDetailPage> createState() =>
      _QuotationDetailPageState();
}

class _QuotationDetailPageState extends ConsumerState<QuotationDetailPage>
    with SingleTickerProviderStateMixin {
  QuotationDetailModel? _detail;
  bool _loading = true;
  String? _error;
  late final TabController _tabController;
  bool _descriptionExpanded = false;

  static const _labelGrey = Color(0xFF9CA3AF);
  static const _readMoreThreshold = 180;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.quotationId.trim();
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Invalid quotation id';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(quotationsApiClientProvider);
      final d = await api.fetchQuotationDetail(id);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
        _descriptionExpanded = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load quotation',
        );
      });
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete quotation?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(quotationsApiClientProvider)
          .deleteQuotation(widget.quotationId.trim());
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Delete failed',
            ),
          ),
        ),
      );
    }
  }

  void _onDuplicateQuotation() {
    if (!mounted) return;
    context.showTopSnackBar(
      const SnackBar(content: Text('Duplicate is not available yet.')),
    );
  }

  void _onDuplicateManyQuotations() {
    if (!mounted) return;
    context.showTopSnackBar(
      const SnackBar(content: Text('Duplicate many is not available yet.')),
    );
  }

  Future<void> _exportToPdf() async {
    final d = _detail;
    if (d == null) return;
    final url = d.exportPdfUrl;
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(
          content: Text('No PDF link is available for this quotation yet.'),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(content: Text('Invalid PDF URL.')),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!launched) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Could not open the PDF link.')),
      );
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 12),
      child: Text(
        title,
        style: AppFonts.titleMedium(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: AppFonts.labelMedium(color: _labelGrey).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.45,
        fontSize: 10,
      ),
    );
  }

  Widget _fieldValue(String value) {
    final t = value.trim();
    return Text(
      t.isEmpty || t == '—' ? '—' : t,
      style: AppFonts.bodyMedium(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w500, fontSize: 16, height: 1.35),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          const SizedBox(height: 5),
          _fieldValue(value),
        ],
      ),
    );
  }

  Widget _tagsBlock(QuotationDetailModel d) {
    final chips = d.tagChips;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Tags'),
          const SizedBox(height: 10),
          if (chips.isEmpty)
            _fieldValue(d.tags)
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: chips.map((c) => _TagChipPill(chip: c)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _descriptionBlock(QuotationDetailModel d) {
    final text = d.description.trim();
    if (text.isEmpty || text == '—') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_sectionTitle('Description'), _fieldValue('—')],
        ),
      );
    }
    final long = text.length > _readMoreThreshold;
    final shown = _descriptionExpanded || !long
        ? text
        : '${text.substring(0, _readMoreThreshold).trim()}…';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Description'),
          Text(
            shown,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w500, fontSize: 15, height: 1.5),
          ),
          if (long)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                foregroundColor: const Color(0xFF1976D2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () =>
                  setState(() => _descriptionExpanded = !_descriptionExpanded),
              child: Text(
                _descriptionExpanded ? 'Read less' : 'Read more',
                style: AppFonts.bodySmall(
                  color: const Color(0xFF1976D2),
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _overviewBody(QuotationDetailModel d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        _sectionTitle('Basic Info'),
        _row('Quote name', d.quoteName),
        _row('Project name', d.projectLabel),
        _row('Client', d.clientLabel),
        _row('Sites', d.siteLabel),
        _row('Cost centre', d.costCentreDisplay),
        _sectionTitle('Contact'),
        _row('Primary customer contact', d.primaryContact),
        _row('Secondary customer contact', d.secondaryContact),
        _row('Site contact', d.siteContact),
        _sectionTitle('Additional information'),
        _tagsBlock(d),
        _row('Order no.', d.orderNo),
        _row('Due date', d.dueDateDisplay),
        _row('Project manager', d.projectManager),
        _row('Technicians', d.technicians),
        _row('Sales person', d.salesPerson),
        _descriptionBlock(d),
      ],
    );
  }

  Widget _scopeBody(QuotationDetailModel d) {
    return _ScopePricingTab(detail: d);
  }

  Widget _exportButton() {
    return Material(
      color: AppColors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _exportToPdf,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Export to Pdf',
                style: AppFonts.titleMedium(
                  color: AppColors.white,
                ).copyWith(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _detail?.quoteName ?? 'Quote Name';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (!_loading && _error == null && _detail != null)
            Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.black12,
                highlightColor: Colors.transparent,
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.inkStrong),
                color: AppColors.white,
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                surfaceTintColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                menuPadding: const EdgeInsets.symmetric(vertical: 8),
                offset: const Offset(0, 44),
                constraints: const BoxConstraints(minWidth: 200),
                onSelected: (value) {
                  switch (value) {
                    case 'duplicate':
                      _onDuplicateQuotation();
                      break;
                    case 'duplicate_many':
                      _onDuplicateManyQuotations();
                      break;
                    case 'delete':
                      _confirmDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'duplicate',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      'Duplicate',
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'duplicate_many',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      'Duplicate Many',
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
                    ),
                  ),
                  const PopupMenuDivider(
                    height: 1,
                    thickness: 1,
                    indent: 12,
                    endIndent: 12,
                    color: Color(0xFFE5E7EB),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 22,
                          color: const Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: AppFonts.bodyMedium(
                            color: const Color(0xFFB91C1C),
                          ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_loading && _error == null && _detail != null)
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  labelColor: AppColors.inkStrong,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.inkStrong,
                  indicatorWeight: 2.2,
                  labelStyle: AppFonts.labelMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                  unselectedLabelStyle: AppFonts.labelMedium(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Scope & pricing'),
                  ],
                ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
            ],
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: const AppSkeletonScreenBody(
                scrollable: false,
                toastBlockCount: 4,
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _detail == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_overviewBody(_detail!), _scopeBody(_detail!)],
                  ),
                ),
                _exportButton(),
              ],
            ),
    );
  }
}

double _scopeParseDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(RegExp(r'[£€,\s]'), '').trim();
  return double.tryParse(s) ?? 0;
}

Map<String, dynamic> _scopeAsMap(dynamic raw) {
  if (raw is Map) {
    return Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return const {};
}

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

@immutable
class _QuoteSectionVm {
  const _QuoteSectionVm({
    required this.name,
    required this.sectionOrder,
    required this.sectionTotal,
    required this.plots,
    this.levelId,
  });

  final String name;
  final int sectionOrder;
  final double sectionTotal;
  final int? levelId;
  final List<_QuotePlotVm> plots;

  factory _QuoteSectionVm.fromMap(Map<String, dynamic> m) {
    final plots = <_QuotePlotVm>[];
    final rawPlots = m['plots'];
    if (rawPlots is List) {
      for (final p in rawPlots) {
        plots.add(_QuotePlotVm.fromMap(_scopeAsMap(p)));
      }
    }
    plots.sort((a, b) => a.plotOrder.compareTo(b.plotOrder));
    return _QuoteSectionVm(
      name: (m['name'] ?? 'Block').toString().trim().isEmpty
          ? 'Block'
          : (m['name'] ?? 'Block').toString().trim(),
      sectionOrder: _scopeParseInt(m['section_order']),
      sectionTotal: _scopeParseDouble(m['section_total']),
      levelId: _scopeParseIntOrNull(m['level_id']),
      plots: plots,
    );
  }
}

@immutable
class _QuotePlotVm {
  const _QuotePlotVm({
    required this.name,
    required this.plotOrder,
    required this.plotTotal,
    required this.pins,
    this.plotId,
  });

  final String name;
  final int plotOrder;
  final double plotTotal;
  final int? plotId;
  final List<_QuotePinVm> pins;

  factory _QuotePlotVm.fromMap(Map<String, dynamic> m) {
    final pins = <_QuotePinVm>[];
    final rawPins = m['pins'];
    if (rawPins is List) {
      for (final p in rawPins) {
        pins.add(_QuotePinVm.fromMap(_scopeAsMap(p)));
      }
    }
    pins.sort((a, b) => a.pinsOrder.compareTo(b.pinsOrder));
    return _QuotePlotVm(
      name: (m['name'] ?? 'Plot').toString().trim().isEmpty
          ? 'Plot'
          : (m['name'] ?? 'Plot').toString().trim(),
      plotOrder: _scopeParseInt(m['plot_order']),
      plotTotal: _scopeParseDouble(m['plot_total']),
      plotId: _scopeParseIntOrNull(m['plot_id']),
      pins: pins,
    );
  }
}

@immutable
class _QuotePinVm {
  const _QuotePinVm({
    required this.name,
    required this.pinsOrder,
    required this.quantity,
    required this.sellingPrice,
    required this.pinsTotal,
    required this.isComposite,
    required this.compositeItems,
    this.pinId,
    this.compositeItemId,
  });

  final String name;
  final int pinsOrder;
  final int quantity;
  final double sellingPrice;
  final double pinsTotal;
  final bool isComposite;
  final int? pinId;
  final int? compositeItemId;
  final List<_QuoteCompositeItemVm> compositeItems;

  factory _QuotePinVm.fromMap(Map<String, dynamic> m) {
    final compositeItems = <_QuoteCompositeItemVm>[];
    final rawChildren = m['composite_items'];
    if (rawChildren is List) {
      for (final c in rawChildren) {
        compositeItems.add(_QuoteCompositeItemVm.fromMap(_scopeAsMap(c)));
      }
    }
    return _QuotePinVm(
      name: (m['name'] ?? 'Quoted item').toString().trim().isEmpty
          ? 'Quoted item'
          : (m['name'] ?? 'Quoted item').toString().trim(),
      pinsOrder: _scopeParseInt(m['pins_order']),
      quantity: _scopeParseInt(m['quantity'], fallback: 1),
      sellingPrice: _scopeParseDouble(m['selling_price']),
      pinsTotal: _scopeParseDouble(m['pins_total']),
      isComposite: m['is_composite'] == true,
      pinId: _scopeParseIntOrNull(m['pin_id']),
      compositeItemId: _scopeParseIntOrNull(m['composite_item_id']),
      compositeItems: compositeItems,
    );
  }
}

@immutable
class _QuoteCompositeItemVm {
  const _QuoteCompositeItemVm({
    required this.childItemName,
    required this.quantity,
    this.childItemId,
  });

  final String childItemName;
  final int quantity;
  final int? childItemId;

  factory _QuoteCompositeItemVm.fromMap(Map<String, dynamic> m) {
    return _QuoteCompositeItemVm(
      childItemName:
          (m['child_item_name'] ?? m['name'] ?? 'Item').toString().trim(),
      quantity: _scopeParseInt(m['quantity'], fallback: 1),
      childItemId: _scopeParseIntOrNull(m['child_item_id']),
    );
  }
}

int _scopeParseInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? fallback;
}

int? _scopeParseIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

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

class _ScopeParsedBlock {
  _ScopeParsedBlock({required this.name, required this.sections});

  final String name;
  final List<_ScopeParsedSection> sections;

  factory _ScopeParsedBlock.fromMap(Map<String, dynamic> m) {
    final name = (m['name'] ?? '').toString().trim();
    final rawSecs = m['sections'];
    final sections = <_ScopeParsedSection>[];
    if (rawSecs is List) {
      for (final s in rawSecs) {
        sections.add(_ScopeParsedSection.fromMap(_scopeAsMap(s)));
      }
    }
    if (sections.isEmpty) {
      sections.add(_ScopeParsedSection(name: '', lines: const []));
    }
    return _ScopeParsedBlock(
      name: name.isEmpty ? 'Block' : name,
      sections: sections,
    );
  }
}

class _ScopeParsedSection {
  _ScopeParsedSection({required this.name, required this.lines});

  final String name;
  final List<Map<String, dynamic>> lines;

  factory _ScopeParsedSection.fromMap(Map<String, dynamic> m) {
    final name = (m['name'] ?? 'Section').toString().trim();
    final rawItems = m['line_items'] ?? m['items'] ?? m['lines'];
    final lines = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        final im = _scopeAsMap(it);
        if (im.isNotEmpty) lines.add(im);
      }
    }
    return _ScopeParsedSection(
      name: name.isEmpty ? 'Section' : name,
      lines: lines,
    );
  }
}

class _ScopeTotals {
  const _ScopeTotals({
    required this.subTotal,
    required this.discount,
    required this.tax,
    required this.adjustment,
    required this.grandTotal,
  });

  final double subTotal;
  final double discount;
  final double tax;
  final double adjustment;
  final double grandTotal;

  factory _ScopeTotals.fromLineItems(List<Map<String, dynamic>> items) {
    var listSub = 0.0;
    var disc = 0.0;
    var tax = 0.0;
    var gross = 0.0;
    for (final m in items) {
      disc += _scopeParseDouble(m['discount'] ?? m['discount_amount']);
      tax += _scopeParseDouble(m['tax'] ?? m['tax_amount']);
      final qtyRaw = _scopeParseDouble(m['quantity'] ?? m['qty']);
      final qty = qtyRaw > 0 ? qtyRaw : 1.0;
      final list = _scopeParseDouble(
        m['list_price'] ?? m['listPrice'] ?? m['unit_price'],
      );
      final amt = _scopeParseDouble(m['amount']);
      final tot = _scopeParseDouble(m['total'] ?? m['line_total']);

      if (list > 0) {
        listSub += list * qty;
      } else if (amt > 0) {
        listSub += amt;
      } else {
        listSub += tot;
      }

      if (tot > 0) {
        gross += tot;
      } else if (amt > 0) {
        gross += amt;
      } else if (list > 0) {
        gross += list * qty;
      }
    }
    const adjustment = 0.0;
    final subDisplay = listSub > 0 ? listSub : gross;
    final grand = (gross - disc + tax + adjustment).clamp(0.0, double.infinity);
    return _ScopeTotals(
      subTotal: subDisplay,
      discount: disc,
      tax: tax,
      adjustment: adjustment,
      grandTotal: grand,
    );
  }
}

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
