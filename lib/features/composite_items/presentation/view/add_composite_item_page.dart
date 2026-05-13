import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/features/items/data/item_models.dart';
import 'package:red5/features/items/data/items_api_client.dart';
import 'package:red5/features/items/presentation/views/item_detail_page.dart';

class _ComponentRow {
  _ComponentRow({this.item, String qtyText = ''})
      : qty = TextEditingController(text: qtyText);

  ItemModel? item;
  final TextEditingController qty;

  void dispose() => qty.dispose();
}

/// Create or edit a composite catalog row (`is_composite: true` + `items` lines).
///
/// Routes must be registered **before** `/catalog/items/:itemId` so `add-composite`
/// is not parsed as an item id.
class AddCompositeItemPage extends ConsumerStatefulWidget {
  const AddCompositeItemPage({super.key, this.editItemId, this.prefill});

  final String? editItemId;
  final ItemDetailModel? prefill;

  static String get path => '${ItemDetailPage.pathPrefix}/add-composite';
  static const name = 'add-composite-item';
  static const editName = 'edit-composite-item';

  static String pathForEdit(String itemId) =>
      '${ItemDetailPage.pathPrefix}/${itemId.trim()}/edit-composite';

  @override
  ConsumerState<AddCompositeItemPage> createState() =>
      _AddCompositeItemPageState();
}

