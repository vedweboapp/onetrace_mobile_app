import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_date_picker_dialog.dart';
import 'package:red5/features/dispatch/data/dispatch_models.dart';
import 'package:red5/features/dispatch/presentation/widgets/dispatch_widgets.dart';

class CreateDispatchRouteExtra {
  const CreateDispatchRouteExtra({
    this.materialRequestId,
    this.dispatchTo,
  });

  final String? materialRequestId;
  final String? dispatchTo;
}

class _DispatchItemDraft {
  _DispatchItemDraft({
    required this.itemName,
    required this.qtyController,
  });

  final String itemName;
  final TextEditingController qtyController;

  int get currentStock => DispatchMockData.itemCatalog[itemName] ?? 0;

  void dispose() => qtyController.dispose();
}

/// Create dispatch form (UI preview until API is available).
class CreateDispatchPage extends StatefulWidget {
  const CreateDispatchPage({
    super.key,
    this.initialMaterialRequestId,
    this.initialDispatchTo,
  });

  static const pathPrefix = '/dispatches';
  static const name = 'create-dispatch';
  static String get path => '$pathPrefix/add';

  final String? initialMaterialRequestId;
  final String? initialDispatchTo;

  @override
  State<CreateDispatchPage> createState() => _CreateDispatchPageState();
}

class _CreateDispatchPageState extends State<CreateDispatchPage> {
  static const _divider = Color(0xFFE5E7EB);
  static const _border = Color(0xFFE8E8EA);
  static const _fieldBg = Color(0xFFF9FAFB);
  static const _muted = Color(0xFF6B7280);
  static const _accent = Color(0xFF2563EB);

  static final _dateFormat = DateFormat('MMM d, yyyy');

  late String? _dispatchTo;
  late String? _materialRequestId;
  DateTime? _dispatchDate;

  late final List<_DispatchItemDraft> _items;

  @override
  void initState() {
    super.initState();
    _dispatchTo = widget.initialDispatchTo;
    _materialRequestId = widget.initialMaterialRequestId;
    _dispatchDate = DateTime.now();
    _items = [
      _DispatchItemDraft(
        itemName: DispatchMockData.itemCatalog.keys.first,
        qtyController: TextEditingController(text: '150'),
      ),
      _DispatchItemDraft(
        itemName: DispatchMockData.itemCatalog.keys.elementAt(1),
        qtyController: TextEditingController(text: '24'),
      ),
    ];
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  bool get _canConfirm =>
      _dispatchTo != null &&
      _materialRequestId != null &&
      _dispatchDate != null &&
      _items.isNotEmpty;

  Future<void> _pickDate() async {
    final picked = await showAppDatePickerDialog(
      context,
      initialDate: _dispatchDate ?? DateTime.now(),
    );
    if (picked != null) setState(() => _dispatchDate = picked);
  }

  void _addItem() {
    final names = DispatchMockData.itemCatalog.keys.toList();
    setState(() {
      _items.add(
        _DispatchItemDraft(
          itemName: names[_items.length % names.length],
          qtyController: TextEditingController(text: '1'),
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      _items.removeAt(index).dispose();
    });
  }

  void _onConfirm() {
    context.pop(true);
  }

  List<String> _dropdownOptions(String? value, List<String> baseOptions) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty || baseOptions.contains(trimmed)) {
      return baseOptions;
    }
    return [trimmed, ...baseOptions];
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> options,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: value,
              isExpanded: true,
              hint: Text(
                hint,
                style: AppFonts.bodyMedium(color: const Color(0xFF9CA3AF)),
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dispatch Date',
          style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dispatchDate == null
                        ? 'Select Site/Client'
                        : _dateFormat.format(_dispatchDate!),
                    style: AppFonts.bodyMedium(
                      color: _dispatchDate == null
                          ? const Color(0xFF9CA3AF)
                          : AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 18, color: _muted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemCard(int index, _DispatchItemDraft item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item Name',
                      style: AppFonts.labelMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: item.itemName,
                          isExpanded: true,
                          items: [
                            for (final name in DispatchMockData.itemCatalog.keys)
                              DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              final draft = _DispatchItemDraft(
                                itemName: value,
                                qtyController: item.qtyController,
                              );
                              _items[index] = draft;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeItem(index),
                icon: const Icon(Icons.delete_outline_rounded, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Stock',
                      style: AppFonts.labelMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.currentStock}',
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dispatch Qty',
                      style: AppFonts.labelMedium(color: _muted).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: item.qtyController,
                      keyboardType: TextInputType.number,
                      style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.inkStrong,
        ),
        title: Text(
          'Create Dispatch',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _divider),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DispatchSectionTitle('Basic Info'),
                      _dropdownField(
                        label: 'Dispatch To',
                        value: _dispatchTo,
                        options: _dropdownOptions(
                          _dispatchTo,
                          DispatchMockData.dispatchToOptions,
                        ),
                        hint: 'e.g. Skyline Apartments Phase II',
                        onChanged: (v) => setState(() => _dispatchTo = v),
                      ),
                      const SizedBox(height: 16),
                      _dropdownField(
                        label: 'Material Request Id',
                        value: _materialRequestId,
                        options: _dropdownOptions(
                          _materialRequestId,
                          DispatchMockData.materialRequestOptions,
                        ),
                        hint: 'id',
                        onChanged: (v) =>
                            setState(() => _materialRequestId = v),
                      ),
                      const SizedBox(height: 16),
                      _dateField(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DispatchSectionTitle('Dispatch Items'),
                      for (var i = 0; i < _items.length; i++)
                        _itemCard(i, _items[i]),
                      Text(
                        'Total Items in Dispatch: ${_items.length}',
                        style: AppFonts.bodySmall(color: _muted).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, color: _accent, size: 20),
                        label: Text(
                          'Add Item',
                          style: AppFonts.bodyMedium(color: _accent).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: _divider)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _canConfirm ? _onConfirm : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF121212),
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Confirm Dispatch',
                        style: AppFonts.titleMedium(color: AppColors.white)
                            .copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.inkStrong,
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppFonts.titleMedium(color: AppColors.inkStrong)
                            .copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
