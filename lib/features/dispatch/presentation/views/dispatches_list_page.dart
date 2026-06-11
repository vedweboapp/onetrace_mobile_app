import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/core/widgets/app_user_avatar.dart';
import 'package:red5/features/dispatch/data/dispatch_models.dart';
import 'package:red5/features/dispatch/presentation/views/create_dispatch_page.dart';
import 'package:red5/features/dispatch/presentation/views/dispatch_detail_page.dart';
import 'package:red5/features/dispatch/presentation/widgets/dispatch_widgets.dart';

/// Dispatch list (UI preview until API is available).
class DispatchesListPage extends StatefulWidget {
  const DispatchesListPage({super.key});

  @override
  State<DispatchesListPage> createState() => _DispatchesListPageState();
}

class _DispatchesListPageState extends State<DispatchesListPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();

  static const _searchBg = Color(0xFFF5F5F5);
  static const _muted = Color(0xFF6B7280);
  static const _border = Color(0xFFE8E8EA);

  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _allItems = DispatchMockData.listItems;
  List<DispatchListItem> _filtered = List.of(_allItems);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(_applySearch);
  }

  void _applySearch() {
    final query = _searchController.text.trim();
    setState(() {
      _filtered = query.isEmpty
          ? List.of(_allItems)
          : _allItems.where((item) => item.matchesQuery(query)).toList();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onCreate() async {
    final created = await context.push<bool?>(CreateDispatchPage.path);
    if (!mounted || created != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dispatch created')),
    );
  }

  void _onMenu(DispatchListItem item, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action — ${item.dispatchCode}')),
    );
  }

  Widget _searchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
          hintText: 'Search dispatch...',
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

  Widget _dispatchCard(DispatchListItem item) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => context.push(DispatchDetailPage.pathFor(item.id)),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
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
                      item.dispatchCode,
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert,
                      color: Color(0xFF9CA3AF),
                      size: 22,
                    ),
                    onSelected: (value) => _onMenu(item, value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'View', child: Text('View')),
                      PopupMenuItem(value: 'Edit', child: Text('Edit')),
                      PopupMenuItem(value: 'Delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  AppUserAvatar(name: item.recipientName, radius: 14, fontSize: 10),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                            .copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(text: item.recipientName),
                          TextSpan(
                            text: ' • ${item.projectName}',
                            style: AppFonts.bodyMedium(color: _muted).copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    _dateFormat.format(item.dispatchDate),
                    style: AppFonts.bodyMedium(color: _muted).copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Color(0xFF9CA3AF))),
                  const SizedBox(width: 8),
                  DispatchStatusBadge(status: item.status),
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
              Icons.local_shipping_outlined,
              color: Color(0xFFB0B0B3),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No dispatch records found' : 'No dispatches yet',
              style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Create your first dispatch record',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _muted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: Column(
        children: [
          if (_filtered.isNotEmpty || _searchController.text.isNotEmpty)
            _searchBar(),
          Expanded(
            child: _filtered.isEmpty
                ? _emptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _dispatchCard(_filtered[index]),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'dispatches_create_fab',
        onPressed: _onCreate,
        backgroundColor: const Color(0xFF121212),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}
