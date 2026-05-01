import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_bar_styles.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_layout.dart';
import 'package:red5/core/widgets/app_screen_stack.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_provider.dart';
import 'package:red5/features/dashboard/data/quote_payload.dart';
import 'package:red5/features/dashboard/presentation/views/quote_composite_items_screen.dart';
import 'package:red5/features/dashboard/presentation/widgets/quote_info_row.dart';
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
  Object? _error;
  bool _loading = true;
  bool _isOpeningPdf = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _payload = null;
    });
    try {
      final api = ref.read(crmQuotesApiProvider);
      final output = await api.fetchQuoteAppPayload(widget.quoteId);
      if (!mounted) return;
      setState(() {
        _payload = QuotePayload.fromJson(output);
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      debugPrint('[QuoteDetails] load error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openPdf(BuildContext context, QuotePayload payload) async {
    if (_isOpeningPdf) return;
    setState(() => _isOpeningPdf = true);
    final q = payload.quote;
    final link =
        (q.workdrivePdfDownload?.trim().isNotEmpty ?? false)
        ? q.workdrivePdfDownload!
        : q.wardrivePdfLink;
    if (link == null || link.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No PDF download/link found in quote data.'),
        ),
      );
      if (mounted) setState(() => _isOpeningPdf = false);
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid PDF URL.')));
      if (mounted) setState(() => _isOpeningPdf = false);
      return;
    }
    try {
      if (!context.mounted) return;
      await context.push(
        QuoteProjectPage.path,
        extra: <String, dynamic>{
          'initialBlockName': q.quoteName,
          'initialPdfUrl': uri.toString(),
          'initialPdfName': q.quoteNumber.trim().isNotEmpty
              ? '${q.quoteNumber}.pdf'
              : 'quote.pdf',
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

  @override
  Widget build(BuildContext context) {
    final listTopPad = AppLayout.bodyTopBelowAppBar(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBarStyles.transparent(
          title: const Text('Quote', style: TextStyle(color: AppColors.inkStrong)),
        ),
        body: const AppScreenStack(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBarStyles.transparent(
          title: const Text('Quote', style: TextStyle(color: AppColors.inkStrong)),
        ),
        body: AppScreenStack(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, listTopPad, 16, 24),
            children: [
              Text(
                'Failed to load quote',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text('$_error', style: const TextStyle(color: AppColors.muted)),
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
    return Scaffold(
      backgroundColor: AppColors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBarStyles.transparent(title: Text(q.quoteName)),
      body: AppScreenStack(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, listTopPad, 16, 24),
          children: [
            const Text(
              'Quote Information',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 16),
            QuoteInfoRow(label: 'Quote Name', value: q.quoteName),
            QuoteInfoRow(label: 'Quote Number', value: q.quoteNumber),
            QuoteInfoRow(label: 'Quote Stage', value: _safe(q.quoteStage)),
            QuoteInfoRow(label: 'Valid Until', value: _safe(q.validTill)),
            QuoteInfoRow(label: 'Property', value: _safe(q.property)),
            QuoteInfoRow(label: 'Door Survey', value: _safe(q.doorSurvey)),
            QuoteInfoRow(label: 'Deal Name', value: _safe(q.dealName)),
            QuoteInfoRow(label: 'Contact Name', value: _safe(q.contactName)),
            QuoteInfoRow(label: 'Created By', value: _safe(q.createdBy)),
            QuoteInfoRow(label: 'Layout', value: _safe(q.layout)),
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
                  title: const Text(
                    'Composite item groups',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${payload.compositeGroups.length} '
                    '${payload.compositeGroups.length == 1 ? 'group' : 'groups'} — open to view composite items',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
              'Products (${payload.products.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            for (final p in payload.products)
              Card(
                elevation: 0,
                color: AppColors.white,
                child: ListTile(
                  title: Text(
                    p.productName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Level: ${_safe(p.levels)}  |  Plot: ${_safe(p.plots)}  |  Qty: ${p.quantity}',
                  ),
                  trailing: Text(
                    '£${p.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
