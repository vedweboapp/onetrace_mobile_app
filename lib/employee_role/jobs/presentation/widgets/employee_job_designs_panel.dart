import 'package:flutter/material.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/jobs/data/employee_job_detail.dart';
import 'package:red5/employee_role/jobs/data/employee_job_drawing_models.dart';
import 'package:red5/employee_role/jobs/presentation/widgets/employee_job_drawing_card.dart';
import 'package:red5/features/dashboard/presentation/views/drawing_canvas_page.dart';

typedef EmployeeJobPinFormTap = void Function(EmployeeJobDrawingPin pin);
typedef EmployeeJobPinQrTap = void Function(EmployeeJobDrawingPin pin);

class EmployeeJobDesignsPanel extends StatefulWidget {
  const EmployeeJobDesignsPanel({
    super.key,
    required this.job,
    this.completedPinFormKeys = const {},
    this.onPinFormTap,
    this.scannedPinQrKeys = const {},
    this.formHasQrFields = const {},
    this.onPinQrTap,
    this.showDrawingCards = true,
    this.showSiteSummary = true,
    this.showPinFormActions = false,
    this.isJobCompleted = false,
    this.formsEnabled = true,
  });

  final EmployeeJobDetail job;
  final Set<String> completedPinFormKeys;
  final Set<String> scannedPinQrKeys;
  final Map<int, bool> formHasQrFields;
  final EmployeeJobPinFormTap? onPinFormTap;
  final EmployeeJobPinQrTap? onPinQrTap;
  final bool showDrawingCards;
  final bool showSiteSummary;
  final bool showPinFormActions;
  final bool isJobCompleted;
  final bool formsEnabled;

  @override
  State<EmployeeJobDesignsPanel> createState() =>
      _EmployeeJobDesignsPanelState();
}

class _EmployeeJobDesignsPanelState extends State<EmployeeJobDesignsPanel> {
  final Set<int> _expandedLevels = <int>{};
  final Set<String> _expandedPlots = <String>{};

  @override
  void initState() {
    super.initState();
    final levels = widget.job.levels
        .where((level) => level.drawingFileUrl?.trim().isNotEmpty == true)
        .toList();
    if (levels.length == 1) {
      _expandedLevels.add(levels.first.id);
      if (levels.first.plots.length == 1) {
        _expandedPlots.add(_plotKey(levels.first.id, levels.first.plots.first.id));
      }
    }
  }

  String _plotKey(int levelId, int plotId) => '${levelId}_$plotId';

  Future<void> _openDrawing(EmployeeJobDrawingLevel level) async {
    final url = resolveEmployeeDrawingFileUrl(level.drawingFileUrl);
    if (url == null || url.isEmpty) return;
    await DrawingCanvasPage.push(
      context,
      DrawingCanvasArgs(
        title: level.name,
        remoteDrawingUrl: url,
        levelName: level.name,
        projectName: widget.job.project,
        projectId: widget.job.projectId?.toString(),
        levelId: level.id.toString(),
        embeddedLevelPlots: level.plotPayloads,
        viewOnly: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final designLevels = widget.job.levels
        .where((level) => level.drawingFileUrl?.trim().isNotEmpty == true)
        .toList(growable: false);
    if (designLevels.isEmpty) {
      return _EmptyDesignsState(siteDetail: widget.job.siteDetail);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSiteSummary && widget.job.siteDetail != null) ...[
          _SiteSummaryCard(site: widget.job.siteDetail!),
          const SizedBox(height: 16),
        ] else ...[
          Text(
            'Designs',
            style: AppFonts.titleLarge(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            '${designLevels.length} design${designLevels.length == 1 ? '' : 's'}',
            style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < designLevels.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _DesignLevelSection(
            level: designLevels[i],
            expanded: _expandedLevels.contains(designLevels[i].id),
            onExpandedChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedLevels.add(designLevels[i].id);
                } else {
                  _expandedLevels.remove(designLevels[i].id);
                }
              });
            },
            onOpenDrawing: () => _openDrawing(designLevels[i]),
            plotExpanded: (plotId) =>
                _expandedPlots.contains(_plotKey(designLevels[i].id, plotId)),
            onPlotExpandedChanged: (plotId, expanded) {
              setState(() {
                final key = _plotKey(designLevels[i].id, plotId);
                if (expanded) {
                  _expandedPlots.add(key);
                } else {
                  _expandedPlots.remove(key);
                }
              });
            },
            completedPinFormKeys: widget.completedPinFormKeys,
            scannedPinQrKeys: widget.scannedPinQrKeys,
            formHasQrFields: widget.formHasQrFields,
            showPinFormActions: widget.showPinFormActions,
            isJobCompleted: widget.isJobCompleted,
            formsEnabled: widget.formsEnabled,
            onPinFormTap: widget.onPinFormTap,
            onPinQrTap: widget.onPinQrTap,
            jobId: widget.job.id,
          ),
        ],
      ],
    );
  }

}

