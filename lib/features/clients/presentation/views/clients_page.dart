import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';
import 'package:red5/features/clients/presentation/views/add_client_page.dart';
import 'package:red5/features/clients/presentation/views/client_detail_page.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});

  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _searchController = TextEditingController();
  final _searchDebounce = DebouncedSearch();
  final List<ClientModel> _clients = <ClientModel>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchClients(reset: true);
  }

  void _onSearchChanged() {
    setState(() {});
    _searchDebounce.schedule(() => _fetchClients(reset: true));
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClients({bool reset = false}) async {
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
      final api = ref.read(clientsApiClientProvider);
      final nextPage = reset ? 1 : (_page + 1);
      final result = await api.fetchClientsPage(
        page: nextPage,
        pageSize: ClientsApiClient.defaultPageSize,
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _clients
            ..clear()
            ..addAll(result.items);
        } else {
          _clients.addAll(result.items);
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
          genericFallback: 'Failed to load clients',
        );
      });
    }
  }

  Color _statusBg(bool active) =>
      active ? const Color(0xFFE9F9EE) : const Color(0xFFF1F1F2);

  Color _statusFg(bool active) =>
      active ? const Color(0xFF137333) : const Color(0xFF6B6B70);

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
        style: AppFonts.bodyLarge(color: AppColors.inkStrong)
            .copyWith(fontSize: 16),
        decoration: InputDecoration(
          hintText: '',
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8A8A8A), size: 20),
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
              child: const Icon(Icons.folder_open, color: Color(0xFFB0B0B3)),
            ),
            const SizedBox(height: 20),
            Text(
              'No Client yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first Client to get started',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: const Color(0xFF8A8A8A))
                  .copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientRow(ClientModel c) {
    return InkWell(
      onTap: () => context.push(ClientDetailPage.pathFor(c.id)),
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
                    c.name,
                    style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                       Image.asset("assets/images/inperson.png",
                          height: 15,width: 15, color: Color(0xFF8B8B8B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.contactPerson.isEmpty ? '—' : c.contactPerson,
                          style: AppFonts.bodySmall(color: const Color(0xFF8B8B8B))
                              .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Image.asset("assets/images/call.png",
                          height: 15,width: 15, color: Color(0xFF8B8B8B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.phone,
                          style: AppFonts.bodySmall(color: const Color(0xFF8B8B8B))
                              .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusBg(c.isActive),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _statusFg(c.isActive).withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                c.isActive ? 'ACTIVE' : 'IN ACTIVE',
                style: AppFonts.labelMedium(color: _statusFg(c.isActive)).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddClient() async {
    final created = await context.push<ClientModel>(AddClientPage.path);
    if (!mounted || created == null) return;
    if (_searchController.text.trim().isNotEmpty) {
      setState(() => _searchController.clear());
    }
    setState(() => _clients.insert(0, created));
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
          if (_clients.isNotEmpty) _searchBar(),
          if (hasQuery)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE0E0E1))),
              ),
              child: Text(
                'SEARCH RESULTS (${_clients.length})',
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
                                style: AppFonts.bodyMedium(color: const Color(0xFF8A8A8A)),
                              ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: () => _fetchClients(reset: true),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _clients.isEmpty
                        ? _emptyState()
                        : RefreshIndicator(
                            onRefresh: () => _fetchClients(reset: true),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _clients.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _clients.length) {
                                  if (!hasQuery &&
                                      !_isLoadingMore &&
                                      _page < _totalPages) {
                                    _fetchClients(reset: false);
                                  }
                                  if (_isLoadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  }
                                  return const SizedBox(height: 10);
                                }
                                return _clientRow(_clients[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'clients_add_fab',
        onPressed: _openAddClient,
        backgroundColor: const Color(0xFF121212),
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

