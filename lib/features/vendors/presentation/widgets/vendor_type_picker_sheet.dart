import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';
import 'package:red5/features/vendors/data/vendors_api_client.dart';
import 'package:red5/features/vendors/presentation/widgets/add_vendor_type_dialog.dart';

/// Searchable vendor type picker — `GET /vendor-type/?search=&is_active=true`.
Future<VendorTypeOption?> showVendorTypePickerSheet({
  required BuildContext context,
  VendorTypeOption? selected,
}) {
  return showModalBottomSheet<VendorTypeOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _VendorTypePickerSheet(selected: selected),
  );
}

class _VendorTypePickerSheet extends ConsumerStatefulWidget {
  const _VendorTypePickerSheet({this.selected});

  final VendorTypeOption? selected;

  @override
  ConsumerState<_VendorTypePickerSheet> createState() =>
      _VendorTypePickerSheetState();
}

class _VendorTypePickerSheetState extends ConsumerState<_VendorTypePickerSheet> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<VendorTypeOption> _types = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    Future.microtask(() => _loadTypes());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) unawaited(_loadTypes());
    });
  }

  Future<void> _loadTypes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final types = await ref.read(vendorsApiClientProvider).fetchVendorTypes(
            search: _searchController.text,
          );
      if (!mounted) return;
      setState(() {
        _types = types;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load vendor types',
        );
      });
    }
  }

  Future<void> _addVendorType() async {
    final created = await showAddVendorTypeDialog(context: context);
    if (created == null || !mounted) return;
    if (!mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Select vendor type',
              style: AppFonts.titleLarge(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Search active vendor types from the catalog.',
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _searchController,
              hintText: 'Search vendor types...',
              prefixIcon: Icons.search_rounded,
              fillColor: const Color(0xFFF3F4F6),
              borderRadius: 12,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _addVendorType,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add vendor type'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkStrong,
                side: const BorderSide(color: AppColors.borderLight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppFonts.bodyMedium(color: AppColors.error),
                    ),
                    TextButton(onPressed: _loadTypes, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_types.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No vendor types found.',
                  textAlign: TextAlign.center,
                  style: AppFonts.bodyMedium(color: AppColors.muted),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final type = _types[index];
                    final isSelected = widget.selected?.id == type.id;
                    final chipBg = parseHexColor(type.bgColor ?? '');
                    final chipFg = parseHexColor(type.textColor ?? '');
                    return Material(
                      color: AppColors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(type),
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.surfaceHigh
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.inkStrong
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (chipBg != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chipBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    type.name,
                                    style: AppFonts.bodyMedium(
                                      color: chipFg ?? AppColors.inkStrong,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ] else
                                Expanded(
                                  child: Text(
                                    type.name,
                                    style: AppFonts.bodyMedium(
                                      color: AppColors.inkStrong,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              if (chipBg != null) const Spacer(),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.inkStrong,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