class _AddCompositeItemPageState extends ConsumerState<AddCompositeItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _quantity = TextEditingController();
  final _costPrice = TextEditingController();
  final _sellingPrice = TextEditingController();

  final List<_ComponentRow> _rows = <_ComponentRow>[_ComponentRow()];

  List<ItemModel> _catalogItems = const <ItemModel>[];
  bool _loadingCatalog = false;
  bool _isSubmitting = false;
  late bool _loadingPrefill;

  bool get _isEdit {
    final id = widget.editItemId?.trim() ?? '';
    return id.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    if (widget.prefill != null) {
      _applyDetail(widget.prefill!);
      _loadingPrefill = false;
    } else if (_isEdit) {
      _loadingPrefill = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    } else {
      _loadingPrefill = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCatalogItems());
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _quantity.dispose();
    _costPrice.dispose();
    _sellingPrice.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _applyDetail(ItemDetailModel d) {
    _name.text = d.name;
    _sku.text = d.sku;
    _quantity.text = d.quantity == d.quantity.roundToDouble()
        ? d.quantity.toInt().toString()
        : d.quantity.toString();
    _costPrice.text = d.costPrice.toStringAsFixed(2);
    _sellingPrice.text = d.sellPrice.toStringAsFixed(2);

    for (final r in _rows) {
      r.dispose();
    }
    _rows.clear();

    if (d.components.isEmpty) {
      _rows.add(_ComponentRow());
    } else {
      for (final c in d.components) {
        _rows.add(
          _ComponentRow(
            item: ItemModel(
              id: c.itemId,
              name: c.itemName,
              sku: c.sku,
              quantity: 0,
              costPrice: 0,
              sellPrice: 0,
            ),
            qtyText: c.quantity == c.quantity.roundToDouble()
                ? c.quantity.toInt().toString()
                : c.quantity.toString(),
          ),
        );
      }
    }
  }

  Future<void> _loadForEdit() async {
    final id = widget.editItemId?.trim() ?? '';
    if (id.isEmpty) return;
    try {
      final api = ref.read(itemsApiClientProvider);
      final d = await api.fetchItemDetail(id);
      if (!mounted) return;
      _applyDetail(d);
      setState(() => _loadingPrefill = false);
      await _loadCatalogItems();
      _reconcileRowItemsWithCatalog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPrefill = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Failed to load composite item',
            ),
          ),
        ),
      );
    }
  }

  /// After catalog loads, swap stub [ItemModel] rows for full catalog rows when ids match.
  void _reconcileRowItemsWithCatalog() {
    final byId = <String, ItemModel>{
      for (final it in _catalogItems) if (it.id.trim().isNotEmpty) it.id.trim(): it,
    };
    var changed = false;
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final id = row.item?.id.trim() ?? '';
      if (id.isEmpty) continue;
      final match = byId[id];
      if (match != null && match != row.item) {
        _rows[i] = _ComponentRow(item: match, qtyText: row.qty.text);
        row.dispose();
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _loadCatalogItems() async {
    if (_loadingCatalog) return;
    setState(() => _loadingCatalog = true);
    try {
      final api = ref.read(itemsApiClientProvider);
      final all = <ItemModel>[];
      var page = 1;
      const pageSize = 50;
      while (page <= 30) {
        final r = await api.fetchItemsPage(
          page: page,
          pageSize: pageSize,
          isComposite: false,
        );
        all.addAll(r.items);
        if (page >= r.totalPages || r.items.isEmpty) break;
        page++;
      }
      if (!mounted) return;
      final editingId = widget.editItemId?.trim() ?? '';
      setState(() {
        _catalogItems = all
            .where((e) => editingId.isEmpty || e.id.trim() != editingId)
            .toList();
        _loadingCatalog = false;
      });
      _reconcileRowItemsWithCatalog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCatalog = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Failed to load items for components',
            ),
          ),
        ),
      );
    }
  }

  String? Function(String?) _required(String fieldName) {
    return (value) {
      if ((value ?? '').trim().isEmpty) {
        return '$fieldName is required';
      }
      return null;
    };
  }

  String? _optionalNumber(String label, String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return null;
    if (double.tryParse(t.replaceAll(',', '')) == null) {
      return 'Enter a valid $label';
    }
    return null;
  }

  double _parseMoney(String raw) {
    final t = raw.trim().replaceAll(',', '');
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  double _parseQty(String raw) {
    final t = raw.trim().replaceAll(',', '');
    if (t.isEmpty) return 0;
    return double.tryParse(t) ?? 0;
  }

  void _addRow() {
    setState(() => _rows.add(_ComponentRow()));
  }

  void _removeRowAt(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final lines = <({String itemId, double quantity})>[];
    for (final row in _rows) {
      final id = row.item?.id.trim() ?? '';
      if (id.isEmpty) continue;
      final q = _parseQty(row.qty.text);
      if (q <= 0) {
        if (!mounted) return;
        context.showTopSnackBar(
          const SnackBar(
            content: Text('Enter a quantity greater than 0 for each component'),
          ),
        );
        return;
      }
      lines.add((itemId: id, quantity: q));
    }
    if (lines.isEmpty) {
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Add at least one component item with quantity'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(itemsApiClientProvider);
      final name = _name.text.trim();
      final sku = _sku.text.trim();
      final quantity = _parseQty(_quantity.text);
      final cost = _parseMoney(_costPrice.text);
      final sell = _parseMoney(_sellingPrice.text);

      final ItemModel saved;
      if (_isEdit) {
        saved = await api.updateCompositeItem(
          id: widget.editItemId!.trim(),
          name: name,
          sku: sku,
          quantity: quantity,
          costPrice: cost,
          sellingPrice: sell,
          componentLines: lines,
        );
      } else {
        saved = await api.createCompositeItem(
          name: name,
          sku: sku,
          quantity: quantity,
          costPrice: cost,
          sellingPrice: sell,
          componentLines: lines,
        );
      }
      if (!mounted) return;
      context.pop<ItemModel>(saved);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: _isEdit
                  ? 'Failed to update composite item'
                  : 'Failed to create composite item',
            ),
          ),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: AppFonts.labelMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
        ],
      ),
      style: AppFonts.bodySmall(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w700, fontSize: 13),
    );
  }

  /// Catalog rows plus any [row.item] already chosen (e.g. from edit prefill) not in the list.
  List<ItemModel> _mergedDropdownItems() {
    final byId = <String, ItemModel>{};
    for (final e in _catalogItems) {
      final id = e.id.trim();
      if (id.isNotEmpty) byId[id] = e;
    }
    for (final row in _rows) {
      final it = row.item;
      if (it == null) continue;
      final id = it.id.trim();
      if (id.isEmpty) continue;
      byId.putIfAbsent(id, () => it);
    }
    return byId.values.toList();
  }

  ItemModel? _dropdownValueForRow(_ComponentRow row, List<ItemModel> items) {
    final id = row.item?.id.trim() ?? '';
    if (id.isEmpty) return null;
    for (final e in items) {
      if (e.id.trim() == id) return e;
    }
    return null;
  }

  Widget _componentBlock(int index) {
    final row = _rows[index];
    final dropdownItems = _mergedDropdownItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (index > 0) const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _label('Item', required: true)),
            if (_rows.length > 1)
              IconButton(
                onPressed: _isSubmitting ? null : () => _removeRowAt(index),
                icon: const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
                tooltip: 'Remove row',
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingCatalog && dropdownItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (!_loadingCatalog && dropdownItems.isEmpty)
          Text(
            'No standard items available to add as components.',
            style: AppFonts.bodySmall(color: AppColors.muted),
          )
        else
          DropdownButtonFormField<ItemModel>(
          key: ValueKey<String>('${index}_${row.item?.id ?? 'none'}'),
          initialValue: _dropdownValueForRow(row, dropdownItems),
          isExpanded: true,
          hint: Text(
            'item name',
            style: AppFonts.bodyMedium(color: AppColors.textFieldHint),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF111111), width: 1.4),
            ),
          ),
          items: dropdownItems
              .map(
                (e) => DropdownMenuItem<ItemModel>(
                  value: e,
                  child: Text(
                    e.name.isNotEmpty ? e.name : e.sku,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _loadingCatalog || _isSubmitting
              ? null
              : (value) => setState(() => row.item = value),
        ),
        const SizedBox(height: 14),
        _label('Qty'),
        const SizedBox(height: 8),
        AppTextField(
          controller: row.qty,
          hintText: 'eg TH',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => _optionalNumber('quantity', v),
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }

  Widget _addRowButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSubmitting ? null : _addRow,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC9C9CC), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 20, color: AppColors.inkStrong.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Text(
                  '+ Add Row',
                  style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Composite items' : 'Add Composite items';
    final primaryLabel = _isEdit ? 'Save' : 'Create';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _isSubmitting ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          title,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.inkStrong.withValues(alpha: 0.08),
          ),
        ),
      ),
      body: _loadingPrefill
          ? Center(
              child: const AppSkeletonScreenBody(
                scrollable: false,
                toastBlockCount: 5,
              ),
            )
          : SafeArea(
              top: false,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                        children: [
                          _sectionLabel('Basic Info'),
                          _label('Name', required: true),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _name,
                            hintText: 'e.g. Apex Structural Group',
                            validator: _required('Name'),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('SKU', required: true),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _sku,
                            hintText: 'e.g. Apex Structural Group',
                            validator: _required('SKU'),
                            textInputAction: TextInputAction.next,
                          ),
                          _sectionLabel('Price'),
                          _label('Quantity'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _quantity,
                            hintText: 'item name',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) => _optionalNumber('quantity', v),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Cost price'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _costPrice,
                            hintText: 'eg TH',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) => _optionalNumber('cost price', v),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          _label('Selling price'),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _sellingPrice,
                            hintText: 'eg TH',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) =>
                                _optionalNumber('selling price', v),
                            textInputAction: TextInputAction.next,
                          ),
                          _sectionLabel('Components'),
                          for (var i = 0; i < _rows.length; i++) _componentBlock(i),
                          _addRowButton(),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        12 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF111111),
                            foregroundColor: AppColors.white,
                            disabledBackgroundColor: const Color(
                              0xFF111111,
                            ).withValues(alpha: 0.45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.white,
                                  ),
                                )
                              : Text(
                                  primaryLabel,
                                  style:
                                      AppFonts.titleMedium(color: AppColors.white)
                                          .copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
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
