import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/application/employee_job_detail_controller.dart';
import 'package:red5/employee_role/jobs/application/operative_canvas_bridge.dart';
import 'package:red5/employee_role/jobs/application/operative_last_working_pin.dart';
import 'package:red5/employee_role/jobs/application/operative_pin_workflow.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_detail_widgets.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_drawing_card.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_page.dart';

class OperativeJobWorkflowPage extends ConsumerStatefulWidget {
  const OperativeJobWorkflowPage({
    super.key,
    required this.jobId,
    this.skipChecklist = false,
  });

  static const path = '/employee-role/jobs/workflow';
  static const name = 'operative-job-workflow';

  final int jobId;
  final bool skipChecklist;

  static OperativeJobWorkflowPage? fromExtra(Object? extra) {
    if (extra is! Map) return null;
    final map = Map<String, dynamic>.from(extra);
    final rawJobId = map['jobId'];
    final jobId = rawJobId is int
        ? rawJobId
        : int.tryParse(rawJobId?.toString() ?? '');
    if (jobId == null || jobId <= 0) return null;

    final rawSkip = map['skipChecklist'];
    final skipChecklist =
        rawSkip == true || rawSkip?.toString().toLowerCase() == 'true';

    return OperativeJobWorkflowPage(
      jobId: jobId,
      skipChecklist: skipChecklist,
    );
  }

  @override
  ConsumerState<OperativeJobWorkflowPage> createState() =>
      _OperativeJobWorkflowPageState();
}