class _DesignLevelSection extends StatelessWidget {
  const _DesignLevelSection({
    required this.level,
    required this.expanded,
    required this.onExpandedChanged,
    required this.onOpenDrawing,
    required this.plotExpanded,
    required this.onPlotExpandedChanged,
    required this.completedPinFormKeys,
    required this.scannedPinQrKeys,
    required this.formHasQrFields,
    required this.showPinFormActions,
    required this.isJobCompleted,
    required this.formsEnabled,
    required this.jobId,
    this.onPinFormTap,
    this.onPinQrTap,
  });

  final EmployeeJobDrawingLevel level;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final VoidCallback onOpenDrawing;
  final bool Function(int plotId) plotExpanded;
  final void Function(int plotId, bool expanded) onPlotExpandedChanged;
  final Set<String> completedPinFormKeys;
  final Set<String> scannedPinQrKeys;
  final Map<int, bool> formHasQrFields;
  final bool showPinFormActions;
  final bool isJobCompleted;
  final bool formsEnabled;
  final int jobId;
  final EmployeeJobPinFormTap? onPinFormTap;
  final EmployeeJobPinQrTap? onPinQrTap;

  String get _levelSubtitle {
    final parts = <String>[];
    if (level.order > 0) {
      parts.add('Level ${level.order}');
    }
    final plotCount = level.plots.length;
    if (plotCount > 0) {
      parts.add('$plotCount plot${plotCount == 1 ? '' : 's'}');
    }
    return parts.isEmpty ? level.name : parts.join(' • ');
  }

  String get _updatedLabel {
    final pinCount = level.pinCount;
    if (pinCount > 0) {
      return '$pinCount pin${pinCount == 1 ? '' : 's'} on drawing';
    }
    return 'Drawing available';
  }

