import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/employee_role/data/app_role.dart';
import 'package:red5/employee_role/jobs/presentation/employee_qr_scan_page.dart';
import 'package:red5/employee_role/presentation/widgets/role_home_scaffold.dart';

enum EmployeeShellTab {
  home(0),
  jobs(1),
  projects(2);

  const EmployeeShellTab(this.navIndex);

  final int navIndex;

  static EmployeeShellTab fromExtra(Object? extra) {
    if (extra is Map) {
      final raw = extra['navPage'];
      if (raw is int) {
        return EmployeeShellTab
            .values[raw.clamp(0, EmployeeShellTab.values.length - 1)];
      }
      if (raw is String) {
        return switch (raw) {
          'jobs' => EmployeeShellTab.jobs,
          'projects' => EmployeeShellTab.projects,
          _ => EmployeeShellTab.home,
        };
      }
    }
    return EmployeeShellTab.home;
  }
}

class TechnicianHomePage extends StatelessWidget {
  const TechnicianHomePage({super.key, this.initialNavPageIndex = 0});

  static const path = '/employee-role/technician';
  static const name = 'technician-home';

  final int initialNavPageIndex;

  static void go(
    BuildContext context, {
    EmployeeShellTab tab = EmployeeShellTab.home,
  }) {
    context.go(
      path,
      extra: <String, Object?>{'navPage': tab.navIndex},
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      role: AppRole.technician,
      initialNavPageIndex: initialNavPageIndex,
      primaryActions: [
        const RoleActionItem(
          title: 'Assigned Jobs',
          subtitle: 'View job cards, materials, forms, and QR tasks.',
          icon: Icons.assignment_turned_in_rounded,
        ),
        RoleActionItem(
          title: 'Scan QR',
          subtitle: 'Open a job or asset using the QR scanner.',
          icon: Icons.qr_code_scanner_rounded,
          onTap: () => context.push(EmployeeQrScanPage.path),
        ),
        const RoleActionItem(
          title: 'Daily Progress',
          subtitle: 'Update field progress and attach photos.',
          icon: Icons.timeline_rounded,
        ),
      ],
    );
  }
}
