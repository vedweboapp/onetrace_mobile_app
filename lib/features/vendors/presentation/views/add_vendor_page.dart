import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/places/place_address.dart';
import 'package:red5/core/widgets/app_address_fields.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';
import 'package:red5/features/vendors/data/vendors_api_client.dart';
import 'package:red5/features/vendors/presentation/widgets/vendor_type_picker_sheet.dart';

class _VendorAddressDraft {
  _VendorAddressDraft({this.isPrimary = false});

  final address1 = TextEditingController();
  final address2 = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  final pincode = TextEditingController();
  String country = 'India';
  bool isPrimary;

  void dispose() {
    for (final c in [address1, address2, city, state, pincode]) {
      c.dispose();
    }
  }

  VendorAddressModel? toModel() {
    if (address1.text.trim().isEmpty &&
        city.text.trim().isEmpty &&
        state.text.trim().isEmpty &&
        pincode.text.trim().isEmpty) {
      return null;
    }
    return VendorAddressModel(
      addressLine1: address1.text,
      addressLine2: address2.text,
      city: city.text,
      state: state.text,
      country: country,
      pincode: pincode.text,
      isPrimary: isPrimary,
    );
  }
}

class AddVendorPage extends ConsumerStatefulWidget {
  const AddVendorPage({super.key});

  static const path = '/vendors/add';
  static const name = 'add-vendor';

  @override
  ConsumerState<AddVendorPage> createState() => _AddVendorPageState();
}

class _AddVendorPageState extends ConsumerState<AddVendorPage> {
  static const _pageBg = Color(0xFFF7F7F8);
  static const _cardBg = AppColors.white;
  static const _labelGrey = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final _vendorName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  final List<_VendorAddressDraft> _addresses = [_VendorAddressDraft(isPrimary: true)];
  bool _submitting = false;
  VendorTypeOption? _selectedType;

  static final _countries = <String>[
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
  ];

  static final _dropdownValueStyle = AppFonts.bodyMedium(
    color: AppColors.inkStrong,
  ).copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  Future<void> _pickVendorType() async {
    final picked = await showVendorTypePickerSheet(
      context: context,
      selected: _selectedType,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedType = picked);
  }

  @override
  void dispose() {
    for (final c in [_vendorName, _email, _phone]) {
      c.dispose();
    }
    for (final address in _addresses) {
      address.dispose();
    }
    super.dispose();
  }

  void _addAddress() {
    setState(() => _addresses.add(_VendorAddressDraft()));
  }

  void _removeAddress(int index) {
    if (_addresses.length <= 1) return;
    setState(() {
      final removed = _addresses.removeAt(index);
      final wasPrimary = removed.isPrimary;
      removed.dispose();
      if (wasPrimary && _addresses.isNotEmpty) {
        _addresses.first.isPrimary = true;
      }
    });
  }

  void _setPrimaryAddress(int index) {
    setState(() {
      for (var i = 0; i < _addresses.length; i++) {
        _addresses[i].isPrimary = i == index;
      }
    });
  }

  List<VendorAddressModel> _buildAddressModels() {
    final models = <VendorAddressModel>[];
    for (final draft in _addresses) {
      final model = draft.toModel();
      if (model != null) models.add(model);
    }
    if (models.isEmpty) return models;
    if (!models.any((a) => a.isPrimary)) {
      models[0] = VendorAddressModel(
        id: models[0].id,
        addressLine1: models[0].addressLine1,
        addressLine2: models[0].addressLine2,
        city: models[0].city,
        state: models[0].state,
        country: models[0].country,
        pincode: models[0].pincode,
        isPrimary: true,
      );
    }
    return models;
  }

