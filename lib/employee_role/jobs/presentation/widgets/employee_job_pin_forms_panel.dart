import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';

typedef EmployeeJobPinFormTap = void Function(EmployeeJobDrawingPin pin);
typedef EmployeeJobPinQrTap = void Function(EmployeeJobDrawingPin pin);

class EmployeeJobPinFormsPanel extends StatefulWidget {
  const EmployeeJobPinFormsPanel({
    super.key,
    required this.pinEntries,
    required this.completedPinFormKeys,
    required this.scannedPinQrKeys,
    required this.formHasQrFields,
    required this.onPinFormTap,
    required this.onPinQrTap,
    this.isJobCompleted = false,
    this.formsEnabled = true,
  });

  final List<EmployeeJobPinListEntry> pinEntries;
  final Set<String> completedPinFormKeys;
  final Set<String> scannedPinQrKeys;
  final Map<int, bool> formHasQrFields;
  final EmployeeJobPinFormTap onPinFormTap;
  final EmployeeJobPinQrTap onPinQrTap;
  final bool isJobCompleted;
  final bool formsEnabled;

  @override
  State<EmployeeJobPinFormsPanel> createState() =>
      _EmployeeJobPinFormsPanelState();
}

class _EmployeeJobPinFormsPanelState extends State<EmployeeJobPinFormsPanel> {
  final Set<int> _expandedPinIds = <int>{};

  @override
  void initState() {
    super.initState();
    if (widget.pinEntries.length == 1) {
      _expandedPinIds.add(widget.pinEntries.first.pin.id);
    }
  }

  int get _formPinCount =>
      widget.pinEntries.where((entry) => entry.pin.hasForm).length;

  int get _completedFormCount => widget.pinEntries
      .where(
        (entry) =>
            entry.pin.hasForm &&
            (widget.completedPinFormKeys.contains(entry.pin.formKey) ||
                entry.pin.isStatusComplete ||
                entry.pin.isFormSubmitted),
      )
      .length;

  @override
  Widget build(BuildContext context) {
    if (widget.pinEntries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          'No pins assigned to this job yet.',
          style: AppFonts.bodyMedium(color: AppColors.muted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Required Form',
                style: AppFonts.titleLarge(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
            if (_formPinCount > 0)
              Text(
                '$_completedFormCount/$_formPinCount Complete',
                style: AppFonts.labelLarge(
                  color: const Color(0xFF5E4BFF),
                ).copyWith(fontWeight: FontWeight.w900),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < widget.pinEntries.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _PinFormsCollapsibleCard(
            entry: widget.pinEntries[i],
            expanded: _expandedPinIds.contains(widget.pinEntries[i].pin.id),
            onExpandedChanged: (expanded) {
              setState(() {
                final pinId = widget.pinEntries[i].pin.id;
                if (expanded) {
                  _expandedPinIds.add(pinId);
                } else {
                  _expandedPinIds.remove(pinId);
                }
              });
            },
            isFormComplete: widget.completedPinFormKeys.contains(
                  widget.pinEntries[i].pin.formKey,
                ) ||
                widget.pinEntries[i].pin.isStatusComplete ||
                widget.pinEntries[i].pin.isFormSubmitted,
            isQrComplete: _isPinQrComplete(widget.pinEntries[i].pin),
            showQrAction: _pinShowsQr(widget.pinEntries[i].pin) &&
                !widget.pinEntries[i].pin.hasForm,
            formsEnabled: widget.formsEnabled,
            onFillForm: widget.pinEntries[i].pin.hasForm
                ? () => widget.onPinFormTap(widget.pinEntries[i].pin)
                : null,
            onScanQr: _pinShowsQr(widget.pinEntries[i].pin) &&
                    !widget.pinEntries[i].pin.hasForm
                ? () => widget.onPinQrTap(widget.pinEntries[i].pin)
                : null,
          ),
        ],
      ],
    );
  }

  bool _pinShowsQr(EmployeeJobDrawingPin pin) => pin.qrCodeFieldPresent;

  bool _isPinQrComplete(EmployeeJobDrawingPin pin) {
    if (pin.hasQrCode) return true;
    return widget.scannedPinQrKeys.contains(pin.formKey);
  }
}

class _PinFormsCollapsibleCard extends StatelessWidget {
  const _PinFormsCollapsibleCard({
    required this.entry,
    required this.expanded,
    required this.onExpandedChanged,
    required this.isFormComplete,
    required this.isQrComplete,
    required this.showQrAction,
    required this.formsEnabled,
    this.onFillForm,
    this.onScanQr,
  });

  final EmployeeJobPinListEntry entry;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final bool isFormComplete;
  final bool isQrComplete;
  final bool showQrAction;
  final bool formsEnabled;
  final VoidCallback? onFillForm;
  final VoidCallback? onScanQr;

  @override
  Widget build(BuildContext context) {
    final pin = entry.pin;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.white,
            child: InkWell(
              onTap: () => onExpandedChanged(!expanded),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(14),
                bottom: expanded ? Radius.zero : const Radius.circular(14),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pin.displayLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.bodyMedium(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w600, height: 1.3),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.muted,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pin.hasForm)
                    _PinFormActionCard(
                      title: isFormComplete ? 'Update Form' : 'Fill Required Form',
                      subtitle: pin.qrCodeFieldPresent
                          ? '${pin.projectFormName ?? 'Linked form'} · QR at bottom of form'
                          : (pin.projectFormName ?? 'Linked form'),
                      isComplete: isFormComplete,
                      enabled: formsEnabled,
                      disabledHint: formsEnabled
                          ? null
                          : 'Start the job to fill forms',
                      onTap: onFillForm,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Text(
                        'No form assigned to this pin.',
                        style: AppFonts.bodySmall(color: AppColors.muted),
                      ),
                    ),
                  if (showQrAction) ...[
                    const SizedBox(height: 8),
                    _PinFormActionCard(
                      title: 'Scan QR',
                      subtitle: pin.hasQrCode
                          ? 'QR ${pin.qrCode}'
                          : 'Scan a QR code to assign to this pin',
                      isComplete: isQrComplete,
                      enabled: formsEnabled,
                      disabledHint: formsEnabled
                          ? null
                          : 'Start the job to scan QR codes',
                      onTap: onScanQr,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PinFormActionCard extends StatelessWidget {
  const _PinFormActionCard({
    required this.title,
    required this.subtitle,
    required this.isComplete,
    required this.enabled,
    this.disabledHint,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isComplete;
  final bool enabled;
  final String? disabledHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onTap != null;

    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: canTap ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700, height: 1.25),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.bodySmall(color: AppColors.muted),
                      ),
                    ],
                    if (disabledHint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        disabledHint!,
                        style: AppFonts.bodySmall(color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isComplete ? AppColors.inkStrong : AppColors.transparent,
                  border: Border.all(
                    color: isComplete ? AppColors.inkStrong : AppColors.border,
                    width: 1.8,
                  ),
                ),
                child: isComplete
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
