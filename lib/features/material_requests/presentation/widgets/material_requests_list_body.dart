import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/employee_role/jobs/data/assigned_jobs_filter.dart';
import 'package:red5/features/material_requests/data/material_request_models.dart';
import 'package:red5/features/material_requests/data/material_requests_api_client.dart';
import 'package:red5/features/material_requests/presentation/views/material_request_detail_page.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_request_widgets.dart';

/// Searchable material requests list used by admin dashboard and operative site.
class MaterialRequestsListBody extends ConsumerStatefulWidget {
  const MaterialRequestsListBody({
    super.key,
    this.alwaysShowSearch = false,
    this.listBottomPadding = 88,
    this.searchHorizontalPadding = 16,
    this.scopeToCurrentWorker = false,
    this.jobId,
    this.statusId,
    this.detailPathFor,
  });

  final bool alwaysShowSearch;
  final double listBottomPadding;
  final double searchHorizontalPadding;

  /// When true, loads `GET /material-requests/?worker=<auth user id>`.
  final bool scopeToCurrentWorker;

  /// Optional `?job=` filter.
  final int? jobId;

  /// Optional `?status=` filter (e.g. PENDING = 68).
  final int? statusId;

  /// Override detail navigation (operative uses its own detail route).
  final String Function(String id)? detailPathFor;

  @override
  ConsumerState<MaterialRequestsListBody> createState() =>
      _MaterialRequestsListBodyState();
}

class _MaterialRequestsListBodyState
    extends ConsumerState<MaterialRequestsListBody> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();

  static const _searchBg = Color(0xFFF5F5F5);
  static const _muted = Color(0xFF6B7280);
  static const _border = Color(0xFFE8E8EA);

  List<MaterialRequestListItem> _allItems = const [];
  List<MaterialRequestListItem> _filtered = const [];
  var _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant MaterialRequestsListBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeToCurrentWorker != widget.scopeToCurrentWorker ||
        oldWidget.jobId != widget.jobId ||
        oldWidget.statusId != widget.statusId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(materialRequestsApiClientProvider);
      final storage = sl<LocalStorage>();
      int? workerId;
      if (widget.scopeToCurrentWorker) {
        final raw = AssignedJobsFilter.currentWorkerId(storage);
        workerId = int.tryParse(raw ?? '');
        if (workerId == null || workerId <= 0) {
          throw StateError('Could not resolve the signed-in worker id.');
        }
      }

      final rows = await api.fetchMaterialRequests(
        workerId: workerId,
        jobId: widget.jobId,
        statusId: widget.statusId,
      );
      final items = rows.map((row) => row.toListItem()).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _filtered = _applyQuery(items, _searchController.text);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          error,
          genericFallback: 'Could not load material requests.',
        );
        _allItems = const [];
        _filtered = const [];
      });
    }
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(() {
      setState(() {
        _filtered = _applyQuery(_allItems, _searchController.text);
      });
    });
  }

  static List<MaterialRequestListItem> _applyQuery(
    List<MaterialRequestListItem> source,
    String rawQuery,
  ) {
    final query = rawQuery.trim();
    if (query.isEmpty) return List.of(source);
    return source.where((item) => item.matchesQuery(query)).toList();
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  bool get _showSearch =>
      widget.alwaysShowSearch ||
      _filtered.isNotEmpty ||
      _searchController.text.isNotEmpty ||
      (!_loading && _errorMessage == null);

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: EdgeInsets.fromLTRB(
        widget.searchHorizontalPadding,
        8,
        widget.searchHorizontalPadding,
        12,
      ),
      decoration: BoxDecoration(
        color: _searchBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong)
            .copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search requests...',
          hintStyle: AppFonts.bodyLarge(color: const Color(0xFF9CA3AF))
              .copyWith(fontSize: 16, fontWeight: FontWeight.w400),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF9CA3AF),
            size: 22,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => _searchController.clear(),
                  icon: const Icon(
                    Icons.cancel,
                    color: Color(0xFF9CA3AF),
                    size: 18,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _requestCard(MaterialRequestListItem item) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          final path = widget.detailPathFor?.call(item.id) ??
              MaterialRequestDetailPage.pathFor(item.id);
          context.push(path);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.requestCode,
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  MaterialRequestStatusBadge(
                    status: item.status,
                    label: item.statusLabel,
                    background: item.statusBg,
                    foreground: item.statusFg,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.jobCode,
                style: AppFonts.bodyMedium(color: _muted).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: _muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.requesterName,
                      style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.inventory_2_outlined, size: 16, color: _muted),
                  const SizedBox(width: 4),
                  Text(
                    '${item.itemCount} Items',
                    style: AppFonts.bodyMedium(color: _muted).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFFB0B0B3),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No requests found' : 'No material requests yet',
              style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Create your first material request',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage ?? 'Could not load material requests.',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.error),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          if (_showSearch) _searchBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : _errorMessage != null
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.45,
                            child: _errorState(),
                          ),
                        ],
                      )
                    : _filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.sizeOf(context).height * 0.45,
                                child: _emptyState(),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              widget.searchHorizontalPadding,
                              0,
                              widget.searchHorizontalPadding,
                              widget.listBottomPadding,
                            ),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _requestCard(_filtered[index]),
                          ),
          ),
        ],
      ),
    );
  }
}
