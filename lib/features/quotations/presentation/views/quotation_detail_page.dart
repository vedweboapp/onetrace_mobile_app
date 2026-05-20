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

/// Scope & pricing tab — Project, block name, quoted item cards, summary.
class _ScopePricingTab extends StatelessWidget {
  const _ScopePricingTab({required this.detail});

  final QuotationDetailModel detail;

  static final NumberFormat _gbp = NumberFormat.currency(
    locale: 'en_GB',
    symbol: '£',
  );

  String _fmt(num n) => _gbp.format(n);

  static String _quotedItemsHeading(String sectionName) {
    final sec = sectionName.trim();
    if (sec.isEmpty) return 'Quoted Items — No Block';
    if (sec.toLowerCase() == 'no plot') return 'Quoted Items — No Block';
    return 'Quoted Items — $sec';
  }

  @override
  Widget build(BuildContext context) {
    const labelGrey = Color(0xFF9CA3AF);
    const barBlue = Color(0xFF1976D2);

    final blocks = detail.rawBlocks;
    final parsedBlocks = <_ScopeParsedBlock>[];
    for (final raw in blocks) {
      final m = _scopeAsMap(raw);
      if (m.isEmpty) continue;
      parsedBlocks.add(_ScopeParsedBlock.fromMap(m));
    }

    final blockBoxName = parsedBlocks.isEmpty
        ? '—'
        : (parsedBlocks.first.name.trim().isEmpty
              ? '—'
              : parsedBlocks.first.name.trim());

    final allLineMaps = <Map<String, dynamic>>[];
    for (final pb in parsedBlocks) {
      for (final sec in pb.sections) {
        allLineMaps.addAll(sec.lines);
      }
    }
    final totals = _ScopeTotals.fromLineItems(allLineMaps);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          'Project',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18, height: 1.2),
        ),
        const SizedBox(height: 14),
        Text(
          'BLOCK NAME',
          style: AppFonts.labelMedium(color: labelGrey).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.55,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            blockBoxName,
            style: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        const SizedBox(height: 28),
        if (parsedBlocks.isEmpty) ...[
          _ScopeQuotedItemsTitle(
            barColor: barBlue,
            title: _quotedItemsHeading(''),
          ),
          const SizedBox(height: 12),
          Text(
            'No scope & pricing data for this quotation yet.',
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(fontSize: 15, height: 1.45),
          ),
        ] else
          for (final pb in parsedBlocks) ...[
            for (final sec in pb.sections) ...[
              _ScopeQuotedItemsTitle(
                barColor: barBlue,
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
        if (parsedBlocks.isNotEmpty) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderLight.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 4),
          _ScopePricingSummary(
            totals: totals,
            formatMoney: _fmt,
            linkBlue: const Color(0xFF1976D2),
          ),
        ],
      ],
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
