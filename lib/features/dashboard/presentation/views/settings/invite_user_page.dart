import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/utils/phone_number_utils.dart';
import 'package:red5/core/widgets/app_phone_text_field.dart';
import 'package:red5/core/widgets/app_address_fields.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/invite_user_service.dart';
import 'package:red5/features/dashboard/presentation/providers/invite_user_ui_provider.dart';
import 'package:red5/features/user_profile/data/role_models.dart';
import 'package:red5/features/user_profile/data/roles_api_client.dart';

/// Invite a user: basic info, contact, address, send action.
class InviteUserPage extends ConsumerStatefulWidget {
  const InviteUserPage({super.key});

  static const path = '/settings/users/invite';
  static const name = 'settings-invite-user';

  @override
  ConsumerState<InviteUserPage> createState() => _InviteUserPageState();
}

class _InviteUserPageState extends ConsumerState<InviteUserPage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  CountryCode _phoneCountry = PhoneNumberUtils.defaultCountry;
  final _emailController = TextEditingController();
  final _addr1Controller = TextEditingController();
  final _addr2Controller = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  String _gender = 'Male';
  int? _selectedRoleId;
  List<RoleModel> _roles = const [];
  bool _rolesLoading = true;

  static const _labelGrey = Color(0xFF6B7280);
  static const _fieldBorderGrey = Color(0xFFD8D8DA);
  static const _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await sl<RolesApiClient>().fetchAllRoles();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _rolesLoading = false;
        if (_selectedRoleId == null && roles.isNotEmpty) {
          _selectedRoleId = int.tryParse(roles.first.id);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _rolesLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addr1Controller.dispose();
    _addr2Controller.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  OutlineInputBorder _outlineBorder({bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: focused ? AppColors.textFieldFocusBorder : _fieldBorderGrey,
        width: focused ? 1.2 : 1,
      ),
    );
  }

  InputDecoration _dropdownDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _outlineBorder(),
      enabledBorder: _outlineBorder(),
      focusedBorder: _outlineBorder(focused: true),
      disabledBorder: _outlineBorder(),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }

  TextStyle _fieldTextStyle() {
    return AppFonts.bodyMedium(color: AppColors.inkStrong)
        .copyWith(fontWeight: FontWeight.w600, fontSize: 15);
  }

  Widget _sectionHeader(String uppercaseTitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.inkStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '| $uppercaseTitle',
            style: AppFonts.labelMedium(color: _labelGrey).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppFonts.bodySmall(
          color: _labelGrey,
        ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _emailValidator(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _roleValidator(int? _) {
    if (_selectedRoleId == null) return 'Role is required';
    return null;
  }

  Widget _genderDropdown(bool submitting) {
    return InputDecorator(
      decoration: _dropdownDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _gender,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B7280),
          ),
          style: _fieldTextStyle(),
          dropdownColor: AppColors.white,
          padding: EdgeInsets.zero,
          items: _genderOptions
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e, style: _fieldTextStyle()),
                ),
              )
              .toList(),
          onChanged: submitting
              ? null
              : (value) {
                  if (value != null) setState(() => _gender = value);
                },
        ),
      ),
    );
  }

  Widget _roleDropdown(bool submitting) {
    if (_rolesLoading) {
      return InputDecorator(
        decoration: _dropdownDecoration(),
        child: Text(
          'Loading roles…',
          style: _fieldTextStyle().copyWith(color: _labelGrey),
        ),
      );
    }
    if (_roles.isEmpty) {
      return InputDecorator(
        decoration: _dropdownDecoration(),
        child: Text(
          'No roles available',
          style: _fieldTextStyle().copyWith(color: _labelGrey),
        ),
      );
    }

    final items = <DropdownMenuItem<int>>[];
    for (final role in _roles) {
      final id = int.tryParse(role.id);
      if (id == null) continue;
      items.add(
        DropdownMenuItem<int>(
          value: id,
          child: Text(role.roleName, style: _fieldTextStyle()),
        ),
      );
    }

    final value = _selectedRoleId != null &&
            items.any((e) => e.value == _selectedRoleId)
        ? _selectedRoleId
        : null;

    return InputDecorator(
      decoration: _dropdownDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value,
          hint: Text('Select role', style: _fieldTextStyle()),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B7280),
          ),
          style: _fieldTextStyle(),
          dropdownColor: AppColors.white,
          padding: EdgeInsets.zero,
          items: items,
          onChanged: submitting
              ? null
              : (value) => setState(() => _selectedRoleId = value),
        ),
      ),
    );
  }

  Future<void> _onSendInvite() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedRoleId == null) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Please select a role')),
      );
      return;
    }

    final ui = ref.read(inviteUserUiProvider.notifier);
    ui.setSubmitting(true);
    try {
      final payload = InviteUserPayload(
        email: _emailController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber:
            PhoneNumberUtils.formatFull(_phoneCountry, _phoneController.text),
        gender: _gender,
        role: _selectedRoleId!,
        address1: _addr1Controller.text.trim(),
        address2: _addr2Controller.text.trim(),
        country: _countryController.text.trim(),
        state: _stateController.text.trim(),
        city: _cityController.text.trim(),
        pincode: _pincodeController.text.trim(),
      );
      await sl<InviteUserService>().invite(payload);
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: AppStrings.apiErrorInviteUser,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) ui.setSubmitting(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitting = ref.watch(inviteUserUiProvider).submitting;
    final fieldTextStyle = _fieldTextStyle();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
          onPressed: submitting ? null : () => context.pop(),
        ),
        title: Text(
          'Invite User',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionHeader('BASIC INFO'),
                      _label('First Name'),
                      AppTextField(
                        controller: _firstNameController,
                        hintText: 'Enter first name',
                        enabled: !submitting,
                        textStyle: fieldTextStyle,
                        validator: (v) => _required(v, 'First name'),
                      ),
                      const SizedBox(height: 14),
                      _label('Last Name'),
                      AppTextField(
                        controller: _lastNameController,
                        hintText: 'Enter last name',
                        enabled: !submitting,
                        textStyle: fieldTextStyle,
                        validator: (v) => _required(v, 'Last name'),
                      ),
                      const SizedBox(height: 14),
                      _label('Role'),
                      FormField<int>(
                        validator: _roleValidator,
                        builder: (state) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _roleDropdown(submitting),
                              if (state.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    state.errorText!,
                                    style: AppFonts.bodySmall(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _label('Gender'),
                      _genderDropdown(submitting),
                      _sectionHeader('CONTACT'),
                      _label('Email'),
                      AppTextField(
                        controller: _emailController,
                        hintText: 'Enter email address',
                        keyboardType: TextInputType.emailAddress,
                        enabled: !submitting,
                        textStyle: fieldTextStyle,
                        validator: _emailValidator,
                      ),
                      const SizedBox(height: 14),
                      _label('Phone'),
                      AppPhoneTextField(
                        controller: _phoneController,
                        hintText: 'Phone number',
                        enabled: !submitting,
                        textStyle: fieldTextStyle,
                        onCountryChanged: (c) => _phoneCountry = c,
                        validator: (v) => PhoneNumberUtils.validateNational(
                          national: v,
                          emptyMessage: 'Phone is required',
                          invalidMessage: 'Enter a valid phone number',
                        ),
                      ),
                      _sectionHeader('ADDRESS'),
                      AppAddressFields(
                        line1: _addr1Controller,
                        line2: _addr2Controller,
                        city: _cityController,
                        state: _stateController,
                        postalCode: _pincodeController,
                        countryController: _countryController,
                        enabled: !submitting,
                        layout: AppAddressLayout.settings,
                        textStyle: fieldTextStyle,
                        line1Hint: 'Start typing an address',
                        line2Hint: 'Suite, unit, etc. (optional)',
                        countryHint: 'Enter country',
                        cityHint: 'Enter city',
                        stateHint: 'Enter state',
                        postalCodeHint: 'Enter pincode',
                        postalCodeLabel: 'Pincode',
                        line1Validator: (v) => _required(v, 'Address line 1'),
                        countryValidator: (v) => _required(v, 'Country'),
                        cityValidator: (v) => _required(v, 'City'),
                        stateValidator: (v) => _required(v, 'State'),
                        postalCodeValidator: (v) => _required(v, 'Pincode'),
                        labelBuilder: (text, {required = false}) =>
                            _label(text),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF2563EB),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'The user will be sent an invitation email '
                                'to set up their account.',
                                style: AppFonts.bodyMedium(
                                  color: const Color(0xFF4B5563),
                                ).copyWith(height: 1.35, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: submitting ? null : _onSendInvite,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: const Color(0xFF9CA3AF),
                    disabledForegroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Send Invite',
                          style: AppFonts.labelLarge(color: Colors.white)
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
