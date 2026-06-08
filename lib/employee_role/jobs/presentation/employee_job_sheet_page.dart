import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/employee_role/jobs/data/employee_job_sheet.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_sheet_detail_page.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_sheet_widgets.dart';
import 'package:red5/employee_role/presentation/widgets/employee_toolbar_header.dart';

class EmployeeJobSheetPage extends StatelessWidget {
  const EmployeeJobSheetPage({super.key});

  static const path = '/employee-role/job-sheet';
  static const name = 'employee-job-sheet';

  @override
  Widget build(BuildContext context) {
    final jobs = EmployeeJobSheetData.jobs;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmployeeToolbarHeader(
              title: 'Jobs Sheet',
              onBack: () => context.pop(),
              onSettingsPressed: () => context.push(
                EmployeeTechnicianSettingsRoutes.personalProfile,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                itemCount: jobs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return JobSheetJobCard(
                    job: job,
                    onViewDetails: () {
                      context.push(
                        EmployeeJobSheetDetailPage.path,
                        extra: job,
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
