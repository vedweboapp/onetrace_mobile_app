import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_bar_styles.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_layout.dart';
import 'package:red5/core/widgets/app_screen_stack.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_provider.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/dashboard/presentation/views/quote_composite_items_screen.dart';
import 'package:red5/features/dashboard/presentation/views/quote_details_page.dart';
import 'package:red5/features/dashboard/presentation/widgets/quote_list_card.dart';
import 'package:red5/features/dashboard/presentation/widgets/quote_list_feedback_cards.dart';
import 'package:red5/features/dashboard/presentation/widgets/quote_pagination_bar.dart';
import 'package:red5/features/quote/presentation/views/quote_project_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  static const path = '/dashboard';
  static const name = 'dashboard';
  static const homePath = '/home';
  static const homeName = 'home';

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  List<QuoteSummary> _quotes = const [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMoreRecords = false;

  @override
  void initState() {
    super.initState();
    _fetchQuoteData(page: 1);
  }

  Future<void> _fetchQuoteData({required int page}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(crmQuotesApiProvider);
      final result = await api.fetchQuotesPage(page);
      if (!mounted) return;
      setState(() {
        _quotes = result.summaries;
        _currentPage = result.page;
        _totalPages = result.totalPages;
        _hasMoreRecords = result.hasMoreRecords;
        _error = null;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('[Dashboard] fetch error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _goToPage(int page) async {
    if (_isLoading) return;
    if (page < 1 || page > _totalPages) return;
    await _fetchQuoteData(page: page);
  }

  void _openQuoteDetails(QuoteSummary summary) {
    context.push(QuoteDetailsPage.pathFor(summary.id));
  }

  /// Opens Create quote (quote project) on the GoRouter stack.
  void _openCreateQuoteProject() {
    GoRouter.of(context).push(QuoteProjectPage.path);
  }

  @override
  Widget build(BuildContext context) {
    final listTopPad = AppLayout.bodyTopBelowAppBar(context);
    return Scaffold(
      backgroundColor: AppColors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBarStyles.transparent(
        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: AppColors.inkStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Create quote',
            icon: const Icon(Icons.add_circle_outline, color: AppColors.inkStrong),
            onPressed: _openCreateQuoteProject,
          ),
          IconButton(
            tooltip: 'Composite item groups',
            icon: const Icon(Icons.layers_outlined, color: AppColors.inkStrong),
            onPressed: () => context.push(QuoteCompositeItemGroupsPage.path),
          ),
        ],
      ),
      body: AppScreenStack(
        child: RefreshIndicator(
        color: AppColors.accentRed,
        onRefresh: () => _fetchQuoteData(page: _currentPage),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, listTopPad, 16, 96),
          children: [
            const Text(
              'Quote list',
              style: TextStyle(
                color: AppColors.brown,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              QuoteListErrorCard(
                error: _error!,
                onRetry: () => _goToPage(_currentPage),
              )
            else if (_quotes.isEmpty)
              const QuoteListEmptyCard()
            else
              for (final q in _quotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: QuoteListCard(
                    quoteName: q.quoteName,
                    quoteNumber: q.quoteNumber,
                    onOpen: () => _openQuoteDetails(q),
                  ),
                ),
          ],
        ),
        ),
      ),
      bottomNavigationBar: _error == null
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: QuotePaginationBar(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  isLoading: _isLoading,
                  onPrev: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                  onNext: (_currentPage < _totalPages || _hasMoreRecords)
                      ? () => _goToPage(_currentPage + 1)
                      : null,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'dashboard_create_quote',
        onPressed: _openCreateQuoteProject,
        backgroundColor: AppColors.accentRed,
        foregroundColor: AppColors.brandOnPrimary,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
