import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/employee_toolbar_header.dart';
import 'package:red5/employee_role/material_requests/presentation/employee_material_request_detail_page.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_requests_list_body.dart';

/// Operative material requests list — opened from the More menu card.
/// Operatives view existing requests only (no create FAB).
class EmployeeMaterialRequestsPage extends StatelessWidget {
  const EmployeeMaterialRequestsPage({super.key});

  static const path = '/employee-role/material-requests';
  static const name = 'employee-material-requests';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmployeeToolbarHeader(
              title: 'Material Requests',
              onBack: () => context.pop(),
              onSettingsPressed: () => context.push(
                EmployeeTechnicianSettingsRoutes.personalProfile,
              ),
            ),
            Expanded(
              child: MaterialRequestsListBody(
                alwaysShowSearch: true,
                searchHorizontalPadding: 18,
                listBottomPadding: 24,
                scopeToCurrentWorker: true,
                detailPathFor: EmployeeMaterialRequestDetailPage.pathFor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
