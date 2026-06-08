import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/employee_toolbar_header.dart';
import 'package:red5/employee_role/reports/data/employee_reports_data.dart';
import 'package:red5/employee_role/reports/presentation/employee_report_product_detail_page.dart';
import 'package:red5/employee_role/reports/presentation/widgets/reports_list_widgets.dart';

class EmployeeReportsPage extends StatelessWidget {
  const EmployeeReportsPage({super.key});

  static const path = '/employee-role/reports';
  static const name = 'employee-reports';

  @override
  Widget build(BuildContext context) {
    final products = EmployeeReportsData.products;

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
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                itemCount: products.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ReportProductListCard(
                    product: product,
                    onTap: () {
                      context.push(
                        EmployeeReportProductDetailPage.path,
                        extra: product,
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
