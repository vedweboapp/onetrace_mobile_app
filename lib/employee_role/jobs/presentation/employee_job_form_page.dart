import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/forms/application/technician_form_controller.dart';
import 'package:red5/employee_role/forms/application/technician_form_sync_listener.dart';
import 'package:red5/employee_role/forms/presentation/widgets/dynamic_form_view.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';

class EmployeeJobFormPage extends ConsumerStatefulWidget {
  const EmployeeJobFormPage({
    super.key,
    required this.formId,
    this.jobId,
  });

  static const path = '/employee-role/jobs/form';
  static const name = 'employee-job-form';

  final int formId;
  final int? jobId;

  @override
  ConsumerState<EmployeeJobFormPage> createState() =>
      _EmployeeJobFormPageState();
}

class _EmployeeJobFormPageState extends ConsumerState<EmployeeJobFormPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadForm);
  }

  Future<void> _loadForm() async {
    final jobController =
        ref.read(employeeJobDetailControllerProvider.notifier);
    jobController.selectForm(widget.formId);

    await ref.read(technicianFormControllerProvider.notifier).load(widget.formId);

    if (!mounted) return;
    final formState = ref.read(technicianFormControllerProvider);
    if (formState.bundle != null) {
      jobController.markFormComplete(widget.formId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(technicianFormControllerProvider);
    final jobState = ref.watch(employeeJobDetailControllerProvider);
    final title = jobState.titleForForm(widget.formId);

    return TechnicianFormSyncListener(
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.inkStrong,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 44,
          leadingWidth: 42,
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () {
              if (context.canPop()) context.pop();
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.titleSmall(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),
        ),
        body: formState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : formState.errorMessage != null
                ? _FormErrorState(
                    message: formState.errorMessage!,
                    onRetry: _loadForm,
                  )
                : formState.bundle == null
                    ? Center(
                        child: Text(
                          'No form data available.',
                          style: AppFonts.bodyMedium(color: AppColors.muted),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          TechnicianFormOfflineBanner(
                            visible: formState.isOfflineCached ||
                                formState.syncStatus ==
                                    TechnicianFormSyncStatus.syncing,
                            isSyncing: formState.syncStatus ==
                                TechnicianFormSyncStatus.syncing,
                          ),
                          DynamicFormView(bundle: formState.bundle!),
                        ],
                      ),
      ),
    );
  }
}

class _FormErrorState extends StatelessWidget {
  const _FormErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.error),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
