import 'package:flutter/material.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';

/// Technician / worker personal profile — same UI as admin with `/user-profile/` API.
class EmployeePersonalProfilePage extends StatelessWidget {
  const EmployeePersonalProfilePage({super.key});

  static const path = EmployeeTechnicianSettingsRoutes.personalProfile;
  static const name = 'technician-personal-profile';

  @override
  Widget build(BuildContext context) {
    return const PersonalProfilePage(useTechnicianSettingsNav: true);
  }
}