  @override
  Widget build(BuildContext context) {
    final hasDrawing = level.drawingFileUrl?.trim().isNotEmpty == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasDrawing)
          EmployeeJobDrawingCard(
            title: level.name,
            subtitle: _levelSubtitle,
            updatedLabel: _updatedLabel,
            drawingFileUrl: resolveEmployeeDrawingFileUrl(level.drawingFileUrl),
            cacheKey: 'job-$jobId-level-${level.id}',
            onTap: onOpenDrawing,
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          level.name,
                          style: AppFonts.titleSmall(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _levelSubtitle,
                          style: AppFonts.bodySmall(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _updatedLabel,
                    style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        _CollapsibleCard(
          title: 'Pins',
          trailing: '${level.pinCount} pin${level.pinCount == 1 ? '' : 's'}',
          expanded: expanded,
          onExpandedChanged: onExpandedChanged,
          nested: true,
          child: level.pinCount == 0
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No pins on this design yet.',
                    style: AppFonts.bodySmall(color: AppColors.muted),
                  ),
                )
              : showPinFormActions
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                      child: Column(
                        children: [
                          for (var i = 0; i < level.plots.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _PlotCard(
                              plot: level.plots[i],
                              expanded: plotExpanded(level.plots[i].id),
                              onExpandedChanged: (value) =>
                                  onPlotExpandedChanged(
                                level.plots[i].id,
                                value,
                              ),
                              completedPinFormKeys: completedPinFormKeys,
                              scannedPinQrKeys: scannedPinQrKeys,
                              formHasQrFields: formHasQrFields,
                              showPinFormActions: showPinFormActions,
                              isJobCompleted: isJobCompleted,
                              formsEnabled: formsEnabled,
                              onPinFormTap: onPinFormTap,
                              onPinQrTap: onPinQrTap,
                            ),
                          ],
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                      child: Column(
                        children: [
                          for (final plot in level.plots)
                            for (final pin in plot.pins) ...[
                              _PinCard(
                                pin: pin,
                                showPinFormActions: false,
                                isFormComplete: false,
                                showQrAction: false,
                                isQrComplete: false,
                                isJobCompleted: isJobCompleted,
                                formsEnabled: formsEnabled,
                              ),
                              const SizedBox(height: 8),
                            ],
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class _EmptyDesignsState extends StatelessWidget {
  const _EmptyDesignsState({this.siteDetail});

  final EmployeeJobSiteDetail? siteDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (siteDetail != null) ...[
          _SiteSummaryCard(site: siteDetail!),
          const SizedBox(height: 16),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Text(
            'No drawings linked to this site job yet.',
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _SiteSummaryCard extends StatelessWidget {
  const _SiteSummaryCard({required this.site});

  final EmployeeJobSiteDetail site;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SITE',
            style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            site.name,
            style: AppFonts.titleSmall(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          if (site.address.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    site.address,
                    style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlotCard extends StatelessWidget {
  const _PlotCard({
    required this.plot,
    required this.expanded,
    required this.onExpandedChanged,
    required this.completedPinFormKeys,
    required this.scannedPinQrKeys,
    required this.formHasQrFields,
    required this.showPinFormActions,
    required this.isJobCompleted,
    required this.formsEnabled,
    this.onPinFormTap,
    this.onPinQrTap,
  });

  final EmployeeJobDrawingPlot plot;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Set<String> completedPinFormKeys;
  final Set<String> scannedPinQrKeys;
  final Map<int, bool> formHasQrFields;
  final bool showPinFormActions;
  final bool isJobCompleted;
  final bool formsEnabled;
  final EmployeeJobPinFormTap? onPinFormTap;
  final EmployeeJobPinQrTap? onPinQrTap;

  @override
  Widget build(BuildContext context) {
    return _CollapsibleCard(
      title: plot.name,
      trailing: '${plot.pins.length} pin${plot.pins.length == 1 ? '' : 's'}',
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      nested: true,
      accentColor: plot.borderColor,
      child: plot.pins.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No pins in this plot.',
                style: AppFonts.bodySmall(color: AppColors.muted),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: Column(
                children: [
                  for (var i = 0; i < plot.pins.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _PinCard(
                      pin: plot.pins[i],
                      showPinFormActions: showPinFormActions,
                      isFormComplete: completedPinFormKeys.contains(
                        plot.pins[i].formKey,
                      ),
                      showQrAction:
                          showPinFormActions &&
                          _pinShowsQr(plot.pins[i]) &&
                          !plot.pins[i].hasForm,
                      isQrComplete: plot.pins[i].hasQrCode ||
                          scannedPinQrKeys.contains(plot.pins[i].formKey),
                      isJobCompleted: isJobCompleted,
                      formsEnabled: formsEnabled,
                      onFillForm: showPinFormActions &&
                              plot.pins[i].hasForm &&
                              onPinFormTap != null
                          ? () => onPinFormTap!(plot.pins[i])
                          : null,
                      onScanQr: showPinFormActions &&
                              _pinShowsQr(plot.pins[i]) &&
                              !plot.pins[i].hasForm &&
                              onPinQrTap != null
                          ? () => onPinQrTap!(plot.pins[i])
                          : null,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

bool _pinShowsQr(EmployeeJobDrawingPin pin) => pin.qrCodeFieldPresent;

class _PinCard extends StatefulWidget {
  const _PinCard({
    required this.pin,
    required this.showPinFormActions,
    required this.isFormComplete,
    required this.showQrAction,
    required this.isQrComplete,
    required this.isJobCompleted,
    required this.formsEnabled,
    this.onFillForm,
    this.onScanQr,
  });

  final EmployeeJobDrawingPin pin;
  final bool showPinFormActions;
  final bool isFormComplete;
  final bool showQrAction;
  final bool isQrComplete;
  final bool isJobCompleted;
  final bool formsEnabled;
  final VoidCallback? onFillForm;
  final VoidCallback? onScanQr;

  @override
  State<_PinCard> createState() => _PinCardState();
}

class _PinCardState extends State<_PinCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final trailing = widget.showPinFormActions
        ? (pin.hasForm
            ? (widget.isFormComplete ? 'Form done' : 'Form pending')
            : 'No form')
        : (pin.location.isNotEmpty ? pin.location : pin.statusName);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.white,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: _expanded ? Radius.zero : const Radius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pin.displayLabel,
                            style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                                .copyWith(fontWeight: FontWeight.w900),
                          ),
                          if (pin.itemName.isNotEmpty &&
                              pin.itemName != pin.displayLabel) ...[
                            const SizedBox(height: 4),
                            Text(
                              pin.itemName,
                              style: AppFonts.bodySmall(color: AppColors.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
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
                    Icon(
                      _expanded
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
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pin.location.isNotEmpty &&
                      !widget.showPinFormActions) ...[
                    Text(
                      'Location: ${pin.location}',
                      style: AppFonts.bodySmall(color: AppColors.muted),
                    ),
                  ],
                  if (widget.showPinFormActions) ...[
                    if (pin.location.isNotEmpty) ...[
                      Text(
                        'Location: ${pin.location}',
                        style: AppFonts.bodySmall(color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (pin.hasForm) ...[
                    Row(
                      children: [
                        Icon(
                          widget.isFormComplete
                              ? Icons.check_circle_rounded
                              : Icons.description_outlined,
                          size: 18,
                          color: widget.isFormComplete
                              ? const Color(0xFF00A86B)
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pin.projectFormName ?? 'Linked form',
                            style: AppFonts.bodySmall(color: AppColors.inkStrong)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (_pinShowsQr(pin)) ...[
                      const SizedBox(height: 6),
                      Text(
                        'QR scanning is available at the bottom of the form.',
                        style: AppFonts.bodySmall(color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: FilledButton(
                        onPressed: widget.formsEnabled ? widget.onFillForm : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.inkStrong,
                          foregroundColor: AppColors.white,
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          disabledForegroundColor: AppColors.muted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          !widget.formsEnabled
                              ? 'Start job to fill form'
                              : widget.isJobCompleted
                                  ? (widget.isFormComplete
                                      ? 'Review form'
                                      : 'Fill form')
                                  : (widget.isFormComplete
                                      ? 'Update form'
                                      : 'Fill form'),
                          style: AppFonts.labelLarge(color: AppColors.white)
                              .copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ] else
                    Text(
                      'No form assigned to this pin.',
                      style: AppFonts.bodySmall(color: AppColors.muted),
                    ),
                  if (widget.showQrAction) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          widget.isQrComplete
                              ? Icons.qr_code_2_rounded
                              : Icons.qr_code_scanner_rounded,
                          size: 18,
                          color: widget.isQrComplete
                              ? const Color(0xFF00A86B)
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.isQrComplete
                                ? 'QR code scanned'
                                : 'QR code required',
                            style: AppFonts.bodySmall(color: AppColors.inkStrong)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (!widget.formsEnabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Start the job to scan QR codes',
                        style: AppFonts.bodySmall(color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: widget.formsEnabled ? widget.onScanQr : null,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: Text(
                          widget.isQrComplete ? 'Scan again' : 'Scan QR code',
                          style: AppFonts.labelLarge(color: AppColors.inkStrong)
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkStrong,
                          disabledForegroundColor: AppColors.muted,
                          side: const BorderSide(color: AppColors.borderLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                  ],
                ],
              ),
            ),
        ],
      ),
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

class _CollapsibleCard extends StatelessWidget {
  const _CollapsibleCard({
    required this.title,
    required this.trailing,
    required this.expanded,
    required this.onExpandedChanged,
    required this.child,
    this.nested = false,
    this.headerAction,
    this.accentColor,
  });

  final String title;
  final String trailing;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Widget child;
  final bool nested;
  final Widget? headerAction;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(nested ? 10 : 12),
        border: Border.all(
          color: nested ? const Color(0xFFE8E8E8) : AppColors.borderLight,
        ),
        boxShadow: nested
            ? null
            : [
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
                top: Radius.circular(nested ? 10 : 12),
                bottom: expanded ? Radius.zero : Radius.circular(nested ? 10 : 12),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: nested ? 10 : 12,
                  vertical: nested ? 10 : 12,
                ),
                child: Row(
                  children: [
                    if (accentColor != null) ...[
                      Container(
                        width: 4,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.titleMedium(color: AppColors.inkStrong)
                            .copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: nested ? 15 : 16,
                        ),
                      ),
                    ),
                    if (headerAction != null) ...[
                      headerAction!,
                      const SizedBox(width: 4),
                    ],
                    Text(
                      trailing,
                      style: AppFonts.bodySmall(color: AppColors.muted)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
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
          if (expanded) child,
        ],
      ),
    );
  }
}
