import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/employee_toolbar_header.dart';
import 'package:red5/employee_role/reports/data/employee_reports_data.dart';
import 'package:red5/employee_role/reports/presentation/widgets/reports_list_widgets.dart';
import 'package:red5/employee_role/sites/presentation/employee_site_detail_page.dart';

/// Technician site directory: search + site cards → [EmployeeSiteDetailPage].
class EmployeeSitesPage extends StatefulWidget {
  const EmployeeSitesPage({super.key});

  static const path = '/employee-role/sites';
  static const name = 'employee-sites';

  @override
  State<EmployeeSitesPage> createState() => _EmployeeSitesPageState();
}

class _EmployeeSitesPageState extends State<EmployeeSitesPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeReportSite> get _visibleSites {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return EmployeeReportsData.sites;
    return EmployeeReportsData.sites
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.address.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final sites = _visibleSites;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.inkStrong,
        foregroundColor: AppColors.white,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmployeeToolbarHeader(
              title: 'Site',
              onBack: () => context.pop(),
              onSettingsPressed: () => context.push(
                EmployeeTechnicianSettingsRoutes.personalProfile,
              ),
            ),
            ReportsSearchField(
              controller: _searchController,
              hintText: 'Search sites...',
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 88),
                itemCount: sites.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final site = sites[index];
                  return ReportSiteListCard(
                    site: site,
                    onTap: () {
                      context.push(
                        EmployeeSiteDetailPage.path,
                        extra: site,
                      );
                    },
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
