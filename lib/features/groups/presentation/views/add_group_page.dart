import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/groups/data/group_models.dart';
import 'package:red5/features/groups/data/groups_api_client.dart';

class _CompositeRow {
  _CompositeRow({CompositeItemRef? compositeItem, String abbreviation = ''})
    : compositeItem = compositeItem,
      abbreviationController = TextEditingController(text: abbreviation);

  CompositeItemRef? compositeItem;
  final TextEditingController abbreviationController;

  void dispose() => abbreviationController.dispose();
}

class AddGroupPage extends ConsumerStatefulWidget {
  const AddGroupPage({super.key, this.existing});

  /// When non-null the form opens in edit mode pre-filled with [existing] and
  /// submits a `PATCH /group/{id}/` instead of a `POST /group/`.
  final GroupModel? existing;

  static const path = '/groups/add';
  static const name = 'add-group';

  @override
  ConsumerState<AddGroupPage> createState() => _AddGroupPageState();
}

class _AddGroupPageState extends ConsumerState<AddGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _groupName = TextEditingController();
  final List<_CompositeRow> _rows = <_CompositeRow>[];

  List<CompositeItemRef> _options = const <CompositeItemRef>[];
  bool _isLoadingOptions = true;
  String? _optionsError;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _groupName.text = existing.name;
      for (final item in existing.items) {
        _rows.add(
          _CompositeRow(
            compositeItem: item.compositeItem,
            abbreviation: item.abbreviation,
          ),
        );
      }
    }
    if (_rows.isEmpty) _rows.add(_CompositeRow());
    _loadOptions();
  }

  @override
  void dispose() {
    _groupName.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _optionsError = null;
    });
    try {
      final api = ref.read(groupsApiClientProvider);
      final fetched = await api.fetchCompositeItemOptions();
      if (!mounted) return;
      final merged = _mergePreselected(fetched);
      setState(() {
        _options = merged;
        _isLoadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingOptions = false;
        _options = _mergePreselected(const <CompositeItemRef>[]);
        _optionsError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load composite items',
        );
      });
    }
  }

  /// Ensure any composite items already attached to [widget.existing] appear
  /// in the dropdown even if the server omits them from the options list.
  List<CompositeItemRef> _mergePreselected(List<CompositeItemRef> fetched) {
    final map = <String, CompositeItemRef>{
      for (final option in fetched) option.id: option,
    };
    for (final row in _rows) {
      final selected = row.compositeItem;
      if (selected != null) map.putIfAbsent(selected.id, () => selected);
    }
    return map.values.toList();
  }

  void _addRow() {
    setState(() => _rows.add(_CompositeRow()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      final row = _rows.removeAt(index);
      row.dispose();
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final missingComposite = _rows.any((row) => row.compositeItem == null);
    if (missingComposite) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Select a composite item for every row')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(groupsApiClientProvider);
      final drafts = _rows
          .map(
            (row) => GroupItemDraft(
              compositeItemId: row.compositeItem!.id,
              abbreviation: row.abbreviationController.text.trim(),
            ),
          )
          .toList();
      final existing = widget.existing;
      final saved = existing == null
          ? await api.createGroup(name: _groupName.text.trim(), items: drafts)
          : await api.updateGroup(
              id: existing.id,
              name: _groupName.text.trim(),
              items: drafts,
            );
      if (!mounted) return;
      context.pop<GroupModel>(saved);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: _isEditing
                  ? 'Failed to update group'
                  : 'Failed to create group',
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

  InputDecoration _dropdownDecoration({String? hintText}) {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.white,
      hintText: hintText,
      hintStyle: AppFonts.bodyMedium(
        color: const Color(0xFFB0B0B3),
      ).copyWith(fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFB0B0B3)),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE53935)),
      ),
    );
  }

  Widget _compositeRow(int index) {
    final row = _rows[index];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _label('Composite item', required: true)),
              if (_rows.length > 1)
                InkWell(
                  onTap: _isSubmitting ? null : () => _removeRow(index),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<CompositeItemRef>(
            isExpanded: true,
            initialValue: row.compositeItem,
            items: _options
                .map(
                  (option) => DropdownMenuItem<CompositeItemRef>(
                    value: option,
                    child: Text(
                      option.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.bodyMedium(color: AppColors.inkStrong),
                    ),
                  ),
                )
                .toList(),
            onChanged: _isSubmitting || _isLoadingOptions
                ? null
                : (value) => setState(() => row.compositeItem = value),
            validator: (value) =>
                value == null ? 'Composite item is required' : null,
            decoration: _dropdownDecoration(hintText: 'item name'),
            icon: _isLoadingOptions
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF8A8A8A),
                  ),
          ),
          const SizedBox(height: 14),
          _label('Abbreviation'),
          const SizedBox(height: 8),
          AppTextField(
            controller: row.abbreviationController,
            hintText: 'eg TH',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          _isEditing ? 'Edit Group' : 'Add Group',
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
      body: SafeArea(
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
                    _label('Group name', required: true),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _groupName,
                      hintText: 'e.g. Apex Structural Group',
                      validator: (value) =>
                          (value ?? '').trim().isEmpty
                          ? 'Group name is required'
                          : null,
                    ),
                    _sectionLabel('Composite Items'),
                    if (_optionsError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _optionsError!,
                                style: AppFonts.bodySmall(
                                  color: const Color(0xFFE53935),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadOptions,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    for (var i = 0; i < _rows.length; i++) _compositeRow(i),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : _addRow,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.inkStrong,
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        '+ Add Row',
                        style: AppFonts.titleMedium(color: AppColors.inkStrong)
                            .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
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
                            _isEditing ? 'Save' : 'Create',
                            style: AppFonts.titleMedium(color: AppColors.white)
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
