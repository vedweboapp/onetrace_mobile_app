import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/quotations/data/quotation_models.dart';
import 'package:red5/features/quotations/data/quotations_api_client.dart';
import 'package:red5/features/quotations/presentation/quotation_list_refresh.dart';
import 'package:red5/features/quotations/presentation/views/quotation_detail_page.dart';

/// Quotation list from `GET /api/v1/quotations/`.
class QuotationsListPage extends ConsumerStatefulWidget {
  const QuotationsListPage({super.key});

  @override
  ConsumerState<QuotationsListPage> createState() => _QuotationsListPageState();
}

class _QuotationsListPageState extends ConsumerState<QuotationsListPage> {
  final _searchController = TextEditingController();
  final List<QuotationListItem> _items = <QuotationListItem>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  static const _muted = Color(0xFF8B8B8B);
  static const _searchBg = Color(0xFFEFEEF0);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchPage(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _projectLine(QuotationListItem q) {
    final p = q.projectName?.trim();
    if (p != null && p.isNotEmpty) return p;
    final d = q.description?.trim();
    if (d != null && d.isNotEmpty) return d;
    return '—';
  }

  String _clientLine(QuotationListItem q) {
    final c = q.clientName?.trim();
    if (c != null && c.isNotEmpty) return c;
    return '—';
  }

  String _phoneLine(QuotationListItem q) {
    final p = q.contactPhone?.trim();
    if (p != null && p.isNotEmpty) return p;
    return '—';
  }

  String _siteLine(QuotationListItem q) {
    final s = q.siteName?.trim();
    if (s != null && s.isNotEmpty) return s;
    return '—';
  }

  List<QuotationListItem> _filtered(List<QuotationListItem> all) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return all;
    return all.where((q) {
      return q.id.toLowerCase().contains(query) ||
          q.quoteName.toLowerCase().contains(query) ||
          q.quoteNumber.toLowerCase().contains(query) ||
          _clientLine(q).toLowerCase().contains(query) ||
          _projectLine(q).toLowerCase().contains(query) ||
          _siteLine(q).toLowerCase().contains(query) ||
          _phoneLine(q).toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _fetchPage({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }
    try {
      final api = ref.read(quotationsApiClientProvider);
      final nextPage = reset ? 1 : (_page + 1);
      final result = await api.fetchQuotationsPage(
        page: nextPage,
        pageSize: QuotationsApiClient.defaultPageSize,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }
        _page = result.currentPage;
        _totalPages = result.totalPages;
        _isLoading = false;
        _isLoadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load quotations',
        );
      });
    }
  }

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong).copyWith(
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8A8A8A), size: 20),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => _searchController.clear(),
                  icon: const Icon(Icons.cancel, color: Color(0xFF8A8A8A), size: 18),
                )
              : null,
        ),
      ),
    );
  }

  Widget _metaLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppFonts.bodyMedium(color: _muted).copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quoteTile(QuotationListItem q) {
    final id = q.id.trim();
    final canOpen = id.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !canOpen
            ? null
            : () => context.push(QuotationDetailPage.pathFor(id)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE0E0E1))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.quoteName,
                style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.2,
                ),
              ),
              _metaLine(Icons.person_outline_rounded, _clientLine(q)),
              _metaLine(Icons.work_outline_rounded, _projectLine(q)),
              if (q.siteName != null && q.siteName!.trim().isNotEmpty)
                _metaLine(Icons.place_outlined, _siteLine(q)),
              _metaLine(Icons.phone_outlined, _phoneLine(q)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1F1F2),
                border: Border.all(color: const Color(0xFFE6E6E7)),
              ),
              child: const Icon(
                Icons.request_quote_outlined,
                color: Color(0xFFB0B0B3),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No quotations yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a quotation to see it listed here',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _muted).copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(quotationListRefreshTickProvider, (previous, next) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchPage(reset: true);
        });
      }
    });

    final filtered = _filtered(_items);
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          if (_items.isNotEmpty) _searchBar(),
          if (hasQuery && _items.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE0E0E1))),
              ),
              child: Text(
                'SEARCH RESULTS (${filtered.length})',
                style: AppFonts.labelLarge(color: const Color(0xFF8A8A8A))
                    .copyWith(
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: const AppSkeletonScreenBody(
                      style: AppSkeletonScreenBodyStyle.listRows,
                      listRowCount: 10,
                    ),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppFonts.bodyMedium(color: _muted),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => _fetchPage(reset: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                ? RefreshIndicator(
                    onRefresh: () => _fetchPage(reset: true),
                    color: const Color(0xFF121212),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.65,
                        child: _emptyState(),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _fetchPage(reset: true),
                    color: const Color(0xFF121212),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length + 1,
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          if (_searchController.text.trim().isEmpty &&
                              !_isLoadingMore &&
                              _page < _totalPages) {
                            _fetchPage(reset: false);
                          }
                          if (_isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          return const SizedBox(height: 12);
                        }
                        return _quoteTile(filtered[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