  Future<void> _create() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedType == null) {
      context.showAppTopToast(
        title: 'Vendor type is required',
        type: AppTopToastType.error,
      );
      return;
    }

    final addressModels = _buildAddressModels();
    if (addressModels.isEmpty) {
      context.showAppTopToast(
        title: 'At least one address is required',
        type: AppTopToastType.error,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = VendorWritePayload.build(
        name: _vendorName.text,
        email: _email.text,
        phone: _phone.text,
        type: _selectedType!.id,
        addresses: addressModels,
      );
      await ref.read(vendorsApiClientProvider).createVendor(payload);
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Vendor created',
        subtitle: _vendorName.text.trim(),
        type: AppTopToastType.success,
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Could not create vendor',
        subtitle: ApiResponseMessage.fromAnyError(e),
        type: AppTopToastType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _sectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: AppFonts.labelSmall(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _requiredLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: AppFonts.labelSmall(color: _labelGrey).copyWith(
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          children: [
            TextSpan(text: text.toUpperCase()),
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionalLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AppFonts.labelSmall(color: _labelGrey).copyWith(
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller, {
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppTextField(
        controller: controller,
        hintText: hint,
        borderRadius: 8,
        keyboardType: keyboardType,
        validator: validator,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.textFieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.textFieldBorder),
      ),
    );
  }

  Widget _addressBlock(int index, _VendorAddressDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_addresses.length > 1) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Address ${index + 1}',
                  style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_addresses.length > 1)
                IconButton(
                  onPressed: () => _removeAddress(index),
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            value: draft.isPrimary,
            onChanged: (_) => _setPrimaryAddress(index),
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Primary address',
              style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        AppAddressFields(
          line1: draft.address1,
          line2: draft.address2,
          city: draft.city,
          state: draft.state,
          postalCode: draft.pincode,
          layout: AppAddressLayout.entityWithCountryDropdown,
          borderRadius: 8,
          countryDropdownValue: draft.country,
          countryDropdownOptions: _countries,
          onCountryDropdownChanged: (v) => setState(() => draft.country = v),
          dropdownDecoration: _dropdownDecoration(),
          dropdownValueStyle: _dropdownValueStyle,
          line1Validator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
          cityValidator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
          stateValidator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
          postalCodeValidator: (v) =>
              v == null || v.trim().isEmpty ? 'Required' : null,
          labelBuilder: (text, {required = false}) => required
              ? _requiredLabel(text)
              : _optionalLabel(text),
          onCountryResolved: (country) {
            final matched =
                matchCountryOption(country, _countries) ?? country;
            setState(() {
              if (!_countries.contains(matched)) {
                _countries.insert(0, matched);
              }
              draft.country = matched;
            });
          },
        ),
        if (index < _addresses.length - 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 4),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: AppColors.inkStrong,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Add Vendor',
          style: AppFonts.titleLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        decoration: const BoxDecoration(
          color: _cardBg,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _submitting ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _submitting ? 'Creating...' : 'Create',
              style: AppFonts.titleMedium(color: AppColors.white).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeading('BASIC INFO'),
                  _requiredLabel('Vendor Name'),
                  _textField(
                    _vendorName,
                    hint: 'Enter vendor name',
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  _requiredLabel('Vendor Type'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FormField<VendorTypeOption>(
                      validator: (_) =>
                          _selectedType == null ? 'Required' : null,
                      builder: (field) {
                        final hasValue = _selectedType != null;
                        final type = _selectedType;
                        final chipBg =
                            type != null ? parseHexColor(type.bgColor ?? '') : null;
                        final chipFg =
                            type != null ? parseHexColor(type.textColor ?? '') : null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: _pickVendorType,
                              borderRadius: BorderRadius.circular(8),
                              child: InputDecorator(
                                decoration: _dropdownDecoration().copyWith(
                                  errorText: field.errorText,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: hasValue && chipBg != null
                                          ? Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: chipBg,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  type!.name,
                                                  style: _dropdownValueStyle
                                                      .copyWith(
                                                    color: chipFg ??
                                                        AppColors.inkStrong,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Text(
                                              hasValue
                                                  ? type!.name
                                                  : 'Search vendor type',
                                              style: hasValue
                                                  ? _dropdownValueStyle
                                                  : AppFonts.bodyMedium(
                                                      color: AppColors
                                                          .textFieldHint,
                                                    ).copyWith(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                            ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: AppColors.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeading('CONTACT'),
                  _requiredLabel('Email'),
                  _textField(
                    _email,
                    hint: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  _optionalLabel('Phone'),
                  _textField(
                    _phone,
                    hint: 'Phone number',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeading('ADDRESS'),
                  for (var i = 0; i < _addresses.length; i++)
                    _addressBlock(i, _addresses[i]),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addAddress,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add another address'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
