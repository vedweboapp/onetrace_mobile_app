import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/employee_role/jobs/application/employee_job_session_controller.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_repository.dart';
import 'package:red5/employee_role/jobs/presentation/employee_checklist_pdf_page.dart';

/// One-time job safety checklist shown on the first pin interaction (Start Job).
Future<bool> showOperativePinChecklistSheet({
  required BuildContext context,
  required int jobId,
  required List<EmployeeSafetyChecklistItem> items,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _OperativePinChecklistSheet(
      jobId: jobId,
      initialItems: items,
    ),
  ).then((value) => value == true);
}

class _OperativePinChecklistSheet extends ConsumerStatefulWidget {
  const _OperativePinChecklistSheet({
    required this.jobId,
    required this.initialItems,
  });

  final int jobId;
  final List<EmployeeSafetyChecklistItem> initialItems;

  @override
  ConsumerState<_OperativePinChecklistSheet> createState() =>
      _OperativePinChecklistSheetState();
}

class _OperativePinChecklistSheetState
    extends ConsumerState<_OperativePinChecklistSheet> {
  late List<EmployeeSafetyChecklistItem> _items;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _items = [
      for (final item in widget.initialItems) item,
    ];
  }

  bool get _allRequiredChecked {
    final requiredItems =
        _items.where((item) => item.isRequired).toList(growable: false);
    if (requiredItems.isEmpty) return true;
    return requiredItems.every((item) => item.isChecked);
  }

  bool get _allConcentricSatisfied =>
      _items.every((item) => item.concentricPointSatisfied);

  bool get _canConfirm =>
      !_isSubmitting && _allRequiredChecked && _allConcentricSatisfied;

  void _toggleItem(String id) {
    setState(() {
      _items = [
        for (final item in _items)
          item.id == id ? item.copyWith(isChecked: !item.isChecked) : item,
      ];
    });
  }

  void _setConcentricPoint(String id, bool confirmed) {
    setState(() {
      _items = [
        for (final item in _items)
          item.id == id
              ? item.copyWith(concentricPointConfirmed: confirmed)
              : item,
      ];
    });
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(employeeJobRepositoryProvider);
      if (_items.isNotEmpty) {
        await repository.startJobWithChecklist(
          jobId: widget.jobId,
          items: _items,
        );
      } else {
        await repository.markJobStarted(widget.jobId);
      }
      ref.read(employeeJobSessionProvider.notifier).startJob(widget.jobId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              error,
              genericFallback: 'Could not save checklist. Please try again.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Job Checklist',
                        style: AppFonts.titleMedium(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w900, fontSize: 22),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Text(
                  'Complete every required item to start work on this pin.',
                  style: AppFonts.bodyMedium(color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _items.isEmpty
                    ? Center(
                        child: Text(
                          'No checklist items for this job.',
                          style: AppFonts.bodyMedium(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _ChecklistRow(
                            title: item.title,
                            isChecked: item.isChecked,
                            isRequired: item.isRequired,
                            hasPdf: item.hasPdf,
                            requiresConcentricPoint: item.requiresConcentricPoint,
                            concentricPointConfirmed:
                                item.concentricPointConfirmed,
                            onToggle: () => _toggleItem(item.id),
                            onConcentricChanged: item.requiresConcentricPoint
                                ? (confirmed) =>
                                      _setConcentricPoint(item.id, confirmed)
                                : null,
                            onViewPdf: item.hasPdf
                                ? () => openEmployeeChecklistPdf(
                                      context,
                                      title: item.title,
                                      fileUrl: item.fileUrl!,
                                    )
                                : null,
                          );
                        },
                      ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderLight)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _canConfirm ? _confirm : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.inkStrong,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(
                                'Start Job',
                                style: AppFonts.titleSmall(
                                  color: AppColors.white,
                                ).copyWith(fontWeight: FontWeight.w900),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.title,
    required this.isChecked,
    required this.isRequired,
    required this.hasPdf,
    required this.requiresConcentricPoint,
    required this.concentricPointConfirmed,
    required this.onToggle,
    this.onConcentricChanged,
    this.onViewPdf,
  });

  final String title;
  final bool isChecked;
  final bool isRequired;
  final bool hasPdf;
  final bool requiresConcentricPoint;
  final bool? concentricPointConfirmed;
  final VoidCallback onToggle;
  final ValueChanged<bool>? onConcentricChanged;
  final VoidCallback? onViewPdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.bodyLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (isRequired)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Required',
                          style: AppFonts.labelSmall(color: AppColors.muted),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: onToggle,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isChecked
                        ? AppColors.inkStrong
                        : AppColors.transparent,
                    border: Border.all(
                      color: isChecked
                          ? AppColors.inkStrong
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.white,
                        )
                      : null,
                ),
              ),
            ],
          ),
          if (hasPdf && onViewPdf != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onViewPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('View PDF'),
            ),
          ],
          if (requiresConcentricPoint && onConcentricChanged != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Concentric point verified',
                    style: AppFonts.bodySmall(color: AppColors.muted),
                  ),
                ),
                Switch.adaptive(
                  value: concentricPointConfirmed == true,
                  onChanged: onConcentricChanged,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
