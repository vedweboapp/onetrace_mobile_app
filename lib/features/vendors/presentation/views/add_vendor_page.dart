import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';

class AddVendorPage extends StatefulWidget {
  const AddVendorPage({super.key});

  static const path = '/vendors/add';
  static const name = 'add-vendor';

  @override
  State<AddVendorPage> createState() => _AddVendorPageState();
}

class _AddVendorPageState extends State<AddVendorPage> {
  static const _pageBg = Color(0xFFF7F7F8);
  static const _cardBg = AppColors.white;
  static const _labelGrey = Color(0xFF6B7280);

  final _formKey = GlobalKey<FormState>();
  final _vendorName = TextEditingController();
  final _contactPerson = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();

  String _country = 'United States';
  bool _submitting = false;

  static const _countries = [
    'United States',
    'India',
    'United Kingdom',
    'Canada',
    'Australia',
  ];

  static final _dropdownValueStyle = AppFonts.bodyMedium(
    color: AppColors.inkStrong,
  ).copyWith(fontSize: 15, fontWeight: FontWeight.w600);

  @override
  void dispose() {
    for (final c in [
      _vendorName,
      _contactPerson,
      _email,
      _phone,
      _address1,
      _address2,
      _city,
      _state,
      _postalCode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _submitting = false);
    context.showAppTopToast(
      title: 'Vendor created',
      subtitle: _vendorName.text.trim(),
      type: AppTopToastType.success,
    );
    context.pop(true);
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
              'Create',
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
                  _sectionHeading('PRIMARY CONTACT'),
                  _optionalLabel('Contact Person'),
                  _textField(_contactPerson, hint: 'Contact person'),
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
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.textFieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: AppColors.textFieldBorder),
                        ),
                      ),
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
                  _requiredLabel('Postal Code'),
                  _textField(
                    _postalCode,
                    hint: 'Postal code',
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