class _OperativeJobWorkflowPageState
    extends ConsumerState<OperativeJobWorkflowPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref
          .read(employeeJobDetailControllerProvider.notifier)
          .load(jobId: widget.jobId);
      _registerCanvasBridge();
    });
  }

  @override
  void dispose() {
    OperativeCanvasBridge.unregister(widget.jobId);
    super.dispose();
  }

  void _registerCanvasBridge() {
    if (!mounted) return;
    // Capture the container while this page is active. The canvas route sits
    // above this page and deactivates it; `ref.read` then fails ancestor lookup.
    final container = ProviderScope.containerOf(context, listen: false);
    OperativeCanvasBridge.register(
      jobId: widget.jobId,
      onPinTap: (hostContext, pinId) async {
        await handleOperativePinTap(
          context: hostContext,
          container: container,
          jobId: widget.jobId,
          pinId: pinId,
          skipChecklist: widget.skipChecklist,
        );
      },
      isPinComplete: (pinId) {
        final state = container.read(employeeJobDetailControllerProvider);
        final job = state.job;
        if (job == null) return false;
        final pin = findEmployeeJobPinById(job.levels, pinId);
        if (pin == null) return false;
        return isOperativePinComplete(pin, state);
      },
    );
  }

  List<EmployeeJobDrawingLevel> _designLevels(EmployeeJobDetail job) {
    return job.levels
        .where((level) => level.drawingFileUrl?.trim().isNotEmpty == true)
        .toList(growable: false);
  }

  Future<void> _openDrawing(
    EmployeeJobDetail job,
    EmployeeJobDrawingLevel level,
  ) async {
    final url = resolveEmployeeDrawingFileUrl(level.drawingFileUrl);
    if (url == null || url.isEmpty) return;

    final container = ProviderScope.containerOf(context);
    final started = await ensureOperativeJobStartedForForms(
      context: context,
      container: container,
      jobId: widget.jobId,
      job: job,
      skipChecklist: widget.skipChecklist,
    );
    if (!mounted || !started) return;

    final state = ref.read(employeeJobDetailControllerProvider);
    final lastWorkingPinId = await OperativeLastWorkingPin.read(
      jobId: widget.jobId,
      levelId: level.id,
    );
    final focusPinId = resolveOperativeFocusPinId(
      level: level,
      state: state,
      lastWorkingPinId: lastWorkingPinId,
    );

    if (!mounted) return;
    _registerCanvasBridge();
    await DrawingCanvasPage.push(
      context,
      DrawingCanvasArgs(
        title: level.name,
        remoteDrawingUrl: url,
        levelName: level.name,
        projectName: job.project,
        projectId: job.projectId?.toString(),
        levelId: level.id.toString(),
        embeddedLevelPlots: level.plotPayloads,
        operativeWorkflow: true,
        operativeJobId: widget.jobId,
        focusPinId: focusPinId,
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _onFormItemTap(EmployeeJobDetail job, String itemId) async {
    if (itemId.startsWith('form_')) {
      final formId = int.tryParse(itemId.substring(5));
      if (formId == null || formId <= 0) return;
      final container = ProviderScope.containerOf(context);
      final started = await ensureOperativeJobStartedForForms(
        context: context,
        container: container,
        jobId: widget.jobId,
        job: job,
        skipChecklist: widget.skipChecklist,
      );
      if (!mounted || !started) return;
      await openOperativeJobForm(
        context: context,
        container: container,
        jobId: widget.jobId,
        formId: formId,
      );
      return;
    }

    switch (itemId) {
      case 'linked_forms':
        final container = ProviderScope.containerOf(context);
        final started = await ensureOperativeJobStartedForForms(
          context: context,
          container: container,
          jobId: widget.jobId,
          job: job,
          skipChecklist: widget.skipChecklist,
        );
        if (!mounted || !started) return;

        final state = ref.read(employeeJobDetailControllerProvider);
        final formIds = state.formIds.isNotEmpty
            ? state.formIds
            : job.linkedFormIds;
        if (formIds.isEmpty) return;

        if (formIds.length == 1) {
          await openOperativeJobForm(
            context: context,
            container: container,
            jobId: widget.jobId,
            formId: formIds.first,
          );
          return;
        }

        for (final formId in formIds) {
          if (!mounted) break;
          final refreshed = ref.read(employeeJobDetailControllerProvider);
          if (refreshed.completedFormIds.contains(formId)) continue;
          await openOperativeJobForm(
            context: context,
            container: container,
            jobId: widget.jobId,
            formId: formId,
          );
        }
        return;
      case 'qr_scan':
        await scanOperativeJobQr(
          context: context,
          container: ProviderScope.containerOf(context),
          jobId: widget.jobId,
          skipChecklist: widget.skipChecklist,
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeJobDetailControllerProvider);
    final job = state.job;

    ref.listen(employeeJobDetailControllerProvider, (previous, next) {
      if (previous?.completedPinFormKeys != next.completedPinFormKeys ||
          previous?.scannedPinQrKeys != next.scannedPinQrKeys) {
        OperativeCanvasBridge.notifyCompletionChanged(widget.jobId);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          job?.title ?? 'Job',
          style: AppFonts.titleSmall(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      body: state.isLoading && job == null
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null && job == null
              ? _ErrorBody(
                  message: state.errorMessage!,
                  onRetry: () => ref
                      .read(employeeJobDetailControllerProvider.notifier)
                      .load(jobId: widget.jobId),
                )
              : job == null
                  ? const _ErrorBody(message: 'Job not found.')
                  : job.usesDesignsWorkflow
                      ? _DesignsBody(
                          job: job,
                          designLevels: _designLevels(job),
                          onOpenDrawing: (level) => _openDrawing(job, level),
                        )
                      : _FormsBody(
                          job: job,
                          state: state,
                          onItemTap: (itemId) => _onFormItemTap(job, itemId),
                          onComplete: () => completeOperativeJob(
                            context: context,
                            container: ProviderScope.containerOf(context),
                            jobId: widget.jobId,
                          ),
                        ),
    );
  }
}

class _DesignsBody extends StatelessWidget {
  const _DesignsBody({
    required this.job,
    required this.designLevels,
    required this.onOpenDrawing,
  });

  final EmployeeJobDetail job;
  final List<EmployeeJobDrawingLevel> designLevels;
  final ValueChanged<EmployeeJobDrawingLevel> onOpenDrawing;

  @override
  Widget build(BuildContext context) {
    final pinCount =
        job.levels.fold<int>(0, (sum, level) => sum + level.pinCount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Designs',
          style: AppFonts.titleLarge(color: AppColors.inkStrong)
              .copyWith(fontWeight: FontWeight.w900, fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          pinCount > 0
              ? 'Open a drawing to start. You’ll confirm the checklist first, then tap pins to fill forms.'
              : 'Open a drawing to review site plans.',
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        if (designLevels.isEmpty)
          Text(
            'No drawings attached to this job.',
            style: AppFonts.bodyMedium(color: AppColors.muted),
          )
        else
          for (var i = 0; i < designLevels.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _DesignCard(
              job: job,
              level: designLevels[i],
              onTap: () => onOpenDrawing(designLevels[i]),
            ),
          ],
      ],
    );
  }
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({
    required this.job,
    required this.level,
    required this.onTap,
  });

  final EmployeeJobDetail job;
  final EmployeeJobDrawingLevel level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plotCount = level.plots.length;
    final subtitle = plotCount > 0
        ? 'Level ${level.order} • $plotCount plot${plotCount == 1 ? '' : 's'}'
        : 'Level ${level.order}';

    return EmployeeJobDrawingCard(
      title: level.name,
      subtitle: subtitle,
      updatedLabel: level.pinCount > 0
          ? '${level.pinCount} pin${level.pinCount == 1 ? '' : 's'} on drawing'
          : 'Drawing available',
      drawingFileUrl: resolveEmployeeDrawingFileUrl(level.drawingFileUrl),
      cacheKey: 'job-${job.id}-level-${level.id}',
      onTap: onTap,
    );
  }
}

class _FormsBody extends StatelessWidget {
  const _FormsBody({
    required this.job,
    required this.state,
    required this.onItemTap,
    required this.onComplete,
  });

  final EmployeeJobDetail job;
  final EmployeeJobDetailState state;
  final ValueChanged<String> onItemTap;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final items = buildEmployeeRequiredFormItems(
      job: job,
      formIds: state.formIds,
      completedFormIds: state.completedFormIds,
      completedPinFormKeys: state.completedPinFormKeys,
      hasQrScan: state.qrCodeScanned,
      dynamicFormComplete: state.allRequiredFormsComplete,
      formHasQrFields: state.formHasQrFields,
      showJobQrScan: job.hasJobQrField,
      formTitles: state.formTitles,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                'Required Forms',
                style: AppFonts.titleLarge(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w900, fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete each form to finish this job.',
                style: AppFonts.bodyMedium(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              EmployeeRequiredFormChecklist(
                items: items,
                onItemTap: onItemTap,
              ),
            ],
          ),
        ),
        if (state.allRequiredFormsComplete)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: onComplete,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.inkStrong,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Complete Job'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

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
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
