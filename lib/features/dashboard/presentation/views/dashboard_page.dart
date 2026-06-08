import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/debounced_search.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/widgets/app_under_development_view.dart';
import 'package:red5/app/routes/route_observers.dart';
import 'package:red5/features/dashboard/data/crm_quotes_api_provider.dart';
import 'package:red5/core/network/api_urls.dart';
import 'package:red5/core/auth/auth_redirect_notifier.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/auth_api_client.dart';
import 'package:red5/core/preferences/nav_menu_style_preference.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/features/dashboard/presentation/views/create_project_page.dart';
import 'package:red5/features/dashboard/presentation/views/qr_codes_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_page.dart';
import 'package:red5/features/dashboard/data/quote_summary.dart';
import 'package:red5/features/dashboard/presentation/views/project_details_page.dart';
import 'package:red5/features/dashboard/presentation/views/add_invoice_page.dart';
import 'package:red5/features/dashboard/presentation/views/invoices_list_page.dart';
import 'package:red5/features/dashboard/presentation/views/add_purchase_order_page.dart';
import 'package:red5/features/dashboard/presentation/views/purchase_orders_list_page.dart';
import 'package:red5/features/dashboard/presentation/views/bills_list_page.dart';
import 'package:red5/features/dashboard/presentation/views/add_bill_page.dart';
import 'package:red5/features/vendors/presentation/views/vendors_list_page.dart';
import 'package:red5/features/dashboard/presentation/views/reports_list_page.dart';
import 'package:red5/features/dashboard/presentation/views/quotations_list_page.dart';
import 'package:red5/features/quotations/data/quotation_models.dart';
import 'package:red5/features/dashboard/presentation/invoice_list_refresh.dart';
import 'package:red5/features/quotations/presentation/quotation_list_refresh.dart';
import 'package:red5/features/quotations/presentation/views/add_quotation_page.dart';
import 'package:red5/features/clients/presentation/views/clients_page.dart';
import 'package:red5/features/contacts/presentation/views/contacts_page.dart';
import 'package:red5/features/groups/presentation/views/groups_page.dart';
import 'package:red5/features/composite_items/presentation/view/composite_item_page.dart';
import 'package:red5/features/items/presentation/views/items_page.dart';
import 'package:red5/features/sites/presentation/views/sites_page.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/employee_role/data/role_session.dart';

