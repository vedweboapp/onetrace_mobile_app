import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';
import 'package:red5/features/vendors/data/vendors_api_client.dart';

/// Searchable vendor picker — `GET /vendors/?search=&is_active=true`.
Future<VendorModel?> showVendorPickerSheet({
  required BuildContext context,
  VendorModel? selected,
}) {
  return showModalBottomSheet<VendorModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => _VendorPickerSheet(selected: selected),
  );
}

class _VendorPickerSheet extends ConsumerStatefulWidget {
  const _VendorPickerSheet({this.selected});

  final VendorModel? selected;

  @override
  ConsumerState<_VendorPickerSheet> createState() => _VendorPickerSheetState();
}

class _VendorPickerSheetState extends ConsumerState<_VendorPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<VendorModel> _vendors = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    Future.microtask(() => _loadVendors());
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
      if (mounted) unawaited(_loadVendors());
    });
  }

  Future<void> _loadVendors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await ref.read(vendorsApiClientProvider).fetchVendorsPage(
            page: 1,
            pageSize: 100,
            search: _searchController.text.trim(),
            isActive: true,
          );
      if (!mounted) return;
      final seen = <String>{};
      final vendors = <VendorModel>[];
      for (final vendor in result.items) {
        if (seen.add(vendor.id)) vendors.add(vendor);
      }
      setState(() {
        _vendors = vendors;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load vendors',
        );
      });
    }
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
              'Select vendor',
              style: AppFonts.titleLarge(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Search active vendors from the catalog.',
              style: AppFonts.bodyMedium(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _searchController,
              hintText: 'Search vendors...',
              prefixIcon: Icons.search_rounded,
              fillColor: const Color(0xFFF3F4F6),
              borderRadius: 12,
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
                    TextButton(onPressed: _loadVendors, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_vendors.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No vendors found.',
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
                  itemCount: _vendors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final vendor = _vendors[index];
                    final isSelected = widget.selected?.id == vendor.id;
                    final subtitle = vendor.email?.trim().isNotEmpty == true
                        ? vendor.email!.trim()
                        : vendor.displayPhone;
                    return Material(
                      color: AppColors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(vendor),
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vendor.name.trim().isEmpty
                                          ? 'Vendor'
                                          : vendor.name,
                                      style: AppFonts.bodyMedium(
                                        color: AppColors.inkStrong,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    if (subtitle != '—') ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: AppFonts.bodySmall(
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
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
