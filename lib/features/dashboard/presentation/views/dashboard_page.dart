import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_under_development_view.dart';
import 'package:red5/app/routes/route_observers.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_provider.dart';
import 'package:red5/core/network/auth_api_client.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/features/dashboard/presentation/views/create_project_page.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/dashboard/presentation/views/project_details_page.dart';
import 'package:red5/features/clients/presentation/views/clients_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  static const path = '/dashboard';
  static const name = 'dashboard';
  static const homePath = '/home';
  static const homeName = 'home';

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> with RouteAware {
  static const _backgroundColor = Color(0xFFF6F6F7);
  static const _inactiveNav = Color(0xFF8A8A8A);
  final _searchController = TextEditingController();
  List<QuoteSummary> _projects = const [];
  bool _isLoadingProjects = false;
  String? _projectsError;
  int _selectedIndex = 0;
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchProjects();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final storage = ref.read(localStorageProvider);
    final token = storage.getString(LocalStorageKeys.authAccessToken)?.trim();
    try {
      final auth = ref.read(authApiClientProvider);
      await auth.logout(accessToken: token);
    } catch (_) {
      // Ignore logout network errors; still clear local session.
    }
    await storage.remove(LocalStorageKeys.authAccessToken);
    await storage.remove(LocalStorageKeys.authRefreshToken);
    if (!mounted) return;
    GoRouter.of(context).go('/');
  }

  /// When returning from a pushed screen (e.g. project details), reload projects.
  @override
  void didPopNext() {
    _fetchProjects(silent: _projects.isNotEmpty);
  }

  Future<void> _fetchProjects({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingProjects = true;
        _projectsError = null;
      });
    } else if (mounted) {
      setState(() => _projectsError = null);
    }
    try {
      final api = ref.read(crmQuotesApiProvider);
      final first = await api.fetchQuotesPage(1);
      if (!mounted) return;
      setState(() {
        _projects = first.summaries;
        _isLoadingProjects = false;
        _projectsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projectsError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load projects',
        );
        _isLoadingProjects = false;
      });
    }
  }

  void _openCreateQuoteProject() {
    GoRouter.of(context).push(CreateProjectPage.path);
  }

  List<QuoteSummary> get _filteredProjects {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _projects;
    return _projects.where((project) {
      return project.quoteName.toLowerCase().contains(query) ||
          project.quoteNumber.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildTopBarTitle() {
    final title = switch (_selectedIndex) {
      0 => 'Home',
      1 => 'Client',
      _ => 'Projects',
    };
    return Text(
      title,
      style: AppFonts.titleLarge(color: AppColors.inkStrong).copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildTopBarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded, size: 22),
          color: AppColors.inkStrong,
          tooltip: 'Notifications',
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.settings_rounded, size: 22),
          color: AppColors.inkStrong,
          tooltip: 'Settings',
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Profile',
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'logout') {
              _logout();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Logout'),
                ],
              ),
            ),
          ],
          child: const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF2A2A2A),
            child: Icon(Icons.person, size: 16, color: AppColors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectSearchBar() {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEEF0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.bodyLarge(color: AppColors.inkStrong).copyWith(fontSize: 18),
        decoration: InputDecoration(
          hintText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          prefixIcon: const Icon(Icons.search, color: _inactiveNav, size: 20),
          suffixIcon: hasQuery
              ? IconButton(
                  onPressed: () => _searchController.clear(),
                  icon: const Icon(Icons.cancel, color: _inactiveNav, size: 18),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildProjectRow(QuoteSummary project, {required bool highlight}) {
    return InkWell(
      onTap: () => context.push(
        ProjectDetailsPage.pathFor(project.id),
        extra: project.toJson(),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE0E0E1))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.quoteName,
              style: AppFonts.titleMedium(
                color: highlight ? const Color(0xFF2A66C6) : const Color(0xFF2E2E2E),
              ).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              project.clientName?.trim().isNotEmpty == true
                  ? project.clientName!
                  : project.quoteNumber,
              style: AppFonts.bodyMedium(color: const Color(0xFF8B8B8B)).copyWith(
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onProjectsPullToRefresh() =>
      _fetchProjects(silent: _projects.isNotEmpty);

  /// Full-height scroll + [RefreshIndicator] so pull works even when list is short, empty, or error.
  Widget _projectsBodyWithRefresh({
    required BoxConstraints constraints,
    required Widget child,
  }) {
    final minH = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : MediaQuery.sizeOf(context).height;
    return RefreshIndicator(
      onRefresh: _onProjectsPullToRefresh,
      color: const Color(0xFF121212),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minH),
          child: child,
        ),
      ),
    );
  }

  Widget _buildProjectsBody() {
    final filtered = _filteredProjects;
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isLoadingProjects) {
          return _projectsBodyWithRefresh(
            constraints: constraints,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (_projectsError != null) {
          return _projectsBodyWithRefresh(
            constraints: constraints,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _projectsError!,
                      textAlign: TextAlign.center,
                      style: AppFonts.bodyMedium(color: _inactiveNav),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _fetchProjects(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (_projects.isEmpty) {
          return _projectsBodyWithRefresh(
            constraints: constraints,
            child: _buildProjectsEmptyState(),
          );
        }
        return Column(
          children: [
            _buildProjectSearchBar(),
            if (hasQuery)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE0E0E1))),
                ),
                child: Text(
                  'SEARCH RESULTS (${filtered.length})',
                  style: AppFonts.labelLarge(color: _inactiveNav).copyWith(
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onProjectsPullToRefresh,
                color: const Color(0xFF121212),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final project = filtered[index];
                    return _buildProjectRow(
                      project,
                      highlight: hasQuery && index == 0,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHomeEmptyState() {
    return const AppUnderDevelopmentView();
  }

  Widget _buildProjectsEmptyState() {
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
            const SizedBox(height: 24),
            Text(
              'No projects yet',
              textAlign: TextAlign.center,
              style: AppFonts.headlineSmall(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 36,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first project to get started',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: _inactiveNav).copyWith(
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: _buildTopBarTitle(),
        actions: [_buildTopBarActions(), const SizedBox(width: 10)],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeEmptyState(),
          const ClientsPage(),
          _buildProjectsBody(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 2) {
            _fetchProjects(silent: _projects.isNotEmpty);
          }
        },
        backgroundColor: _backgroundColor,
        indicatorColor: const Color(0xFFECECEE),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Projects',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton(
              heroTag: 'dashboard_create_quote',
              onPressed: _openCreateQuoteProject,
              backgroundColor: const Color(0xFF121212),
              foregroundColor: AppColors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }
}
