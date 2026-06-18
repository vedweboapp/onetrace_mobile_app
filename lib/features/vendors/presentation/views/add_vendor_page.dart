import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/vendors/data/vendor_models.dart';
import 'package:red5/features/vendors/data/vendors_api_client.dart';

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
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();

  String _country = 'India';
  bool _submitting = false;
  bool _typesLoading = true;
  String? _typesError;
  List<VendorTypeOption> _vendorTypes = const [];
  VendorTypeOption? _selectedType;

  static const _countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
  ];

  static final _dropdownValueStyle = AppFonts.bodyMedium(
    color: AppColors.inkStrong,
  ).copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVendorTypes());
  }

  Future<void> _loadVendorTypes() async {
    setState(() {
      _typesLoading = true;
      _typesError = null;
    });
    try {
      final types = await ref.read(vendorsApiClientProvider).fetchVendorTypes();
      if (!mounted) return;
      setState(() {
        _vendorTypes = types;
        _selectedType = types.isEmpty ? null : types.first;
        _typesLoading = false;
        _typesError = types.isEmpty ? 'No vendor types available' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _typesLoading = false;
        _typesError = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load vendor types',
        );
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _vendorName,
      _email,
      _phone,
      _address1,
      _address2,
      _city,
      _state,
      _pincode,
    ]) {
      c.dispose();
    }
    super.dispose();
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

    setState(() => _submitting = true);
    try {
      final payload = VendorWritePayload.build(
        name: _vendorName.text,
        email: _email.text,
        phone: _phone.text,
        type: _selectedType!.id,
        addresses: [
          VendorAddressModel(
            addressLine1: _address1.text,
            addressLine2: _address2.text,
            city: _city.text,
            state: _state.text,
            country: _country,
            pincode: _pincode.text,
            isPrimary: true,
          ),
        ],
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

  Widget _halfRow({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
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
            onPressed: _submitting || _typesLoading ? null : _create,
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
                  if (_typesLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  else if (_typesError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _typesError!,
                            style: AppFonts.bodySmall(
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadVendorTypes,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: DropdownButtonFormField<VendorTypeOption>(
                        value: _selectedType,
                        items: _vendorTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.name, style: _dropdownValueStyle),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedType = value),
                        isExpanded: true,
                        decoration: _dropdownDecoration(),
                        validator: (v) => v == null ? 'Required' : null,
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
                  _optionalLabel('Address Line 1'),
                  _textField(_address1, hint: 'Address line 1'),
                  _optionalLabel('Address Line 2'),
                  _textField(_address2, hint: 'Address line 2'),
                  _optionalLabel('Country'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DropdownButtonFormField<String>(
                      value: _country,
                      items: _countries
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: _dropdownValueStyle),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _country = v);
                      },
                      isExpanded: true,
                      decoration: _dropdownDecoration(),
                    ),
                  ),
                  _halfRow(
                    left: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _optionalLabel('City'),
                        _textField(_city, hint: 'City'),
                      ],
                    ),
                    right: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _optionalLabel('State / Province'),
                        _textField(_state, hint: 'State'),
                      ],
                    ),
                  ),
                  _requiredLabel('Pincode'),
                  _textField(
                    _pincode,
                    hint: 'Pincode',
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
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
