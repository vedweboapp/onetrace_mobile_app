import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_confirmation_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_form_page.dart';
import 'package:red5/employee_role/jobs/presentation/employee_job_safety_verification_page.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_detail_widgets.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_form_picker_sheet.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_photo_capture_sheet.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_timer_banner.dart';

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
  bool _safetyRedirectChecked = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(employeeJobDetailControllerProvider.notifier)
          .load(jobId: widget.jobId);
    });
  }

  void _redirectToSafetyIfNeeded(EmployeeJobDetailState state) {
    if (_safetyRedirectChecked || widget.jobId == null) return;
    final job = state.job;
    if (job == null || state.isLoading) return;

    _safetyRedirectChecked = true;
    final session = ref.read(employeeJobSessionProvider.notifier);
    final needsSafety = session.needsSafetyVerification(
      jobId: widget.jobId!,
      status: _statusFromLabel(job.currentStatus),
    );
    if (!needsSafety) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pushReplacement(
        EmployeeJobSafetyVerificationPage.path,
        extra: <String, Object?>{'jobId': widget.jobId},
      );
    });
  }

  EmployeeJobStatus _statusFromLabel(String label) {
    final normalized = label.trim().toUpperCase();
    if (normalized.contains('PROGRESS')) return EmployeeJobStatus.inProgress;
    if (normalized.contains('COMPLETE')) return EmployeeJobStatus.completed;
    if (normalized.contains('PENDING')) return EmployeeJobStatus.pending;
    return EmployeeJobStatus.upcoming;
  }

  Future<void> _openPhotoCaptureSheet() async {
    final state = ref.read(employeeJobDetailControllerProvider);
    final result = await showEmployeeJobPhotoCaptureSheet(
      context: context,
      beforeBytes: state.beforePhotoBytes,
      beforeName: state.beforePhotoName,
      afterBytes: state.afterPhotoBytes,
      afterName: state.afterPhotoName,
    );
    if (!mounted || result == null) return;
    if (result.beforeBytes == null || result.afterBytes == null) return;

    ref.read(employeeJobDetailControllerProvider.notifier).setJobPhotos(
          beforeBytes: result.beforeBytes!,
          beforeName: result.beforeName ?? 'before-photo.jpg',
          afterBytes: result.afterBytes!,
          afterName: result.afterName ?? 'after-photo.jpg',
        );
  }

  Future<void> _openMaterialSheet() async {
    final controller = ref.read(employeeJobDetailControllerProvider.notifier);
    final current = ref.read(employeeJobDetailControllerProvider).materialUsed;

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => _MaterialUsedSheet(initialValue: current),
    );

    if (value != null && mounted) {
      controller.updateMaterialUsed(value);
    }
  }

  Future<void> _openSignatureSheet() async {
    final captured = ref
        .read(employeeJobDetailControllerProvider)
        .customerSignatureCaptured;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: EmployeeJobSignatureCapture(
              captured: captured,
              onCapture: () {
                ref
                    .read(employeeJobDetailControllerProvider.notifier)
                    .setCustomerSignatureCaptured(true);
                Navigator.of(context).pop();
              },
              onClear: () {
                ref
                    .read(employeeJobDetailControllerProvider.notifier)
                    .setCustomerSignatureCaptured(false);
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      },
    );
  }

  void _onRequiredFormItemTap(String itemId) {
    switch (itemId) {
      case 'before_photo':
        _openPhotoCaptureSheet();
      case 'material_used':
        _openMaterialSheet();
      case 'signature':
        _openSignatureSheet();
      case 'linked_forms':
        _openFormPicker();
      default:
        break;
    }
  }

  Future<void> _openFormPicker() async {
    final state = ref.read(employeeJobDetailControllerProvider);
    final selected = await showEmployeeJobFormPickerSheet(
      context: context,
      selectedFormId: state.selectedFormId,
      forms: [
        for (final formId in state.formIds)
          EmployeeJobFormOption(
            formId: formId,
            title: state.titleForForm(formId),
            isComplete: state.completedFormIds.contains(formId),
          ),
      ],
    );
    if (selected == null || !mounted) return;
    context.push(
      EmployeeJobFormPage.path,
      extra: <String, Object?>{
        'formId': selected,
        'jobId': widget.jobId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeJobDetailControllerProvider);
    final controller = ref.read(employeeJobDetailControllerProvider.notifier);
    final session = ref.watch(employeeJobSessionProvider);
    final job = state.job;

    _redirectToSafetyIfNeeded(state);

    final dynamicFormComplete = state.formIds.isEmpty
        ? false
        : state.formIds.every(state.completedFormIds.contains);

    final canSubmit = controller.canSubmit(
      dynamicFormComplete: dynamicFormComplete,
    );

    final requiredItems = job == null
        ? const <EmployeeRequiredFormItem>[]
        : buildEmployeeRequiredFormItems(
            job: job,
            formIds: state.formIds,
            completedFormIds: state.completedFormIds,
            hasBeforePhoto: state.hasJobPhotos,
            hasMaterialUsed: state.materialUsed.trim().isNotEmpty,
            hasCustomerSignature: state.customerSignatureCaptured,
            dynamicFormComplete: dynamicFormComplete,
          );

    final timerElapsed = widget.jobId == null
        ? Duration.zero
        : session.elapsedFor(widget.jobId!);

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
                      if (ref
                          .read(employeeJobSessionProvider.notifier)
                          .isJobStarted(job.id)) ...[
                        EmployeeJobTimerBanner(elapsed: timerElapsed),
                        const SizedBox(height: 16),
                      ],
                      EmployeeJobStatusCard(status: job.currentStatus),
                      const SizedBox(height: 24),
                      EmployeeJobInfoSection(job: job),
                      const SizedBox(height: 28),
                      EmployeeJobItemsCard(items: job.items),
                      const SizedBox(height: 22),
                      EmployeeJobTabs(
                        selectedTab: state.selectedTab,
                        onChanged: controller.selectTab,
                      ),
                      const SizedBox(height: 18),
                      if (state.selectedTab == EmployeeJobDetailTab.forms) ...[
                        EmployeeRequiredFormChecklist(
                          items: requiredItems,
                          onItemTap: _onRequiredFormItemTap,
                        ),
                        if (state.hasJobPhotos) ...[
                          const SizedBox(height: 24),
                          EmployeeJobPhotosPreview(
                            beforeBytes: state.beforePhotoBytes!,
                            afterBytes: state.afterPhotoBytes!,
                            onEdit: _openPhotoCaptureSheet,
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (state.formIds.isEmpty) ...[
                          const SizedBox(height: 26),
                          EmployeeSafetyChecklist(
                            items: job.safetyChecklist,
                            onChanged: controller.toggleChecklistItem,
                          ),
                        ],
                      ] else
                        const EmployeeJobLocationPanel(),
                    ],
                  ),
                ),
                _SubmitBar(
                  enabled: canSubmit,
                  onSubmit: canSubmit
                      ? () {
                          context.push(
                            EmployeeJobConfirmationPage.path,
                            extra: <String, Object?>{
                              'jobId': job.id,
                              'jobTitle': job.title,
                            },
                          );
                        }
                      : null,
                ),
              ],
            ),
    );
  }
}

class _MaterialUsedSheet extends StatefulWidget {
  const _MaterialUsedSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_MaterialUsedSheet> createState() => _MaterialUsedSheetState();
}

class _MaterialUsedSheetState extends State<_MaterialUsedSheet> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(_textController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Material Used',
              style: AppFonts.titleLarge(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _textController,
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: 'Enter material used',
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.inkStrong,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.enabled, required this.onSubmit});

  final bool enabled;
  final VoidCallback? onSubmit;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!enabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Complete all required sections to submit.',
                    textAlign: TextAlign.center,
                    style: AppFonts.bodySmall(color: AppColors.muted),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.inkStrong,
                    disabledBackgroundColor: const Color(0xFFB8B8BE),
                    foregroundColor: AppColors.white,
                    disabledForegroundColor: AppColors.white,
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
            ],
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
