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
                entry.pin.isStatusComplete),
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
                'PINS & FORMS',
                style: AppFonts.labelMedium(color: AppColors.muted).copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (_formPinCount > 0)
              Text(
                '$_completedFormCount/$_formPinCount forms',
                style: AppFonts.labelLarge(
                  color: const Color(0xFF5E4BFF),
                ).copyWith(fontWeight: FontWeight.w900),
              ),
          ],
        ),
        const SizedBox(height: 12),
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
            ) || widget.pinEntries[i].pin.isStatusComplete,
            isQrComplete: _isPinQrComplete(widget.pinEntries[i].pin),
            showQrAction: _pinShowsQr(widget.pinEntries[i].pin),
            isJobCompleted: widget.isJobCompleted,
            formsEnabled: widget.formsEnabled,
            onFillForm: widget.pinEntries[i].pin.hasForm
                ? () => widget.onPinFormTap(widget.pinEntries[i].pin)
                : null,
            onScanQr: _pinShowsQr(widget.pinEntries[i].pin)
                ? () => widget.onPinQrTap(widget.pinEntries[i].pin)
                : null,
          ),
        ],
      ],
    );
  }

  bool _pinShowsQr(EmployeeJobDrawingPin pin) {
    final formId = pin.projectFormId;
    if (formId == null || formId <= 0) return false;
    return widget.formHasQrFields[formId] == true;
  }

  bool _isPinQrComplete(EmployeeJobDrawingPin pin) {
    if (!_pinShowsQr(pin)) return false;
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
    required this.isJobCompleted,
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
  final bool isJobCompleted;
  final bool formsEnabled;
  final VoidCallback? onFillForm;
  final VoidCallback? onScanQr;

  @override
  Widget build(BuildContext context) {
    final pin = entry.pin;
    final subtitle = '${entry.levelName} • ${entry.plotName}';
    final trailing = pin.hasForm
        ? (isFormComplete ? 'Form done' : 'Form pending')
        : 'No form';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.inkStrong.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.white,
            child: InkWell(
              onTap: () => onExpandedChanged(!expanded),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: expanded ? Radius.zero : const Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pin.displayLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.titleMedium(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.bodySmall(color: AppColors.muted)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: pin.statusName,
                      background: pin.statusBackground,
                      foreground: pin.statusForeground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      trailing,
                      style: AppFonts.bodySmall(color: AppColors.muted)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pin.itemName.isNotEmpty &&
                      pin.itemName != pin.displayLabel) ...[
                    Text(
                      pin.itemName,
                      style: AppFonts.bodySmall(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (pin.location.isNotEmpty) ...[
                    Text(
                      'Location: ${pin.location}',
                      style: AppFonts.bodySmall(color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (pin.hasForm) ...[
                    _FormActionRow(
                      formName: pin.projectFormName ?? 'Linked form',
                      isComplete: isFormComplete,
                      actionLabel: !formsEnabled
                          ? 'Start job to fill form'
                          : isJobCompleted
                              ? (isFormComplete ? 'Review form' : 'Fill form')
                              : (isFormComplete ? 'Update form' : 'Fill form'),
                      onTap: formsEnabled ? onFillForm : null,
                    ),
                  ] else
                    Text(
                      'No form assigned to this pin.',
                      style: AppFonts.bodySmall(color: AppColors.muted),
                    ),
                  if (showQrAction) ...[
                    const SizedBox(height: 10),
                    _QrActionRow(
                      isComplete: isQrComplete,
                      onTap: formsEnabled ? onScanQr : null,
                      disabledHint: formsEnabled
                          ? null
                          : 'Start the job to scan QR codes',
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

class _FormActionRow extends StatelessWidget {
  const _FormActionRow({
    required this.formName,
    required this.isComplete,
    required this.actionLabel,
    this.onTap,
  });

  final String formName;
  final bool isComplete;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              isComplete
                  ? Icons.check_circle_rounded
                  : Icons.description_outlined,
              size: 18,
              color: isComplete
                  ? const Color(0xFF00A86B)
                  : AppColors.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                formName,
                style: AppFonts.bodySmall(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.inkStrong,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              actionLabel,
              style: AppFonts.labelLarge(color: AppColors.white).copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QrActionRow extends StatelessWidget {
  const _QrActionRow({
    required this.isComplete,
    this.onTap,
    this.disabledHint,
  });

  final bool isComplete;
  final VoidCallback? onTap;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              isComplete
                  ? Icons.qr_code_2_rounded
                  : Icons.qr_code_scanner_rounded,
              size: 18,
              color: isComplete
                  ? const Color(0xFF00A86B)
                  : AppColors.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isComplete ? 'QR code scanned' : 'QR code required in form',
                style: AppFonts.bodySmall(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (disabledHint != null) ...[
          Text(
            disabledHint!,
            style: AppFonts.bodySmall(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text(
              isComplete ? 'Scan again' : 'Scan QR code',
              style: AppFonts.labelLarge(color: AppColors.inkStrong).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              side: const BorderSide(color: AppColors.borderLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: AppFonts.labelSmall(color: foreground).copyWith(
          fontWeight: FontWeight.w900,
          fontSize: 9,
        ),
      ),
    );
  }
}