String? _absoluteProfileImageUrl(String imageFromApi) {
  final raw = imageFromApi.trim();
  if (raw.isEmpty) return null;
  final parsed = Uri.tryParse(raw);
  if (parsed != null &&
      parsed.hasScheme &&
      (parsed.scheme == 'http' || parsed.scheme == 'https')) {
    return raw;
  }
  return Uri.parse(
    AppApiUrls.baseUrl,
  ).resolve(raw.startsWith('/') ? raw : '/$raw').toString();
}

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
  final _searchDebounce = DebouncedSearch();
  List<QuoteSummary> _projects = const [];
  bool _isLoadingProjects = false;
  String? _projectsError;
  int _selectedIndex = 0;
  bool _productsExpanded = true;
  final GlobalKey<ScaffoldState> _dashboardScaffoldKey =
      GlobalKey<ScaffoldState>();
  NavMenuStyle _navMenuStyle = NavMenuStyle.drawer;
  PageRoute<dynamic>? _subscribedRoute;
  String? _profileAvatarUrl;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchProjects();
    unawaited(_loadProfileAvatar());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNavMenuStyle());
  }

  void _loadNavMenuStyle() {
    final storage = ref.read(localStorageProvider);
    final style = NavMenuStylePreference.read(storage);
    if (mounted) setState(() => _navMenuStyle = style);
  }

  void _openMainNavigation() {
    FocusScope.of(context).unfocus();
    if (_navMenuStyle == NavMenuStyle.bottomSheet) {
      _showMainNavBottomSheet();
    } else {
      _dashboardScaffoldKey.currentState?.openDrawer();
    }
  }

  void _showMainNavBottomSheet() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.78;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: AppColors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E2E4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text(
                            'Menu',
                            style:
                                AppFonts.titleLarge(
                                  color: AppColors.inkStrong,
                                ).copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: const Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE3E3E4),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        children: _mainNavMenuSiblings(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

  void _onSearchChanged() {
    setState(() {});
    if (_selectedIndex != 3) return;
    _searchDebounce.schedule(
      () => _fetchProjects(silent: _projects.isNotEmpty),
    );
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _searchDebounce.dispose();
    _searchController.removeListener(_onSearchChanged);
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
    await storage.remove(LocalStorageKeys.authUserId);
    await RoleSession.clearRole(storage);
    if (!mounted) return;
    sl<AuthRedirectNotifier>().notifyAuthChanged();
    GoRouter.of(context).go('/');
  }

  /// When returning from a pushed screen (e.g. project details), reload projects.
  @override
  void didPopNext() {
    _fetchProjects(silent: _projects.isNotEmpty);
    unawaited(_loadProfileAvatar());
    _loadNavMenuStyle();
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
      final first = await api.fetchQuotesPage(
        1,
        search: _searchController.text.trim(),
      );
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

  Future<void> _loadProfileAvatar() async {
    try {
      final api = ref.read(userProfileApiClientProvider);
      final profile = await api.fetchCurrentProfile();
      if (!mounted) return;
      final raw = profile?.userImage.trim() ?? '';
      setState(() {
        _profileAvatarUrl = raw.isEmpty ? null : _absoluteProfileImageUrl(raw);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileAvatarUrl = null);
    }
  }

  void _openCreateQuoteProject() async {
    if (_selectedIndex == 12) {
      context.push<bool?>(AddBillPage.path);
      return;
    }
    if (_selectedIndex == 11) {
      context.push<bool?>(AddPurchaseOrderPage.path);
      return;
    }
    if (_selectedIndex == 10) {
      context.push<String?>(AddInvoicePage.path).then((createdId) {
        if (!mounted || createdId == null || createdId.trim().isEmpty) return;
        ref.read(invoiceListRefreshTickProvider.notifier).state++;
      });
      return;
    }
    if (_selectedIndex == 8) {
      final created = await context.push<QuotationListItem>(
        AddQuotationPage.path,
      );
      if (!mounted) return;
      if (created != null) {
        ref.read(quotationListRefreshTickProvider.notifier).state++;
      }
    } else {
      GoRouter.of(context).push(CreateProjectPage.path);
    }
  }

  void _openSettings() {
    context.push(SettingsPage.path);
  }

  Widget _buildTopBarTitle() {
    final title = switch (_selectedIndex) {
      0 => 'Home',
      1 => 'Client',
      2 => 'Sites',
      3 => 'Projects',
      4 => 'Contacts',
      5 => 'Groups',
      6 => 'Items',
      7 => 'Composite items',
      8 => 'Quotation',
      9 => 'Jobs',
      10 => 'Invoices',
      11 => 'Purchase Order',
      12 => 'Bill Order',
      13 => 'Vendor',
      14 => 'Reports',
      _ => 'Home',
    };
    return Text(
      title,
      style: AppFonts.titleLarge(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w800),
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
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_rounded, size: 22),
          color: AppColors.inkStrong,
          tooltip: 'Settings',
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Profile',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
          child: _buildProfileMenuAvatar(),
        ),
      ],
    );
  }

  /// [CircleAvatar] only allows [onBackgroundImageError] when [backgroundImage] is non-null.
  Widget _buildProfileMenuAvatar() {
    final url = _profileAvatarUrl?.trim();
    if (url == null || url.isEmpty) {
      return const CircleAvatar(
        radius: 16,
        backgroundColor: Color(0xFFE5E7EB),
        child: Icon(
          Icons.person_rounded,
          size: 20,
          color: AppColors.textFieldHint,
        ),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (Object exception, StackTrace? stackTrace) {
        if (!mounted) return;
        setState(() => _profileAvatarUrl = null);
      },
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
        style: AppFonts.bodyLarge(
          color: AppColors.inkStrong,
        ).copyWith(fontSize: 18),
        decoration: InputDecoration(
          hintText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
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
              style:
                  AppFonts.titleMedium(
                    color: highlight
                        ? const Color(0xFF2A66C6)
                        : const Color(0xFF2E2E2E),
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
              style: AppFonts.bodyMedium(
                color: const Color(0xFF8B8B8B),
              ).copyWith(fontSize: 14, height: 1.25),
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
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isLoadingProjects) {
          return _projectsBodyWithRefresh(
            constraints: constraints,
            child: Center(
              child: const AppSkeletonScreenBody(
                style: AppSkeletonScreenBodyStyle.listRows,
                listRowCount: 10,
              ),
            ),
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
                  'SEARCH RESULTS (${_projects.length})',
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
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
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
              style: AppFonts.headlineSmall(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 36),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first project to get started',
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(
                color: _inactiveNav,
              ).copyWith(fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDrawerIndex(int index) {
    setState(() => _selectedIndex = index);
    Navigator.of(context).pop();
    if (index == 3 || index == 9) {
      _fetchProjects(silent: _projects.isNotEmpty);
    }
  }

  /// Drawer + overflow bottom sheet share the same destinations.
  List<Widget> _mainNavMenuSiblings() {
    return [
      _drawerItem(
        icon: 'assets/images/home.png',
        label: 'Home',
        selected: _selectedIndex == 0,
        onTap: () => _selectDrawerIndex(0),
      ),
      _drawerItem(
        icon: 'assets/images/clients.png',
        label: 'Clients',
        selected: _selectedIndex == 1,
        onTap: () => _selectDrawerIndex(1),
      ),
      _drawerItem(
        icon: 'assets/images/contacts.png',
        label: 'Contacts',
        selected: _selectedIndex == 4,
        onTap: () => _selectDrawerIndex(4),
      ),
      _drawerItem(
        icon: 'assets/images/sites.png',
        label: 'Sites',
        selected: _selectedIndex == 2,
        onTap: () => _selectDrawerIndex(2),
      ),
      _drawerItem(
        icon: 'assets/images/qoutations.png',
        label: 'Quotations',
        selected: _selectedIndex == 8,
        onTap: () {
          Navigator.of(context).pop();
          setState(() => _selectedIndex = 8);
        },
      ),
      _drawerIconItem(
        iconData: Icons.receipt_long_rounded,
        label: 'Invoices',
        selected: _selectedIndex == 10,
        onTap: () => _selectDrawerIndex(10),
      ),
      _drawerIconItem(
        iconData: Icons.shopping_cart_outlined,
        label: 'Purchase Order',
        selected: _selectedIndex == 11,
        onTap: () => _selectDrawerIndex(11),
      ),
      _drawerSectionTitle('Bill'),
      _drawerIconItem(
        iconData: Icons.receipt_long_outlined,
        label: 'Bill Order',
        selected: _selectedIndex == 12,
        onTap: () => _selectDrawerIndex(12),
      ),
      _drawerSectionTitle('Vendor'),
      _drawerIconItem(
        iconData: Icons.storefront_outlined,
        label: 'Vendor',
        selected: _selectedIndex == 13,
        onTap: () => _selectDrawerIndex(13),
      ),
      _drawerItem(
        icon: 'assets/images/jobs.png',
        label: 'Jobs',
        selected: _selectedIndex == 9,
        onTap: () => _selectDrawerIndex(9),
      ),
      _drawerIconItem(
        iconData: Icons.qr_code_2_rounded,
        label: 'QR codes',
        onTap: () {
          Navigator.of(context).pop();
          context.push(QrCodesPage.path);
        },
      ),
      _drawerItem(
        icon: 'assets/images/projects.png',
        label: 'Projects',
        selected: _selectedIndex == 3,
        onTap: () => _selectDrawerIndex(3),
      ),
      _drawerIconItem(
        iconData: Icons.assessment_outlined,
        label: 'Reports',
        selected: _selectedIndex == 14,
        onTap: () => _selectDrawerIndex(14),
      ),
      _drawerItem(
        icon: 'assets/images/groups.png',
        label: 'Groups',
        selected: _selectedIndex == 5,
        onTap: () => _selectDrawerIndex(5),
      ),
      _drawerExpandableItem(
        icon: 'assets/images/products.png',
        label: 'Products',
        expanded: _productsExpanded,
        onTap: () => setState(() => _productsExpanded = !_productsExpanded),
        children: [
          _drawerSubItem('Items', () {
            Navigator.of(context).pop();
            setState(() {
              _selectedIndex = 6;
              _productsExpanded = true;
            });
          }, _selectedIndex == 6),
          _drawerSubItem('Composite Items', () {
            Navigator.of(context).pop();
            setState(() {
              _selectedIndex = 7;
              _productsExpanded = true;
            });
          }, _selectedIndex == 7),
        ],
      ),
    ];
  }

  Widget _buildAppDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.white,
      elevation: 1,
      width: 260,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
              child: Row(
                children: [
                  Text(
                    'RED 5',
                    style: AppFonts.titleLarge(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const Spacer(),
                  InkWell(
                    // visualDensity: VisualDensity.,
                    onTap: () => Navigator.of(context).pop(),
                    child: Image.asset(
                      "assets/images/Vector.png",
                      color: Color(0xFF6B7280),
                      height: 20,
                      width: 20,
                    ),
                    // tooltip: 'Close menu',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                children: _mainNavMenuSiblings(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerSectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 6),
      child: Text(
        label,
        style: AppFonts.labelSmall(color: const Color(0xFF9CA3AF)).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required String icon,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? const Color(0xFFEFEFF1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Image.asset(
                  icon,
                  width: 22,
                  height: 22,
                  color: selected ? AppColors.inkStrong : HexColor("#4B5563"),
                ),
                // Icon(icon, size: 18, color: AppColors.inkStrong),
                const SizedBox(width: 14),
                Text(
                  label,
                  style:
                      AppFonts.titleMedium(
                        color: selected
                            ? AppColors.inkStrong
                            : HexColor("#4B5563"),
                      ).copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        fontSize: 16,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _drawerExpandableItem({
    required String icon,
    required String label,
    required bool expanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Image.asset(
                    icon,
                    width: 22,
                    height: 22,
                    color: AppColors.inkStrong,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...children,
      ],
    );
  }

  Widget _drawerSubItem(String label, VoidCallback onTap, bool selected) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(44, 9, 12, 9),
          child: Text(
            label,
            style: AppFonts.titleMedium(
              color: selected ? AppColors.inkStrong : HexColor("#4B5563"),
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _drawerIconItem({
    required IconData iconData,
    required String label,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? const Color(0xFFEFEFF1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  iconData,
                  size: 22,
                  color: selected ? AppColors.inkStrong : HexColor("#4B5563"),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: AppFonts.titleMedium(
                    color: selected ? AppColors.inkStrong : HexColor("#4B5563"),
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int get _bottomSelectedIndex {
    if (_navMenuStyle == NavMenuStyle.bottomSheet) {
      return switch (_selectedIndex) {
        0 => 0,
        1 => 1,
        3 => 2,
        _ => 3,
      };
    }
    return switch (_selectedIndex) {
      0 => 0,
      1 => 1,
      3 => 2,
      _ => 0,
    };
  }

  /// No pill when current screen is not one of the primary bottom tabs.
  bool get _suppressBottomNavIndicator {
    if (_navMenuStyle == NavMenuStyle.drawer) {
      return _selectedIndex != 0 && _selectedIndex != 1 && _selectedIndex != 3;
    }
    return _bottomSelectedIndex == 3 &&
        _selectedIndex != 0 &&
        _selectedIndex != 1 &&
        _selectedIndex != 3;
  }

  void _onBottomDestinationSelected(int index) {
    if (_navMenuStyle == NavMenuStyle.bottomSheet && index == 3) {
      _openMainNavigation();
      return;
    }
    final pageIndex = switch (index) {
      0 => 0,
      1 => 1,
      2 => 3,
      _ => 0,
    };
    setState(() => _selectedIndex = pageIndex);
    if (pageIndex == 3) {
      _fetchProjects(silent: _projects.isNotEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final whiteShellTab =
        _selectedIndex == 8 ||
        _selectedIndex == 10 ||
        _selectedIndex == 11 ||
        _selectedIndex == 12;
    final shellBg = whiteShellTab ? AppColors.white : _backgroundColor;

    return Scaffold(
      key: _dashboardScaffoldKey,
      backgroundColor: shellBg,
      drawer: _navMenuStyle == NavMenuStyle.drawer
          ? _buildAppDrawer(context)
          : null,
      drawerEnableOpenDragGesture: _navMenuStyle == NavMenuStyle.drawer,
      appBar: AppBar(
        backgroundColor: shellBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 4,
        automaticallyImplyLeading: _navMenuStyle == NavMenuStyle.drawer,
        leading: _navMenuStyle == NavMenuStyle.drawer
            ? IconButton(
                onPressed: _openMainNavigation,
                icon: const Icon(Icons.menu_rounded, size: 24),
                color: AppColors.inkStrong,
                tooltip: 'Menu',
              )
            : null,
        title: _buildTopBarTitle(),
        actions: [_buildTopBarActions(), const SizedBox(width: 10)],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeEmptyState(),
          const ClientsPage(),
          const SitesPage(),
          _buildProjectsBody(),
          const ContactsPage(),
          const GroupsPage(),
          const ItemsPage(),
          const CompositeItemPage(),
          const QuotationsListPage(),
          _buildProjectsBody(),
          const InvoicesListPage(),
          const PurchaseOrdersListPage(),
          const BillsListPage(),
          const VendorsListPage(),
          const ReportsListPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomSelectedIndex,
        onDestinationSelected: _onBottomDestinationSelected,
        backgroundColor: shellBg,
        indicatorColor: _suppressBottomNavIndicator
            ? Colors.transparent
            : const Color(0xFFECECEE),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Image.asset(
              "assets/images/homes.png",
              width: 22,
              height: 22,
              color: _selectedIndex == 0
                  ? AppColors.inkStrong
                  : HexColor("#4B5563"),
            ),
            selectedIcon: Image.asset(
              "assets/images/homes.png",
              width: 22,
              height: 22,
              color: _selectedIndex == 0
                  ? AppColors.inkStrong
                  : HexColor("#4B5563"),
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Image.asset(
              "assets/images/client.png",
              width: 22,
              height: 22,
              color: _selectedIndex == 1
                  ? AppColors.inkStrong
                  : HexColor("#4B5563"),
            ),
            selectedIcon: Image.asset(
              "assets/images/client.png",
              width: 22,
              height: 22,
              color: _selectedIndex == 1
                  ? AppColors.inkStrong
                  : HexColor("#4B5563"),
            ),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Image.asset(
              "assets/images/files.png",
              width: 22,
              height: 22,
              color: _selectedIndex == 3
                  ? AppColors.inkStrong
                  : HexColor("#4B5563"),
            ),
            selectedIcon: Image.asset(
              "assets/images/files.png",
              width: 22,
              height: 22,
              color: _selectedIndex == 3
                  ? AppColors.inkStrong
                  : HexColor("#4B5563"),
            ),
            label: 'Projects',
          ),
          if (_navMenuStyle == NavMenuStyle.bottomSheet)
            NavigationDestination(
              icon: Icon(
                Icons.more_horiz_rounded,
                size: 26,
                color: _bottomSelectedIndex == 3
                    ? AppColors.inkStrong
                    : HexColor('#4B5563'),
              ),
              selectedIcon: const Icon(
                Icons.more_horiz_rounded,
                size: 26,
                color: AppColors.inkStrong,
              ),
              label: 'More',
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton:
          (_selectedIndex == 3 ||
              _selectedIndex == 8 ||
              _selectedIndex == 9 ||
              _selectedIndex == 10 ||
              _selectedIndex == 11 ||
              _selectedIndex == 12)
          ? FloatingActionButton(
              heroTag: _selectedIndex == 8
                  ? 'dashboard_quotation_create_fab'
                  : _selectedIndex == 9
                  ? 'dashboard_jobs_create_fab'
                  : _selectedIndex == 10
                  ? 'dashboard_invoices_create_fab'
                  : _selectedIndex == 11
                  ? 'dashboard_purchase_orders_create_fab'
                  : _selectedIndex == 12
                  ? 'dashboard_bills_create_fab'
                  : 'dashboard_create_quote',
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
