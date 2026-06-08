import 'package:flutter/material.dart';
import 'package:red5/employee_role/data/app_role.dart';
import 'package:red5/employee_role/presentation/widgets/role_home_scaffold.dart';

class TechnicianHomePage extends StatelessWidget {
  const TechnicianHomePage({super.key});

  static const path = '/employee-role/technician';
  static const name = 'technician-home';

  @override
  Widget build(BuildContext context) {
    return const RoleHomeScaffold(
      role: AppRole.technician,
      primaryActions: [
        RoleActionItem(
          title: 'Assigned Jobs',
          subtitle: 'View job cards, materials, forms, and QR tasks.',
          icon: Icons.assignment_turned_in_rounded,
        ),
        RoleActionItem(
          title: 'Scan QR',
          subtitle: 'Open a job or asset using the QR scanner.',
          icon: Icons.qr_code_scanner_rounded,
        ),
        RoleActionItem(
          title: 'Daily Progress',
          subtitle: 'Update field progress and attach photos.',
          icon: Icons.timeline_rounded,
        ),
      ],
    );
  }
}
