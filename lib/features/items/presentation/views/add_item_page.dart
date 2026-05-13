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

/// Create (`POST /api/v1/item/`) or edit (`PUT /api/v1/item/{id}/`) a catalog item.
///
/// Add route must stay **`/catalog/items/add`** before **`/catalog/items/:itemId`**
/// so `add` is not parsed as an id. Edit uses **`/catalog/items/:itemId/edit`**.
class AddItemPage extends ConsumerStatefulWidget {
  const AddItemPage({super.key, this.editItemId, this.prefill});

  /// When non-null and [prefill] is null, detail is loaded via `GET /item/{id}/`.
  final String? editItemId;

  /// When passed from [ItemDetailPage], avoids a duplicate fetch.
  final ItemDetailModel? prefill;

  static String get path => '${ItemDetailPage.pathPrefix}/add';
  static const name = 'add-item';
  static const editName = 'edit-item';

  static String pathForEdit(String itemId) =>
      '${ItemDetailPage.pathPrefix}/${itemId.trim()}/edit';

  @override
  ConsumerState<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends ConsumerState<AddItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _quantity = TextEditingController();
  final _costPrice = TextEditingController();
  final _sellingPrice = TextEditingController();

  bool _isSubmitting = false;
  late bool _loadingPrefill;

  bool get _isEdit {
    final id = widget.editItemId?.trim() ?? '';
    return id.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final id = widget.editItemId?.trim() ?? '';
    if (widget.prefill != null) {
      _applyDetail(widget.prefill!);
      _loadingPrefill = false;
    } else if (id.isNotEmpty) {
      _loadingPrefill = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    } else {
      _loadingPrefill = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _quantity.dispose();
    _costPrice.dispose();
    _sellingPrice.dispose();
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPrefill = false);
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Failed to load item',
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
        saved = await api.updateItem(
          id: widget.editItemId!.trim(),
          name: name,
          sku: sku,
          quantity: quantity,
          costPrice: cost,
          sellingPrice: sell,
        );
      } else {
        saved = await api.createItem(
          name: name,
          sku: sku,
          quantity: quantity,
          costPrice: cost,
          sellingPrice: sell,
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
              genericFallback:
                  _isEdit ? 'Failed to update item' : 'Failed to create item',
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

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Items' : 'Add Items';
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
                            textInputAction: TextInputAction.done,
                          ),
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
