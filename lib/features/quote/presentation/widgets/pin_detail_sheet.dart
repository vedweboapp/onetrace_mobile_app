import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/quote/data/quote_selection_options.dart';
import 'package:red5/features/quote/presentation/widgets/pdf_markup_geometry.dart';

/// Full-screen style sheet for viewing / removing a single pin.
Future<void> showPinDetailSheet({
  required BuildContext context,
  required int pinIndex,
  required PinEntry pin,
  required VoidCallback onRemoved,
  required ValueChanged<PinEntry> onPinChanged,
  String? levelId,
  String? formName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Theme(
            data: Theme.of(ctx).copyWith(
              brightness: Brightness.light,
              canvasColor: AppColors.white,
              scaffoldBackgroundColor: AppColors.white,
            ),
            child: Material(
              color: AppColors.white,
              surfaceTintColor: Colors.transparent,
              child: _PinDetailBody(
                scrollController: scrollController,
                pinIndex: pinIndex,
                pin: pin,
                onRemoved: onRemoved,
                onPinChanged: onPinChanged,
                levelId: levelId,
                formName: formName,
              ),
            ),
          );
        },
      );
    },
  );
}

class _PinDetailBody extends StatefulWidget {
  const _PinDetailBody({
    required this.scrollController,
    required this.pinIndex,
    required this.pin,
    required this.onRemoved,
    required this.onPinChanged,
    this.levelId,
    this.formName,
  });

  final ScrollController scrollController;
  final int pinIndex;
  final PinEntry pin;
  final VoidCallback onRemoved;
  final ValueChanged<PinEntry> onPinChanged;
  final String? levelId;
  final String? formName;

  @override
  State<_PinDetailBody> createState() => _PinDetailBodyState();
}

class _PinDetailBodyState extends State<_PinDetailBody> {
  late final TextEditingController _desc = TextEditingController(
    text: widget.pin.description,
  );
  late final TextEditingController _qty = TextEditingController(
    text: '${widget.pin.quantity}',
  );
  String? _product;
  late String _status;
  late String _variation;
  bool _isEditing = false;
  late List<String> _attachmentNames;

  static const List<String> _statuses = [
    'To Do',
    'Installed',
    'In Progress',
    'Action Required',
    'Declined',
  ];
  static const List<String> _variations = ['No', 'Yes'];

  @override
  void initState() {
    super.initState();
    _product = (widget.pin.productName ?? '').trim().isEmpty
        ? null
        : widget.pin.productName!.trim();
    _status = _statuses.contains(widget.pin.status)
        ? widget.pin.status
        : 'To Do';
    _variation = _variations.contains(widget.pin.variation)
        ? widget.pin.variation
        : 'No';
    _attachmentNames = List<String>.from(widget.pin.attachmentNames);
  }

