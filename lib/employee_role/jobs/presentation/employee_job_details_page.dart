import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_confirmation_page.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_detail_widgets.dart';

class EmployeeJobDetailsPage extends ConsumerStatefulWidget {
  const EmployeeJobDetailsPage({super.key, this.jobId});

  static const path = '/employee-role/jobs/detail';
  static const name = 'employee-job-detail';

  final int? jobId;

  @override
  ConsumerState<EmployeeJobDetailsPage> createState() =>
      _EmployeeJobDetailsPageState();
}

class _EmployeeJobDetailsPageState
    extends ConsumerState<EmployeeJobDetailsPage> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _photoPickInFlight = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(employeeJobDetailControllerProvider.notifier)
          .load(jobId: widget.jobId);
    });
  }

  String _cameraErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('permission') || message.contains('denied')) {
      return 'Camera permission was denied.';
    }
    if (message.contains('camera')) return 'Could not open camera.';
    return 'Could not capture photo.';
  }

  Future<void> _captureBeforePhoto() async {
    if (_photoPickInFlight || !mounted) return;
    setState(() => _photoPickInFlight = true);

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (!mounted || picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      ref
          .read(employeeJobDetailControllerProvider.notifier)
          .setBeforePhoto(
            bytes: bytes,
            name: picked.name.trim().isEmpty ? 'before-photo.jpg' : picked.name,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_cameraErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _photoPickInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeJobDetailControllerProvider);
    final controller = ref.read(employeeJobDetailControllerProvider.notifier);
    final job = state.job;

    return Scaffold(
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
          job?.title ?? 'Job Details',
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
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
          ? _JobErrorState(
              message: state.errorMessage!,
              onRetry: () => controller.load(jobId: widget.jobId),
            )
          : job == null
          ? const _JobEmptyState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      EmployeeJobStatusCard(status: job.currentStatus),
                      const SizedBox(height: 24),
                      EmployeeJobInfoSection(job: job),
                      const SizedBox(height: 28),
                      EmployeeMaterialsCard(materials: job.materials),
                      const SizedBox(height: 22),
                      EmployeeJobTabs(
                        selectedTab: state.selectedTab,
                        onChanged: controller.selectTab,
                      ),
                      const SizedBox(height: 18),
                      if (state.selectedTab == EmployeeJobDetailTab.form) ...[
                        EmployeeBeforePhotoUpload(
                          photoBytes: state.beforePhotoBytes,
                          photoName: state.beforePhotoName,
                          isPicking: _photoPickInFlight,
                          onTap: _captureBeforePhoto,
                        ),
                        const SizedBox(height: 26),
                        EmployeeSafetyChecklist(
                          items: job.safetyChecklist,
                          onChanged: controller.toggleChecklistItem,
                        ),
                        const SizedBox(height: 20),
                        EmployeeMaterialUsedField(
                          value: state.materialUsed,
                          onChanged: controller.updateMaterialUsed,
                        ),
                      ] else
                        const EmployeeJobLocationPanel(),
                    ],
                  ),
                ),
                _SubmitBar(
                  onSubmit: () {
                    context.push(
                      EmployeeJobConfirmationPage.path,
                      extra: <String, Object?>{
                        'jobId': job.id,
                        'jobTitle': job.title,
                      },
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkStrong,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                'Submit Form',
                style: AppFonts.titleSmall(
                  color: AppColors.white,
                ).copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JobErrorState extends StatelessWidget {
  const _JobErrorState({required this.message, required this.onRetry});

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

class _JobEmptyState extends StatelessWidget {
  const _JobEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No job details found.',
        style: AppFonts.bodyMedium(color: AppColors.muted),
      ),
    );
  }
}
