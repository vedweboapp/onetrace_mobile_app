part of 'quotation_detail.dart';

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
    final title = _detail?.listTitle ?? 'Quote';

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