  @override
  void dispose() {
    _desc.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _resetFormFromPin() {
    setState(() {
      _product = (widget.pin.productName ?? '').trim().isEmpty
          ? null
          : widget.pin.productName!.trim();
      _qty.text = '${widget.pin.quantity}';
      _status = _statuses.contains(widget.pin.status)
          ? widget.pin.status
          : 'To Do';
      _variation = _variations.contains(widget.pin.variation)
          ? widget.pin.variation
          : 'No';
      _desc.text = widget.pin.description;
      _attachmentNames = List<String>.from(widget.pin.attachmentNames);
      _isEditing = false;
    });
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'webp',
        'doc',
        'docx',
      ],
    );
    if (!mounted || result == null) return;
    setState(() {
      for (final file in result.files) {
        final name = file.name.trim();
        if (name.isEmpty) continue;
        if (!_attachmentNames.contains(name)) {
          _attachmentNames.add(name);
        }
      }
    });
  }

  void _saveChanges() {
    final qty = int.tryParse(_qty.text.trim()) ?? widget.pin.quantity;
    final next = widget.pin.copyWith(
      productName: _product?.trim(),
      quantity: qty < 1 ? 1 : qty,
      status: _status,
      variation: _variation,
      description: _desc.text.trim(),
      attachmentNames: List<String>.from(_attachmentNames),
    );
    widget.onPinChanged(next);
    setState(() {
      _isEditing = false;
    });
  }

  Color _statusBg(String status) {
    return switch (status) {
      'Installed' => const Color(0xFFE9F9EE),
      'In Progress' => const Color(0xFFFEF3E8),
      'Action Required' => const Color(0xFFFDECEC),
      'Declined' => const Color(0xFFF3E8FF),
      _ => const Color(0xFFE0F2FE),
    };
  }

  Color _statusFg(String status) {
    return switch (status) {
      'Installed' => const Color(0xFF137333),
      'In Progress' => const Color(0xFFB54708),
      'Action Required' => const Color(0xFFB42318),
      'Declined' => const Color(0xFF6B21A8),
      _ => const Color(0xFF0B6E99),
    };
  }

  Color _statusBorder(String status) {
    return _statusFg(status).withValues(alpha: 0.35);
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'Installed' => Icons.check_circle_outline,
      'In Progress' => Icons.timelapse,
      'Action Required' => Icons.error_outline,
      'Declined' => Icons.cancel_outlined,
      _ => Icons.pending_actions_outlined,
    };
  }

  Future<void> _pickStatus() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFFF9FAFB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Status',
                  style: AppFonts.titleMedium(color: AppColors.ink).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                ..._statuses.map((s) {
                  final selected = s == _status;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx, s),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBg(s),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _statusBorder(s)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 22,
                                color: selected
                                    ? _statusFg(s)
                                    : const Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                _statusIcon(s),
                                size: 20,
                                color: _statusFg(s),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  s,
                                  style:
                                      AppFonts.bodyMedium(color: _statusFg(s))
                                          .copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (selected)
                                Icon(Icons.check, color: _statusFg(s), size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null && mounted) {
      setState(() => _status = chosen);
    }
  }

  String _displayOrDash(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _levelDisplayLabel() {
    final id = (widget.levelId ?? '').trim();
    final fromPin = (widget.pin.levelName ?? '').trim();
    if (id.isNotEmpty) return '$id (${widget.pin.page ?? 1})';
    if (fromPin.isNotEmpty) return fromPin;
    return '—';
  }

  String _coordPercent(double norm) => '${(norm * 100).toStringAsFixed(2)}%';

  static const _sheetBg = AppColors.white;
  static const _sheetCard = AppColors.surfaceHigh;
  static const _sheetMuted = AppColors.muted;
  static const _sheetDivider = AppColors.borderLight;
  static const _sheetInk = AppColors.inkStrong;

  Widget _attachmentsTrailing({required bool editing}) {
    if (_attachmentNames.isEmpty && !editing) {
      return Text(
        '—',
        textAlign: TextAlign.right,
        style: AppFonts.bodySmall(color: _sheetInk).copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_attachmentNames.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              for (var i = 0; i < _attachmentNames.length; i++)
                InputChip(
                  label: Text(
                    _attachmentNames[i],
                    style: AppFonts.labelSmall(color: AppColors.inkStrong)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  deleteIcon: editing
                      ? const Icon(Icons.close_rounded, size: 16)
                      : null,
                  onDeleted: editing
                      ? () => setState(() => _attachmentNames.removeAt(i))
                      : null,
                  backgroundColor: _sheetCard,
                  side: const BorderSide(color: _sheetDivider),
                ),
            ],
          ),
        if (editing) ...[
          if (_attachmentNames.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickAttachments,
            icon: const Icon(Icons.attach_file_rounded, size: 18),
            label: const Text('Add file'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.inkStrong,
              side: const BorderSide(color: Color(0xFFD9D9DC)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pin;

    Widget detailRow(IconData icon, String label, Widget trailing) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: _sheetMuted),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppFonts.bodySmall(color: _sheetMuted).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(child: trailing),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _sheetDivider),
        ],
      );
    }

    Widget textValue(String? value) {
      return Text(
        _displayOrDash(value),
        textAlign: TextAlign.right,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppFonts.bodySmall(color: _sheetInk).copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final statusChip = Container(
      constraints: const BoxConstraints(maxWidth: 168),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBg(_status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(_status), size: 14, color: _statusFg(_status)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppFonts.labelMedium(color: _statusFg(_status)).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    final subtitle = (p.productName ?? '').trim().isNotEmpty
        ? p.productName!.trim()
        : 'Pin ${widget.pinIndex + 1}';

    return Material(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location #${widget.pinIndex + 1}',
                          style: AppFonts.titleMedium(color: _sheetInk).copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.bodyMedium(color: _sheetMuted).copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _resetFormFromPin,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: _sheetMuted),
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFB70011),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saveChanges,
                        child: const Text('Save'),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkStrong,
                          side: const BorderSide(color: Color(0xFFD9D9DC)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 22),
                        color: _sheetMuted,
                        splashRadius: 22,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                detailRow(
                  Icons.folder_outlined,
                  'Group',
                  textValue(p.groupName),
                ),
                detailRow(
                  Icons.inventory_2_outlined,
                  'Product Name',
                  _isEditing
                      ? SizedBox(
                          width: 185,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _product,
                              hint: Text(
                                'Select product',
                                style: TextStyle(color: _sheetMuted),
                              ),
                              dropdownColor: AppColors.white,
                              isDense: true,
                              isExpanded: true,
                              style: TextStyle(color: AppColors.inkStrong),
                              selectedItemBuilder: (context) {
                                return QuoteSelectionOptions.products
                                    .map(
                                      (o) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          o,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList();
                              },
                              items: QuoteSelectionOptions.products
                                  .map(
                                    (o) => DropdownMenuItem<String>(
                                      value: o,
                                      child: Text(
                                        o,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _product = v),
                            ),
                          ),
                        )
                      : textValue(p.productName),
                ),
                detailRow(
                  Icons.add_box_outlined,
                  'Quantity',
                  _isEditing
                      ? SizedBox(
                          width: 84,
                          child: AppTextField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            dense: true,
                            hintText: '',
                          ),
                        )
                      : textValue('${p.quantity}'),
                ),
                detailRow(
                  Icons.timelapse,
                  'Status',
                  _isEditing
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => unawaited(_pickStatus()),
                            borderRadius: BorderRadius.circular(10),
                            child: statusChip,
                          ),
                        )
                      : Align(
                          alignment: Alignment.centerRight,
                          child: statusChip,
                        ),
                ),
                detailRow(
                  Icons.location_on_outlined,
                  'Location',
                  textValue('${widget.pinIndex + 1}'),
                ),
                detailRow(
                  Icons.layers_outlined,
                  'Plot',
                  textValue(p.zoneLabel),
                ),
                detailRow(
                  Icons.grid_on_outlined,
                  'Level',
                  textValue(_levelDisplayLabel()),
                ),
                detailRow(
                  Icons.description_outlined,
                  'Description',
                  _isEditing
                      ? SizedBox(
                          width: 200,
                          child: AppTextField(
                            controller: _desc,
                            maxLines: 2,
                            dense: true,
                            hintText: 'Add notes...',
                          ),
                        )
                      : textValue(p.description),
                ),
                detailRow(
                  Icons.attach_file_rounded,
                  'Attachments',
                  _attachmentsTrailing(editing: _isEditing),
                ),
                detailRow(
                  Icons.apps_rounded,
                  'Form',
                  textValue(widget.formName),
                ),
                detailRow(
                  Icons.layers_outlined,
                  'Variation',
                  Align(
                    alignment: Alignment.centerRight,
                    child: CupertinoSwitch(
                      value: _variation == 'Yes',
                      onChanged: _isEditing
                          ? (v) => setState(() => _variation = v ? 'Yes' : 'No')
                          : null,
                      activeTrackColor: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'LOCATION',
                  style: AppFonts.labelSmall(color: _sheetMuted).copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _sheetCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _sheetDivider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'X COORDINATE',
                              style: AppFonts.labelSmall(color: _sheetMuted)
                                  .copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _coordPercent(p.nx),
                              style: AppFonts.titleSmall(color: _sheetInk)
                                  .copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Y COORDINATE',
                              style: AppFonts.labelSmall(color: _sheetMuted)
                                  .copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _coordPercent(p.ny),
                              style: AppFonts.titleSmall(color: _sheetInk)
                                  .copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onRemoved();
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                    ),
                    label: Text(
                      'Delete Pin',
                      style: AppFonts.titleMedium(
                        color: const Color(0xFFEF4444),
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      backgroundColor: AppColors.white,
                      side: const BorderSide(color: Color(0x33EF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
