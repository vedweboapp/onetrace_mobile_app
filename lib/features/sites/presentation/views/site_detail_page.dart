import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/sites/data/site_models.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';
import 'package:red5/features/sites/presentation/views/add_site_page.dart';

/// Read-only details view for a single site. Loads via `GET /item/{id}/`.
class SiteDetailPage extends ConsumerStatefulWidget {
  const SiteDetailPage({super.key, required this.siteId});

  static const pathPrefix = '/sites';
  static const name = 'site-detail';

  static String pathFor(String id) => '$pathPrefix/$id';

  final String siteId;

  @override
  ConsumerState<SiteDetailPage> createState() => _SiteDetailPageState();
}

class _SiteDetailPageState extends ConsumerState<SiteDetailPage> {
  SiteModel? _site;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.siteId.trim();
    if (id.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid site id';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(sitesApiClientProvider);
      final data = await api.fetchSiteDetail(id);
      if (!mounted) return;
      setState(() {
        _site = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load site details',
        );
      });
    }
  }

  Future<void> _openEdit() async {
    final current = _site;
    if (current == null) return;
    final updated = await Navigator.of(context).push<SiteModel>(
      MaterialPageRoute(
        settings: const RouteSettings(name: AddSitePage.name),
        builder: (_) => AddSitePage(existing: current),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      setState(() => _site = updated);
    }
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 12),
      child: Text(
        text,
        style: AppFonts.titleMedium(
          color: AppColors.inkStrong,
        ).copyWith(fontWeight: FontWeight.w800, fontSize: 20),
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value.trim().isEmpty ? '—' : value.trim(),
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
        ),
      ],
    );
  }

  Widget _streetAddress(SiteModel s) {
    final hasLine2 = s.addressLine2.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STREET ADDRESS',
          style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.addressLine1.trim().isEmpty ? '—' : s.addressLine1.trim(),
          style: AppFonts.bodyMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        if (hasLine2) ...[
          const SizedBox(height: 2),
          Text(
            s.addressLine2.trim(),
            style: AppFonts.bodyMedium(
              color: AppColors.muted,
            ).copyWith(fontSize: 15),
          ),
        ],
      ],
    );
  }

  Widget _buildOverviewTab(SiteModel s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _sectionHeader('Basic Info'),
        _labelValue('Site Name', s.siteName),
        const SizedBox(height: 14),
        _labelValue('Client Name', s.clientName),
        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0xFFE2E2E4)),
        _sectionHeader('Address'),
        _streetAddress(s),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labelValue('City', s.city)),
            const SizedBox(width: 16),
            Expanded(child: _labelValue('State / Province', s.state)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _labelValue('Postal Code', s.postalCode)),
            const SizedBox(width: 16),
            Expanded(child: _labelValue('Country', s.country)),
          ],
        ),
      ],
    );
  }

  List<Map<String, String>> _mockProjectsFor(SiteModel s) {
    final baseClient = s.clientName.trim().isEmpty
        ? 'Client Name'
        : s.clientName.trim();
    return [
      {
        'title': '${s.siteName} - Northview Commercial Complex',
        'client': baseClient,
      },
      {'title': 'Skyline Residential Tower', 'client': baseClient},
      {'title': '${s.siteName} - Phase 2', 'client': baseClient},
    ];
  }

  Widget _buildProjectTab(SiteModel s) {
    final projects = _mockProjectsFor(s);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemBuilder: (context, index) {
        final project = projects[index];
        return Container(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E2E4), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project['title'] ?? '',
                style: AppFonts.bodyLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                project['client'] ?? '',
                style: AppFonts.bodySmall(
                  color: AppColors.muted,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemCount: projects.length,
    );
  }

  Widget _buildLoaded(SiteModel s) {
    final siteTitle = s.siteName.trim().isEmpty
        ? 'Site Name'
        : s.siteName.trim();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
          ),
          title: Text(
            siteTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.titleMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Material(
                color: const Color(0xFFF1F1F2),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isLoading || _site == null ? null : _openEdit,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/images/edit_icon.png',
                      color: AppColors.inkStrong,
                      height: 15,
                      width: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1, color: Color(0xFFE2E2E4)),
                TabBar(
                  labelColor: AppColors.inkStrong,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.inkStrong,
                  indicatorWeight: 2,
                  labelStyle: AppFonts.labelMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800),
                  unselectedLabelStyle: AppFonts.labelMedium(
                    color: AppColors.muted,
                  ).copyWith(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Project'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(children: [_buildOverviewTab(s), _buildProjectTab(s)]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: AppSkeletonScreenBody(scrollable: false, toastBlockCount: 4),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
          ),
          title: const Text('Site Details'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppFonts.bodyMedium(color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final site = _site;
    if (site == null) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(child: Text('No site details found.')),
      );
    }

    return _buildLoaded(site);
  }
}
