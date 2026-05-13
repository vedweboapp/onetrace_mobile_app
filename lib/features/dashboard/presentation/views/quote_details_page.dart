import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_bar_styles.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/theme/app_layout.dart';
import 'package:red5/core/widgets/app_screen_stack.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_provider.dart';
import 'package:red5/features/dashboard/data/quote_payload.dart';
import 'package:red5/features/dashboard/presentation/views/quote_composite_items_screen.dart';
import 'package:red5/features/dashboard/presentation/widgets/quote_info_row.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';
import 'package:red5/features/quote/presentation/views/quote_project_page.dart';

/// Full-screen quote CRM payload; opened via GoRouter at [pathFor].
class QuoteDetailsPage extends ConsumerStatefulWidget {
  const QuoteDetailsPage({super.key, required this.quoteId});

  final String quoteId;

  static const pathPrefix = '/quotes';
  static const name = 'quoteDetails';

  static String pathFor(String quoteId) =>
      '$pathPrefix/${Uri.encodeComponent(quoteId)}';

  @override
  ConsumerState<QuoteDetailsPage> createState() => _QuoteDetailsPageState();
}

class _QuoteDetailsPageState extends ConsumerState<QuoteDetailsPage> {
  QuotePayload? _payload;
  List<ProjectLevelItem> _levels = const [];
  String? _errorDetail;
  String? _levelsError;
  bool _loading = true;
  bool _isOpeningPdf = false;
  String? _selectedGroup;
  String? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorDetail = null;
      _payload = null;
    });
    try {
      final api = ref.read(crmQuotesApiProvider);
      final output = await api.fetchQuoteAppPayload(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _payload = QuotePayload.fromJson(output);
        _levels = const [];
        _levelsError = null;
        _loading = false;
        _errorDetail = null;
      });
      final projectId = (_payload?.quote.projectId ?? '').trim();
      if (projectId.isNotEmpty) {
        try {
          final api = ref.read(quoteProjectApiClientProvider);
          final levels = await api.fetchProjectLevels(projectId: projectId);
          if (!mounted) return;
          setState(() {
            _levels = levels;
            _levelsError = null;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _levels = const [];
            _levelsError = ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Could not load levels for this project.',
            );
          });
        }
      }
    } catch (e, st) {
      debugPrint('[QuoteDetails] load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _errorDetail = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: AppStrings.apiErrorLoadQuote,
        );
        _loading = false;
      });
    }
  }

  Future<void> _openPdf(BuildContext context, QuotePayload payload) async {
    if (_isOpeningPdf) return;
    setState(() => _isOpeningPdf = true);
    final q = payload.quote;
    final quoteLink =
        (q.workdrivePdfDownload?.trim().isNotEmpty ?? false)
        ? q.workdrivePdfDownload!
        : q.wardrivePdfLink;
    final levelLink = _levels.isNotEmpty ? _levels.first.drawingFile.trim() : '';
    final link = levelLink.isNotEmpty ? levelLink : (quoteLink ?? '').trim();
    if (link.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text('No drawing file/link found for this project.'),
        ),
      );
      if (mounted) setState(() => _isOpeningPdf = false);
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) {
      context.showTopSnackBar(const SnackBar(content: Text('Invalid PDF URL.')));
      if (mounted) setState(() => _isOpeningPdf = false);
      return;
    }
    try {
      if (!context.mounted) return;
      await context.push(
        QuoteProjectPage.path,
        extra: <String, dynamic>{
          'initialProjectId': (q.projectId ?? '').trim().isNotEmpty
              ? q.projectId!.trim()
              : widget.quoteId,
          'initialBlockName': q.quoteName,
          'initialPdfUrl': uri.toString(),
          'initialPdfName': _levels.isNotEmpty
              ? _levels.first.name
              : (q.quoteNumber.trim().isNotEmpty
                    ? '${q.quoteNumber}.pdf'
                    : 'quote.pdf'),
          'initialProducts': payload.products
              .map((p) => p.toPinSeedJson())
              .toList(),
        },
      );
    } finally {
      if (mounted) setState(() => _isOpeningPdf = false);
    }
  }

  String _safe(String? value) {
    if (value == null || value.trim().isEmpty) return '—';
    return value.trim();
  }

  List<String> _groupOptionsFor(QuotePayload payload) {
    final fromComposite = payload.compositeGroups
        .map((e) => e.title.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (fromComposite.isNotEmpty) {
      return fromComposite;
    }
    final fromProducts = payload.products
        .map((e) => (e.levels ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return fromProducts;
  }

  List<String> _productOptionsFor(QuotePayload payload) {
    final products = payload.products
        .map((e) => e.productName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return products;
  }

  List<QuoteLineProduct> _filteredProductsFor(QuotePayload payload) {
    var rows = List<QuoteLineProduct>.from(payload.products);
    final group = (_selectedGroup ?? '').trim();
    final product = (_selectedProduct ?? '').trim();

    if (group.isNotEmpty) {
      final selectedComposite = payload.compositeGroups.where(
        (g) => g.title.trim().toLowerCase() == group.toLowerCase(),
      );
      final namesInGroup = selectedComposite
          .expand((g) => g.items)
          .map((e) => e.name.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (namesInGroup.isNotEmpty) {
        rows = rows
            .where(
              (p) => namesInGroup.contains(p.productName.trim().toLowerCase()),
            )
            .toList();
      } else {
        rows = rows
            .where((p) => (p.levels ?? '').trim().toLowerCase() == group.toLowerCase())
            .toList();
      }
    }

    if (product.isNotEmpty) {
      rows = rows
          .where((p) => p.productName.trim().toLowerCase() == product.toLowerCase())
          .toList();
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final listTopPad = AppLayout.bodyTopBelowAppBar(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBarStyles.transparent(
          title: Text(
            'Quote',
            style: AppFonts.titleLarge(color: AppColors.inkStrong)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        body: AppScreenStack(
          child: AppSkeletonScreenBody(
            padding: EdgeInsets.fromLTRB(16, listTopPad, 16, 24),
            style: AppSkeletonScreenBodyStyle.listRows,
            listRowCount: 12,
            spacing: 0,
          ),
        ),
      );
    }
    if (_errorDetail != null) {
      return Scaffold(
        backgroundColor: AppColors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBarStyles.transparent(
          title: Text(
            'Quote',
            style: AppFonts.titleLarge(color: AppColors.inkStrong)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        body: AppScreenStack(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, listTopPad, 16, 24),
            children: [
              Text(
                'Failed to load quote',
                style: AppFonts.titleMedium(color: AppColors.ink).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorDetail!,
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final payload = _payload!;
    final q = payload.quote;
    final groupOptions = _groupOptionsFor(payload);
    final productOptions = _productOptionsFor(payload);
    final filteredProducts = _filteredProductsFor(payload);
    return Scaffold(
      backgroundColor: AppColors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBarStyles.transparent(
        title: Text(
          q.quoteName,
          style: AppFonts.titleLarge(color: AppColors.inkStrong)
              .copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: AppScreenStack(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, listTopPad, 16, 24),
          children: [
            Text(
              'Quote Information',
              style: AppFonts.headlineSmall(color: AppColors.ink).copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            QuoteInfoRow(label: 'Quote Name', value: q.quoteName),
            QuoteInfoRow(label: 'Quote Number', value: q.quoteNumber),
            QuoteInfoRow(label: 'Project ID', value: _safe(q.projectId)),
            QuoteInfoRow(label: 'Quote Stage', value: _safe(q.quoteStage)),
            QuoteInfoRow(label: 'Valid Until', value: _safe(q.validTill)),
            QuoteInfoRow(label: 'Property', value: _safe(q.property)),
            QuoteInfoRow(label: 'Door Survey', value: _safe(q.doorSurvey)),
            QuoteInfoRow(label: 'Deal Name', value: _safe(q.dealName)),
            QuoteInfoRow(label: 'Contact Name', value: _safe(q.contactName)),
            QuoteInfoRow(label: 'Created By', value: _safe(q.createdBy)),
            QuoteInfoRow(label: 'Modified By', value: _safe(q.modifiedBy)),
            QuoteInfoRow(label: 'Created At', value: _safe(q.createdAt)),
            QuoteInfoRow(label: 'Modified At', value: _safe(q.modifiedAt)),
            QuoteInfoRow(label: 'Deleted At', value: _safe(q.deletedAt)),
            QuoteInfoRow(label: 'Deleted By', value: _safe(q.deletedBy)),
            QuoteInfoRow(label: 'Is Deleted', value: _safe(q.isDeleted)),
            QuoteInfoRow(label: 'Layout', value: _safe(q.layout)),
            const SizedBox(height: 24),
            Text(
              'Levels (${_levels.length})',
              style: AppFonts.titleMedium(color: AppColors.ink).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            if ((_payload?.quote.projectId ?? '').trim().isEmpty)
              Text(
                'No project id found for this quote.',
                style: AppFonts.bodyMedium(color: AppColors.muted),
              )
            else if (_levelsError != null)
              Text(
                _levelsError!,
                style: AppFonts.bodyMedium(color: AppColors.muted),
              )
            else if (_levels.isEmpty)
              Text(
                'No levels found for this project.',
                style: AppFonts.bodyMedium(color: AppColors.muted),
              )
            else
              for (final level in _levels)
                Card(
                  elevation: 0,
                  color: AppColors.white,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.brandPrimaryContainer,
                      child: Icon(
                        Icons.layers_outlined,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    title: Text(
                      level.name,
                      style: AppFonts.titleSmall(color: AppColors.ink).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    subtitle: Text(
                      'Level ID: ${level.id} | Plots: ${level.plots.length} | Pins: ${level.plots.fold<int>(0, (acc, e) => acc + ((e['pins'] is List) ? (e['pins'] as List).length : 0))}',
                      style: AppFonts.bodySmall(color: AppColors.muted),
                    ),
                  ),
                ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isOpeningPdf ? null : () => _openPdf(context, payload),
                icon: _isOpeningPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_isOpeningPdf ? 'Opening...' : 'Get/Open File'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (payload.compositeGroups.isNotEmpty) ...[
              Card(
                elevation: 0,
                color: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.brandPrimaryContainer,
                    child: Icon(Icons.layers_outlined, color: AppColors.brandPrimary),
                  ),
                  title: Text(
                    'Composite item groups',
                    style: AppFonts.titleMedium(color: AppColors.ink)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${payload.compositeGroups.length} '
                    '${payload.compositeGroups.length == 1 ? 'group' : 'groups'} — open to view composite items',
                    style: AppFonts.bodyMedium(color: AppColors.muted)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedLight),
                  onTap: () {
                    context.push(
                      QuoteCompositeItemGroupsPage.path,
                      extra: <String, dynamic>{
                        'quoteTitle': q.quoteName,
                        'groups': payload.compositeGroups,
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'Products (${filteredProducts.length})',
              style: AppFonts.titleMedium(color: AppColors.ink).copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _PopupSelectTag(
                  label: 'GROUP',
                  placeholder: '— Select Group —',
                  options: groupOptions,
                  selected: _selectedGroup,
                  onChanged: (value) => setState(() => _selectedGroup = value),
                ),
                const SizedBox(width: 8),
                _PopupSelectTag(
                  label: 'PRODUCT',
                  placeholder: '— Select Product —',
                  options: productOptions,
                  selected: _selectedProduct,
                  onChanged: (value) => setState(() => _selectedProduct = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final p in filteredProducts)
              Card(
                elevation: 0,
                color: AppColors.white,
                child: ListTile(
                  title: Text(
                    p.productName,
                    style: AppFonts.titleSmall(color: AppColors.ink)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Level: ${_safe(p.levels)}  |  Plot: ${_safe(p.plots)}  |  Qty: ${p.quantity}',
                    style: AppFonts.bodySmall(color: AppColors.muted),
                  ),
                  trailing: Text(
                    '£${p.total.toStringAsFixed(2)}',
                    style: AppFonts.titleSmall(color: AppColors.ink)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}

class _PopupSelectTag extends StatelessWidget {
  const _PopupSelectTag({
    required this.label,
    required this.placeholder,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String placeholder;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final sel = selected?.trim();
    final hasSelection = sel != null && sel.isNotEmpty;
    final display = hasSelection ? sel : placeholder;
    final canPick = options.isNotEmpty;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: !canPick
            ? null
            : () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: const Color(0xFF1F2937),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(
                            children: [
                              const Icon(Icons.list_alt, color: Color(0xFF9CA3AF), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                placeholder,
                                style: AppFonts.titleMedium(color: Colors.white).copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFF374151)),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, color: Color(0xFF374151)),
                            itemBuilder: (context, i) {
                              final item = options[i];
                              final isSel = hasSelection && item == sel;
                              return ListTile(
                                title: Text(
                                  item,
                                  style: AppFonts.bodyMedium(color: Colors.white).copyWith(
                                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                                trailing: isSel
                                    ? const Icon(Icons.check, color: Color(0xFF34D399), size: 20)
                                    : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onChanged(item);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Text(
                '$label ',
                style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Expanded(
                child: Text(
                  canPick ? display : 'No options',
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.labelSmall(
                    color: hasSelection ? AppColors.ink : AppColors.mutedLight,
                  ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF6B7280)),
            ],
          ),
        ),
      ),
    );
  }
}
