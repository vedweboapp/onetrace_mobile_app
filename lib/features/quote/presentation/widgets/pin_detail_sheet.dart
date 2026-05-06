import 'dart:async';

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
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return _PinDetailBody(
            scrollController: scrollController,
            pinIndex: pinIndex,
            pin: pin,
            onRemoved: onRemoved,
            onPinChanged: onPinChanged,
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
  });

  final ScrollController scrollController;
  final int pinIndex;
  final PinEntry pin;
  final VoidCallback onRemoved;
  final ValueChanged<PinEntry> onPinChanged;

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

  static const List<String> _statuses = [
    'To Do',
    'Installed',
    'In Progress',
    'Action Required',
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
      _isEditing = false;
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
      _ => const Color(0xFFE0F2FE),
    };
  }

  Color _statusFg(String status) {
    return switch (status) {
      'Installed' => const Color(0xFF137333),
      'In Progress' => const Color(0xFFB54708),
      'Action Required' => const Color(0xFFB42318),
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

  String _fmtDropped() {
    final d = widget.pin.droppedAt;
    if (d == null) return '—';
    final day = d.day.toString().padLeft(2, '0');
    final mon = d.month.toString().padLeft(2, '0');
    final y = d.year;
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$day/$mon/$y, $h:$min:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pin;
    final title = 'Location ${widget.pinIndex + 1}';

    Widget row(IconData icon, String label, Widget value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: AppFonts.bodySmall(color: AppColors.muted).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Align(alignment: Alignment.centerRight, child: value),
            ),
          ],
        ),
      );
    }

    final statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusBg(_status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(_status),
            size: 15,
            color: _statusFg(_status),
          ),
          const SizedBox(width: 6),
          Text(
            _status,
            style: AppFonts.labelMedium(color: _statusFg(_status)).copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chevron_left, size: 28),
                color: AppColors.ink,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppFonts.titleMedium(color: AppColors.ink).copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (_isEditing) ...[
                TextButton(
                  onPressed: _resetFormFromPin,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFB70011),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveChanges,
                  child: const Text('Save'),
                ),
              ] else
                TextButton(
                  onPressed: () => setState(() => _isEditing = true),
                  child: const Text('Edit'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              row(
                Icons.inventory_2_outlined,
                'Product Name',
                _isEditing
                    ? SizedBox(
                        width: 185,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _product,
                            hint: const Text('Select product'),
                            isDense: true,
                            isExpanded: true,
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
                    : Text(
                        (p.productName?.trim().isNotEmpty ?? false)
                            ? p.productName!.trim()
                            : '—',
                        textAlign: TextAlign.right,
                        style:
                            AppFonts.bodySmall(color: AppColors.ink).copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
              ),
              row(
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
                    : Text(
                        '${p.quantity}',
                        style:
                            AppFonts.bodySmall(color: AppColors.ink).copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
              ),
              row(
                Icons.timelapse,
                'Status',
                _isEditing
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: InkWell(
                            onTap: () => unawaited(_pickStatus()),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _statusBg(_status),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _statusBorder(_status)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _statusIcon(_status),
                                    size: 18,
                                    color: _statusFg(_status),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _status,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.bodySmall(
                                            color: _statusFg(_status),
                                          ).copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.expand_more,
                                    size: 20,
                                    color: _statusFg(_status),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : statusChip,
              ),
              row(
                Icons.layers_outlined,
                'Block',
                Text(
                  (p.blockName?.trim().isNotEmpty ?? false)
                      ? p.blockName!.trim()
                      : '—',
                  textAlign: TextAlign.right,
                  style: AppFonts.bodySmall(color: AppColors.ink).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              row(
                Icons.layers_outlined,
                'Level',
                Text(
                  (p.levelName?.trim().isNotEmpty ?? false)
                      ? p.levelName!.trim()
                      : '—',
                  textAlign: TextAlign.right,
                  style: AppFonts.bodySmall(color: AppColors.ink).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              row(
                Icons.grid_on_outlined,
                'Zone',
                Text(
                  (p.zoneLabel?.trim().isNotEmpty ?? false)
                      ? p.zoneLabel!.trim()
                      : '—',
                  textAlign: TextAlign.right,
                  style: AppFonts.bodySmall(color: AppColors.ink).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              row(
                Icons.adjust,
                'Variation',
                _isEditing
                    ? SizedBox(
                        width: 185,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _variation,
                            isExpanded: true,
                            isDense: true,
                            items: _variations
                                .map(
                                  (v) => DropdownMenuItem<String>(
                                    value: v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _variation = v);
                            },
                          ),
                        ),
                      )
                    : Text(
                        p.variation,
                        style:
                            AppFonts.bodySmall(color: AppColors.ink).copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
              ),
              row(
                Icons.schedule_outlined,
                'Dropped',
                Text(
                  _fmtDropped(),
                  textAlign: TextAlign.right,
                  style: AppFonts.bodySmall(color: AppColors.ink).copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'DESCRIPTION',
                style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _desc,
                maxLines: 4,
                readOnly: !_isEditing,
                hintText: 'Add notes or detailed description here...',
                borderRadius: 12,
                hintStyle:
                    AppFonts.bodyMedium(color: AppColors.textFieldHint).copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRemoved();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB70011),
                    side: const BorderSide(color: Color(0x33B70011)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Remove This Pin',
                    style: AppFonts.labelLarge(color: AppColors.brandPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
