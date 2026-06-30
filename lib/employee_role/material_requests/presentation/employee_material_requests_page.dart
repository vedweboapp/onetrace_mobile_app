import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/employee_toolbar_header.dart';
import 'package:red5/features/material_requests/presentation/views/create_material_request_page.dart';
import 'package:red5/features/material_requests/presentation/widgets/material_requests_list_body.dart';

/// Operative material requests list — opened from the More menu card.
class EmployeeMaterialRequestsPage extends StatelessWidget {
  const EmployeeMaterialRequestsPage({super.key});

  static const path = '/employee-role/material-requests';
  static const name = 'employee-material-requests';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'employee_material_requests_create_fab',
        onPressed: () => context.push(CreateMaterialRequestPage.path),
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
              title: 'Material Requests',
              onBack: () => context.pop(),
              onSettingsPressed: () => context.push(
                EmployeeTechnicianSettingsRoutes.personalProfile,
              ),
            ),
            const Expanded(
              child: MaterialRequestsListBody(
                alwaysShowSearch: true,
                searchHorizontalPadding: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
