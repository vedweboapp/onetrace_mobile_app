import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/employee_toolbar_header.dart';
import 'package:red5/employee_role/reports/data/employee_reports_data.dart';
import 'package:red5/employee_role/reports/presentation/employee_report_product_detail_page.dart';
import 'package:red5/employee_role/reports/presentation/widgets/reports_list_widgets.dart';
import 'package:red5/employee_role/sites/presentation/employee_site_detail_page.dart';

/// Operative Reports — Site-wise / Product-wise inventory views.
class EmployeeReportsPage extends StatefulWidget {
  const EmployeeReportsPage({super.key});

  static const path = '/employee-role/reports';
  static const name = 'employee-reports';

  @override
  State<EmployeeReportsPage> createState() => _EmployeeReportsPageState();
}

class _EmployeeReportsPageState extends State<EmployeeReportsPage> {
  static const _tabs = ['Site-wise', 'Product-wise'];

  int _tabIndex = 1;
  final _siteSearchController = TextEditingController();
  String _siteQuery = '';

  @override
  void dispose() {
    _siteSearchController.dispose();
    super.dispose();
  }

  List<EmployeeReportSite> get _visibleSites {
    final q = _siteQuery.trim().toLowerCase();
    if (q.isEmpty) return EmployeeReportsData.sites;
    return EmployeeReportsData.sites
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.address.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmployeeToolbarHeader(
              title: 'Reports',
              onBack: () => context.pop(),
              onSettingsPressed: () => context.push(
                EmployeeTechnicianSettingsRoutes.personalProfile,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: _ReportsSegmentedTabs(
                tabs: _tabs,
                selectedIndex: _tabIndex,
                onChanged: (index) => setState(() => _tabIndex = index),
              ),
            ),
            Expanded(
              child: _tabIndex == 0
                  ? _SiteWiseBody(
                      searchController: _siteSearchController,
                      sites: _visibleSites,
                      onSearchChanged: (v) => setState(() => _siteQuery = v),
                      onSiteTap: (site) {
                        context.push(
                          EmployeeSiteDetailPage.path,
                          extra: site,
                        );
                      },
                    )
                  : _ProductWiseBody(
                      products: EmployeeReportsData.products,
                      onProductTap: (product) {
                        context.push(
                          EmployeeReportProductDetailPage.path,
                          extra: product,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsSegmentedTabs extends StatelessWidget {
  const _ReportsSegmentedTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? AppColors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: selectedIndex == i
                        ? const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[i],
                    style: AppFonts.titleSmall(
                      color: selectedIndex == i
                          ? AppColors.inkStrong
                          : AppColors.muted,
                    ).copyWith(
                      fontWeight:
                          selectedIndex == i ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductWiseBody extends StatelessWidget {
  const _ProductWiseBody({
    required this.products,
    required this.onProductTap,
  });

  final List<EmployeeReportProduct> products;
  final ValueChanged<EmployeeReportProduct> onProductTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];
        return ReportProductListCard(
          product: product,
          onTap: () => onProductTap(product),
        );
      },
    );
  }
}

class _SiteWiseBody extends StatelessWidget {
  const _SiteWiseBody({
    required this.searchController,
    required this.sites,
    required this.onSearchChanged,
    required this.onSiteTap,
  });

  final TextEditingController searchController;
  final List<EmployeeReportSite> sites;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<EmployeeReportSite> onSiteTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportsSearchField(
          controller: searchController,
          hintText: 'Search sites...',
          onChanged: onSearchChanged,
        ),
        Expanded(
          child: sites.isEmpty
              ? Center(
                  child: Text(
                    'No sites found.',
                    style: AppFonts.bodyMedium(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  itemCount: sites.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final site = sites[index];
                    return ReportSiteListCard(
                      site: site,
                      onTap: () => onSiteTap(site),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
