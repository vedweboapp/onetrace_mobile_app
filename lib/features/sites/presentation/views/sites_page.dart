import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_pagination.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/sites/data/site_models.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';
import 'package:red5/features/sites/presentation/views/add_site_page.dart';
import 'package:red5/features/sites/presentation/views/site_detail_page.dart';

class SitesPage extends ConsumerStatefulWidget {
  const SitesPage({super.key});

  @override
  ConsumerState<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends ConsumerState<SitesPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();
  final List<SiteModel> _sites = <SiteModel>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchSites(reset: true);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(() => _fetchSites(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSites({bool reset = false}) async {
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
      final api = ref.read(sitesApiClientProvider);
      final nextPage = reset ? 1 : (_page + 1);
      final result = await api.fetchSitesPage(
        page: nextPage,
        pageSize: kDefaultApiPageSize,
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _sites
            ..clear()
            ..addAll(result.items);
        } else {
          _sites.addAll(result.items);
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
          genericFallback: 'Failed to load sites',
        );
      });
    }
  }

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEEF0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.bodyLarge(
          color: AppColors.inkStrong,
        ).copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF8A8A8A),
            size: 20,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => _searchController.clear(),
                  icon: const Icon(
                    Icons.cancel,
                    color: Color(0xFF8A8A8A),
                    size: 18,
                  ),
                )
              : null,
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
              child: const Icon(Icons.public, color: Color(0xFFB0B0B3)),
            ),
            const SizedBox(height: 20),
            Text(
              'No Sites yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first Site to get started',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: const Color(0xFF8A8A8A),
              ).copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _siteRow(SiteModel site) {
    return InkWell(
      onTap: () => context.push(SiteDetailPage.pathFor(site.id)),
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
              site.siteName,
              style: AppFonts.titleMedium(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 15, height: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              site.clientName.isEmpty ? 'Client' : site.clientName,
              style: AppFonts.bodySmall(
                color: const Color(0xFF8B8B8B),
              ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddSite() async {
    final created = await context.push<SiteModel>(AddSitePage.path);
    if (!mounted || created == null) return;
    if (_searchController.text.trim().isNotEmpty) {
      setState(() => _searchController.clear());
    }
    setState(() => _sites.insert(0, created));
    context.showTopSnackBar(
      SnackBar(
        content: Text('${created.siteName} created successfully'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: Column(
        children: [
          if (_sites.isNotEmpty) _searchBar(),
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
                            style: AppFonts.bodyMedium(
                              color: const Color(0xFF8A8A8A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: () => _fetchSites(reset: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _sites.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: () => _fetchSites(reset: true),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _sites.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _sites.length) {
                          if (!hasQuery &&
                              !_isLoadingMore &&
                              _page < _totalPages) {
                            _fetchSites(reset: false);
                          }
                          if (_isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 10);
                        }
                        return _siteRow(_sites[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'sites_add_fab',
        onPressed: _openAddSite,
        backgroundColor: const Color(0xFF121212),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
