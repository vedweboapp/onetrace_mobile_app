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
import 'package:red5/features/groups/data/group_date_format.dart';
import 'package:red5/features/groups/data/group_models.dart';
import 'package:red5/features/groups/data/groups_api_client.dart';
import 'package:red5/features/groups/presentation/views/add_group_page.dart';
import 'package:red5/features/groups/presentation/views/group_detail_page.dart';

class GroupsPage extends ConsumerStatefulWidget {
  const GroupsPage({super.key});

  @override
  ConsumerState<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends ConsumerState<GroupsPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();
  final List<GroupModel> _groups = <GroupModel>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchGroups(reset: true);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(() => _fetchGroups(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroups({bool reset = false}) async {
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
      final api = ref.read(groupsApiClientProvider);
      final nextPage = reset ? 1 : (_page + 1);
      final result = await api.fetchGroupsPage(
        page: nextPage,
        pageSize: kDefaultApiPageSize,
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _groups
            ..clear()
            ..addAll(result.items);
        } else {
          _groups.addAll(result.items);
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
          genericFallback: 'Failed to load groups',
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
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFEEEEEF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 42,
                color: Color(0xFFD5D5D7),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Create your first Group to get started',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: const Color(0xFF8A8A8A),
              ).copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'No Groups yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w800, fontSize: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(bool isActive) {
    final color = isActive ? const Color(0xFF12A150) : const Color(0xFF6B7280);
    final bg = isActive ? const Color(0xFFE6F7EE) : const Color(0xFFEDEEF0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'IN ACTIVE',
        style: AppFonts.labelMedium(color: color).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _groupRow(GroupModel group) {
    final compositeCount = group.items.length;
    final compositeLabel = compositeCount > 0
        ? '$compositeCount Composite items'
        : 'Composite items';
    return InkWell(
      onTap: () => context.push(GroupDetailPage.pathFor(group.id)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE0E0E1))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: AppFonts.titleMedium(
                      color: AppColors.inkStrong,
                    ).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    compositeLabel,
                    style: AppFonts.bodySmall(
                      color: const Color(0xFF8B8B8B),
                    ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatGroupDate(group.createdAt),
                    style: AppFonts.bodySmall(
                      color: const Color(0xFF8B8B8B),
                    ).copyWith(fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _statusPill(group.isActive),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddGroup() async {
    final created = await context.push<GroupModel>(AddGroupPage.path);
    if (!mounted || created == null) return;
    if (_searchController.text.trim().isNotEmpty) {
      setState(() => _searchController.clear());
    }
    setState(() => _groups.insert(0, created));
    context.showTopSnackBar(
      SnackBar(
        content: Text('${created.name} created successfully'),
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
          if (_groups.isNotEmpty) _searchBar(),
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
                            onPressed: () => _fetchGroups(reset: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _groups.isEmpty
                ? _emptyState()
                : RefreshIndicator(
                    onRefresh: () => _fetchGroups(reset: true),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _groups.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _groups.length) {
                          if (!hasQuery &&
                              !_isLoadingMore &&
                              _page < _totalPages) {
                            _fetchGroups(reset: false);
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
                        return _groupRow(_groups[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'groups_add_fab',
        onPressed: _openAddGroup,
        backgroundColor: const Color(0xFF121212),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
