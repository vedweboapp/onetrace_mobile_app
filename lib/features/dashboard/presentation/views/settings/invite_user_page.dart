import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:red5/core/constants/app_strings.dart';
import 'package:red5/core/di/injection.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/invite_user_service.dart';
import 'package:red5/features/dashboard/presentation/providers/invite_user_ui_provider.dart';

/// Invite a user: photo (optional), basic info, contact, address, invitation notice, send action.
class InviteUserPage extends ConsumerStatefulWidget {
  const InviteUserPage({super.key});

  static const path = '/settings/users/invite';
  static const name = 'settings-invite-user';

  @override
  ConsumerState<InviteUserPage> createState() => _InviteUserPageState();
}

class _InviteUserPageState extends ConsumerState<InviteUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  final _firstNameController = TextEditingController(text: 'John');
  final _lastNameController = TextEditingController(text: 'Doe');
  final _roleController = TextEditingController(text: 'Site Supervisor');
  final _dobController = TextEditingController(text: '01/01/1990');
  final _phoneController = TextEditingController(text: '+1 (555) 000-1234');
  final _emailController =
      TextEditingController(text: 'john.doe@acmeconstruction.com');
  final _addr1Controller = TextEditingController(text: '123 Industrial Way');
  final _addr2Controller = TextEditingController(text: 'Suite 400');
  final _cityController = TextEditingController(text: 'San Francisco');
  final _stateController = TextEditingController(text: 'California');
  final _zipController = TextEditingController(text: '94105');

  String _gender = 'Male';
  bool _photoPickInFlight = false;

  static const _labelGrey = Color(0xFF6B7280);
  static const _fieldBorderGrey = Color(0xFFD8D8DA);
  static const _captionPhoto = Color(0xFF6B8FA8);

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _roleController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addr1Controller.dispose();
    _addr2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  OutlineInputBorder _outlineBorder({bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color:
            focused ? AppColors.textFieldFocusBorder : _fieldBorderGrey,
        width: focused ? 1.2 : 1,
      ),
    );
  }

  InputDecoration _dropdownDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _outlineBorder(),
      enabledBorder: _outlineBorder(),
      focusedBorder: _outlineBorder(focused: true),
      disabledBorder: _outlineBorder(),
      suffixIcon: suffixIcon,
      suffixIconConstraints:
          const BoxConstraints(minWidth: 44, minHeight: 44),
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

  String _photoPickErrorMessage(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('camera')) return 'Could not open camera.';
    if (s.contains('photo') ||
        s.contains('gallery') ||
        s.contains('permission') ||
        s.contains('denied')) {
      return 'Photos access was denied or unavailable.';
    }
    return 'Could not select image.';
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photoPickInFlight || !mounted) return;
    setState(() => _photoPickInFlight = true);
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (!mounted || picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      ref.read(inviteUserUiProvider.notifier).setProfilePhotoBytes(bytes);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(content: Text(_photoPickErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _photoPickInFlight = false);
    }
  }

  void _showPhotoOptionsSheet() {
    FocusScope.of(context).unfocus();
    final hadPhoto =
        ref.read(inviteUserUiProvider).profilePhotoBytes != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E2E4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Profile photo',
                        style: AppFonts.titleMedium(
                          color: AppColors.inkStrong,
                        ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEAEAEC),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 4,
                    ),
                    leading: const Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.inkStrong,
                    ),
                    title: Text(
                      'Take photo',
                      style: AppFonts.bodyLarge(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _pickPhoto(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 4,
                    ),
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.inkStrong,
                    ),
                    title: Text(
                      'Choose from gallery',
                      style: AppFonts.bodyLarge(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _pickPhoto(ImageSource.gallery);
                    },
                  ),
                  if (hadPhoto)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 4,
                      ),
                      leading: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE53935),
                      ),
                      title: Text(
                        'Remove photo',
                        style: AppFonts.bodyLarge(
                          color: const Color(0xFFE53935),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        ref
                            .read(inviteUserUiProvider.notifier)
                            .clearProfilePhoto();
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'Cancel',
                          style: AppFonts.bodyMedium(
                            color: _labelGrey,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDob() async {
    final initial = DateTime(1990, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        _dobController.text = '$m/$d/${picked.year}';
      });
    }
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

  Widget _genderDropdown() {
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
          items: ['Male', 'Female', 'Other']
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e, style: _fieldTextStyle()),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _gender = value);
          },
        ),
      ),
    );
  }

  Future<void> _onSendInvite() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ui = ref.read(inviteUserUiProvider.notifier);
    ui.setSubmitting(true);
    try {
      final payload = InviteUserPayload(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        role: _roleController.text.trim(),
        gender: _gender,
        dateOfBirth: _dobController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        addressLine1: _addr1Controller.text.trim(),
        addressLine2: _addr2Controller.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zipCode: _zipController.text.trim(),
        profilePhotoBytes: ref.read(inviteUserUiProvider).profilePhotoBytes,
      );
      await sl<InviteUserService>().invite(payload);
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(content: Text('Invitation sent successfully')),
      );
      context.pop();
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
    final photoBytes = ref.watch(inviteUserUiProvider).profilePhotoBytes;
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
                      Center(
                        child: GestureDetector(
                          onTap: _showPhotoOptionsSheet,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 148,
                            height: 148,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                DottedBorder(
                                  options: RoundedRectDottedBorderOptions(
                                    radius: const Radius.circular(74),
                                    strokeWidth: 1.8,
                                    color: const Color(0xFFC5CAD1),
                                    dashPattern: const [5, 4],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(72),
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      color: const Color(0xFFF5F6F8),
                                      child: photoBytes != null
                                          ? Image.memory(
                                              photoBytes,
                                              fit: BoxFit.cover,
                                            )
                                          : Icon(
                                              Icons.person_outline_rounded,
                                              size: 56,
                                              color: AppColors.mutedLight,
                                            ),
                                    ),
                                  ),
                                ),
                                if (_photoPickInFlight)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.white
                                            .withValues(alpha: 0.75),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: Material(
                                    elevation: 3,
                                    color: const Color(0xFF111111),
                                    shape: const CircleBorder(),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: submitting
                                          ? null
                                          : _showPhotoOptionsSheet,
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: Icon(
                                          Icons.photo_camera_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'Upload Profile Photo (Optional)',
                          style: AppFonts.bodyMedium(
                            color: _captionPhoto,
                          ).copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _sectionHeader('BASIC INFO'),
                      _label('First Name'),
                      AppTextField(
                        controller: _firstNameController,
                        hintText: '',
                        enabled: !submitting,
                        hintStyle:
                            const TextStyle(color: Colors.transparent),
                        textStyle: fieldTextStyle,
                        validator: (v) =>
                            _required(v, 'First name'),
                      ),
                      const SizedBox(height: 14),
                      _label('Last Name'),
                      AppTextField(
                        controller: _lastNameController,
                        hintText: '',
                        enabled: !submitting,
                        hintStyle:
                            const TextStyle(color: Colors.transparent),
                        textStyle: fieldTextStyle,
                        validator: (v) =>
                            _required(v, 'Last name'),
                      ),
                      const SizedBox(height: 14),
                      _label('Role'),
                      AppTextField(
                        controller: _roleController,
                        hintText: '',
                        enabled: !submitting,
                        hintStyle:
                            const TextStyle(color: Colors.transparent),
                        textStyle: fieldTextStyle,
                        validator: (v) => _required(v, 'Role'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Gender'),
                                _genderDropdown(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Date of Birth'),
                                TextFormField(
                                  controller: _dobController,
                                  readOnly: true,
                                  onTap:
                                      submitting ? null : _pickDob,
                                  enabled: !submitting,
                                  style: fieldTextStyle,
                                  decoration: _dropdownDecoration(
                                    suffixIcon: IconButton(
                                      icon: const Icon(
                                        Icons.calendar_month_rounded,
                                        color: Color(0xFF6B7280),
                                      ),
                                      onPressed:
                                          submitting ? null : _pickDob,
                                    ),
                                  ),
                                  validator: (v) =>
                                      _required(v, 'Date of birth'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _sectionHeader('CONTACT'),
                      _label('Phone'),
                      AppTextField(
                        controller: _phoneController,
                        hintText: '',
                        keyboardType: TextInputType.phone,
                        enabled: !submitting,
                        hintStyle:
                            const TextStyle(color: Colors.transparent),
                        textStyle: fieldTextStyle,
                        validator: (v) =>
                            _required(v, 'Phone'),
                      ),
                      const SizedBox(height: 14),
                      _label('Email'),
                      AppTextField(
                        controller: _emailController,
                        hintText: '',
                        keyboardType: TextInputType.emailAddress,
                        enabled: !submitting,
                        hintStyle:
                            const TextStyle(color: Colors.transparent),
                        textStyle: fieldTextStyle,
                        validator: _emailValidator,
                      ),
                      _sectionHeader('ADDRESS'),
                      _label('Address Line 1'),
                      AppTextField(
                        controller: _addr1Controller,
                        hintText: '',
                        enabled: !submitting,
                        hintStyle:
                            const TextStyle(color: Colors.transparent),
                        textStyle: fieldTextStyle,
                        validator: (v) =>
                            _required(v, 'Address line 1'),
                      ),
                      const SizedBox(height: 14),
                      _label('Address Line 2'),
                      AppTextField(
                        controller: _addr2Controller,
                        hintText: '',
                        enabled: !submitting,
                        hintStyle:
                            const TextStyle(color: Colors.transparent),
                        textStyle: fieldTextStyle,
                      ),
                      const SizedBox(height: 14),
                      _label('City'),
                      AppTextField(
                        controller: _cityController,
                        hintText: '',
                        enabled: !submitting,
                        hintStyle:
                            const TextStyle(color: Colors.transparent),
                        textStyle: fieldTextStyle,
                        validator: (v) => _required(v, 'City'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('State'),
                                AppTextField(
                                  controller: _stateController,
                                  hintText: '',
                                  enabled: !submitting,
                                  hintStyle:
                                      const TextStyle(
                                        color: Colors.transparent,
                                      ),
                                  textStyle: fieldTextStyle,
                                  validator: (v) =>
                                      _required(v, 'State'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('ZIP Code'),
                                AppTextField(
                                  controller: _zipController,
                                  hintText: '',
                                  keyboardType: TextInputType.text,
                                  enabled: !submitting,
                                  hintStyle:
                                      const TextStyle(
                                        color: Colors.transparent,
                                      ),
                                  textStyle: fieldTextStyle,
                                  validator: (v) =>
                                      _required(v, 'ZIP Code'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FA),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: const Color(0xFF2563EB),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'The user will be sent an invitation email '
                                'to set up their account. They will have '
                                'access to all public project documents '
                                'by default.',
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
                    disabledBackgroundColor:
                        const Color(0xFF9CA3AF),
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
