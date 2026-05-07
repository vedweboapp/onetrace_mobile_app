import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/company_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';

/// Personal profile + RED 5 sidebar; edit mode adds multi phone/email, add rows, save.
class PersonalProfilePage extends StatefulWidget {
  const PersonalProfilePage({super.key});

  static const path = '/settings/personal-profile';
  static const name = 'settings-personal-profile';

  @override
  State<PersonalProfilePage> createState() => _PersonalProfilePageState();
}

class _PersonalProfilePageState extends State<PersonalProfilePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _profilePhotoBytes;
  bool _photoPickInFlight = false;

  final _firstNameController = TextEditingController(text: 'John');
  final _lastNameController = TextEditingController(text: 'Doe');
  final _roleController = TextEditingController(text: 'Site Supervisor');
  final _dobController = TextEditingController(text: '01/01/1990');
  final _addr1Controller = TextEditingController(text: '123 Industrial Way');
  final _addr2Controller = TextEditingController(text: 'Suite 400');
  final _cityController = TextEditingController(text: 'San Francisco');
  final _stateController = TextEditingController(text: 'California');
  final _zipController = TextEditingController(text: '94105');

  late final List<TextEditingController> _phoneControllers;
  late final List<TextEditingController> _emailControllers;

  final _extraAddr1 = TextEditingController();
  final _extraAddr2 = TextEditingController();
  final _extraCity = TextEditingController();
  final _extraState = TextEditingController();
  final _extraZip = TextEditingController();

  String _gender = 'Male';

  static const _fieldBorderGrey = Color(0xFFD8D8DA);
  static const _labelGrey = Color(0xFF6B7280);

  /// Off by default; tap edit to show multi-row contact + add buttons + save.
  bool _editable = false;
  bool _showExtraAddress = false;

  @override
  void initState() {
    super.initState();
    _phoneControllers = [
      TextEditingController(text: '+1 (555) 000-1234'),
      TextEditingController(text: '+1 (555) 000-1234'),
    ];
    _emailControllers = [
      TextEditingController(text: 'john.doe@acmeconstruction.com'),
    ];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _roleController.dispose();
    _dobController.dispose();
    _addr1Controller.dispose();
    _addr2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _extraAddr1.dispose();
    _extraAddr2.dispose();
    _extraCity.dispose();
    _extraState.dispose();
    _extraZip.dispose();
    for (final c in _phoneControllers) {
      c.dispose();
    }
    for (final c in _emailControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _closeDrawerPush(String route) {
    _scaffoldKey.currentState?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.push(route);
    });
  }

  void _logoutToDashboard() {
    _scaffoldKey.currentState?.closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(DashboardPage.path);
    });
  }

  void _toggleEdit() => setState(() => _editable = !_editable);

  void _saveChanges() {
    setState(() => _editable = false);
    context.showTopSnackBar(
      const SnackBar(content: Text('Profile changes saved')),
    );
  }

  void _addPhone() {
    setState(() {
      _phoneControllers.add(TextEditingController(text: ''));
    });
  }

  void _removePhone(int index) {
    if (_phoneControllers.length <= 1) return;
    setState(() {
      final removed = _phoneControllers.removeAt(index);
      removed.dispose();
    });
  }

  void _addEmail() {
    setState(() {
      _emailControllers.add(TextEditingController(text: ''));
    });
  }

  void _removeEmail(int index) {
    if (_emailControllers.length <= 1) return;
    setState(() {
      final removed = _emailControllers.removeAt(index);
      removed.dispose();
    });
  }

  void _addAddressBlock() => setState(() => _showExtraAddress = true);

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

  Future<void> _pickProfilePhoto(ImageSource source) async {
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
      setState(() => _profilePhotoBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(content: Text(_photoPickErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _photoPickInFlight = false);
    }
  }

  void _showProfilePhotoOptionsSheet() {
    FocusScope.of(context).unfocus();
    final bottomInset = MediaQuery.of(context).padding.bottom;
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
                  const Divider(height: 1, thickness: 1, color: Color(0xFFEAEAEC)),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 4,
                    ),
                    leading: Icon(Icons.photo_camera_outlined, color: AppColors.inkStrong),
                    title: Text(
                      'Take photo',
                      style: AppFonts.bodyLarge(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _pickProfilePhoto(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 4,
                    ),
                    leading: Icon(
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
                      await _pickProfilePhoto(ImageSource.gallery);
                    },
                  ),
                  if (_profilePhotoBytes != null)
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
                        setState(() => _profilePhotoBytes = null);
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

  OutlineInputBorder _outlineBorder({bool focused = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: focused ? AppColors.textFieldFocusBorder : _fieldBorderGrey,
        width: focused ? 1.2 : 1,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    Widget? suffix,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.white,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _outlineBorder(),
      enabledBorder: _outlineBorder(),
      focusedBorder: _outlineBorder(focused: true),
      disabledBorder: _outlineBorder(),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }

  TextStyle _fieldTextStyle() {
    return AppFonts.bodyMedium(
      color: AppColors.inkStrong,
    ).copyWith(fontWeight: FontWeight.w500, fontSize: 15);
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
            '$uppercaseTitle',
            style: AppFonts.labelMedium(color: _labelGrey).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabelCaps(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        text,
        style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF)).copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppFonts.bodyMedium1(
          color: _labelGrey,
        ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }

  Widget _sidebarNavTile({
    required String title,
    required String iconAsset,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? const Color(0xFFF2F2F4) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Image.asset(
                  iconAsset,
                  width: 22,
                  height: 22,
                  color: const Color(0xFF4B5563),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style:
                        AppFonts.bodyMedium(
                          color: selected
                              ? AppColors.inkStrong
                              : const Color(0xFF525860),
                        ).copyWith(
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 15,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileHeader() {
    final hasPhoto = _profilePhotoBytes != null;
    final photoReady = _editable;

    void openPick() {
      if (!photoReady) return;
      _showProfilePhotoOptionsSheet();
    }

    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 108,
                  height: 108,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: const Color(0xFFE5E7EB),
                        backgroundImage: hasPhoto ? MemoryImage(_profilePhotoBytes!) : null,
                        child: !hasPhoto
                            ? Icon(
                                Icons.person_rounded,
                                size: 68,
                                color: AppColors.textFieldHint,
                              )
                            : null,
                      ),
                      if (_photoPickInFlight)
                        ClipOval(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.35),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_editable)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Material(
                      color: Colors.black,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: openPick,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(9),
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
        const SizedBox(height: 12),
        GestureDetector(
          onTap: openPick,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    'Change Profile Photo',
                    textAlign: TextAlign.center,
                    style: AppFonts.labelMedium(
                      color: photoReady ? const Color(0xFF374151) : _labelGrey,
                    ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _genderDropdown() {
    return InputDecorator(
      decoration: _fieldDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: DropdownButtonHideUnderline(
        child: SizedBox(
          height: 24,
          child: DropdownButton<String>(
            isDense: true,
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
            onChanged: !_editable
                ? null
                : (value) {
                    if (value != null) setState(() => _gender = value);
                  },
          ),
        ),
      ),
    );
  }

  Widget _addRowButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: !_editable ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 20,
                  color: !_editable ? _labelGrey : AppColors.inkStrong,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppFonts.bodyMedium(
                    color: !_editable ? _labelGrey : AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneFieldRow(int index) {
    final enabled = _editable;
    final showTrash = _editable && _phoneControllers.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (index == 0) _label('Phone'),
          AppTextField(
            controller: _phoneControllers[index],
            hintText: '',
            keyboardType: TextInputType.phone,
            enabled: enabled,
            hintStyle: const TextStyle(color: Colors.transparent, height: 0),
            suffixIcon: showTrash
                ? IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFE53935),
                    ),
                    onPressed: () => _removePhone(index),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _emailFieldRow(int index) {
    final enabled = _editable;
    final showTrash = _editable && _emailControllers.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (index == 0) _label('Email'),
          AppTextField(
            controller: _emailControllers[index],
            hintText: '',
            keyboardType: TextInputType.emailAddress,
            enabled: enabled,
            hintStyle: const TextStyle(color: Colors.transparent, height: 0),
            suffixIcon: showTrash
                ? IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFE53935),
                    ),
                    onPressed: () => _removeEmail(index),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _editable;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      drawerEnableOpenDragGesture: true,
      drawer: Drawer(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        width: MediaQuery.sizeOf(context).width * 0.82,
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'RED 5',
                      style: AppFonts.headlineSmall(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w800, fontSize: 22),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Exit',
                      onPressed: _logoutToDashboard,
                      icon: Icon(
                        Icons.exit_to_app_rounded,
                        color: AppColors.inkStrong,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  children: [
                    _sectionLabelCaps('GENERAL'),
                    _sidebarNavTile(
                      title: 'Personal Profile',
                      iconAsset: 'assets/images/person.png',
                      selected: true,
                      onTap: () => _scaffoldKey.currentState?.closeDrawer(),
                    ),
                    _sidebarNavTile(
                      title: 'Users',
                      iconAsset: 'assets/images/public.png',
                      selected: false,
                      onTap: () => _closeDrawerPush(UsersSettingsPage.path),
                    ),
                    _sidebarNavTile(
                      title: 'Company Settings',
                      iconAsset: 'assets/images/company.png',
                      selected: false,
                      onTap: () => _closeDrawerPush(CompanySettingsPage.path),
                    ),
                    _sectionLabelCaps('CUSTOMISATION'),
                    _sidebarNavTile(
                      title: 'Meta Data',
                      iconAsset: 'assets/images/database (1).png',
                      selected: false,
                      onTap: () => _closeDrawerPush(MetadataSettingsPage.path),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.inkStrong),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: const Color(0xFFECECEC),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toggleEdit,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: _editable
                        ? const Icon(
                            Icons.check_rounded,
                            size: 22,
                            color: AppColors.inkStrong,
                          )
                        : Image.asset(
                            'assets/images/edit_icon.png',
                            width: 18,
                            height: 18,
                            color: AppColors.inkStrong,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
        title: Text(
          'Personal Profile',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _profileHeader(),
          const SizedBox(height: 28),
          _sectionHeader('BASIC INFO'),
          const SizedBox(height: 14),
          _label('First Name'),
          AppTextField(
            controller: _firstNameController,
            hintText: '',
            enabled: enabled,
            hintStyle: const TextStyle(color: Colors.transparent, height: 0),
          ),
          const SizedBox(height: 14),
          _label('Last Name'),
          AppTextField(
            controller: _lastNameController,
            hintText: '',
            enabled: enabled,
            hintStyle: const TextStyle(color: Colors.transparent, height: 0),
          ),
          const SizedBox(height: 14),
          _label('Role'),
          AppTextField(
            controller: _roleController,
            hintText: '',
            enabled: enabled,
            hintStyle: const TextStyle(color: Colors.transparent, height: 0),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_label('Gender'), _genderDropdown()],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Date of Birth'),
                    TextField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: enabled ? _pickDob : null,
                      style: _fieldTextStyle(),
                      decoration: _fieldDecoration(
                        suffix: IconButton(
                          icon: Icon(
                            Icons.calendar_month_outlined,
                            color: enabled
                                ? const Color(0xFF6B7280)
                                : _labelGrey,
                            size: 22,
                          ),
                          onPressed: enabled ? _pickDob : null,
                        ),
                      ),
                      enabled: enabled,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _sectionHeader('CONTACT'),
          const SizedBox(height: 14),
          if (!_editable) ...[
            _label('Phone'),
            AppTextField(
              controller: _phoneControllers.first,
              hintText: '',
              keyboardType: TextInputType.phone,
              enabled: false,
              hintStyle: const TextStyle(color: Colors.transparent, height: 0),
            ),
            const SizedBox(height: 14),
            _label('Email'),
            AppTextField(
              controller: _emailControllers.first,
              hintText: '',
              keyboardType: TextInputType.emailAddress,
              enabled: false,
              hintStyle: const TextStyle(color: Colors.transparent, height: 0),
            ),
          ] else ...[
            for (var i = 0; i < _phoneControllers.length; i++)
              _phoneFieldRow(i),
            _addRowButton(label: '+ Add Phone', onPressed: _addPhone),
            const SizedBox(height: 8),
            for (var i = 0; i < _emailControllers.length; i++)
              _emailFieldRow(i),
            _addRowButton(label: '+ Add Email', onPressed: _addEmail),
          ],
          const SizedBox(height: 28),
          _sectionHeader('ADDRESS'),
          _label('Address Line 1'),
          AppTextField(
            controller: _addr1Controller,
            hintText: '',
            enabled: enabled,
            hintStyle: const TextStyle(color: Colors.transparent, height: 0),
          ),
          const SizedBox(height: 14),
          _label('Address Line 2'),
          AppTextField(
            controller: _addr2Controller,
            hintText: '',
            enabled: enabled,
            hintStyle: const TextStyle(color: Colors.transparent, height: 0),
          ),
          const SizedBox(height: 14),
          _label('City'),
          AppTextField(
            controller: _cityController,
            hintText: '',
            enabled: enabled,
            hintStyle: const TextStyle(color: Colors.transparent, height: 0),
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
                      enabled: enabled,
                      hintStyle: const TextStyle(
                        color: Colors.transparent,
                        height: 0,
                      ),
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
                      enabled: enabled,
                      hintStyle: const TextStyle(
                        color: Colors.transparent,
                        height: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_editable) ...[
            _addRowButton(label: '+ Add Address', onPressed: _addAddressBlock),
            if (_showExtraAddress) ...[
              const SizedBox(height: 20),
              _label('Address Line 1'),
              AppTextField(
                controller: _extraAddr1,
                hintText: '',
                hintStyle: const TextStyle(
                  color: Colors.transparent,
                  height: 0,
                ),
              ),
              const SizedBox(height: 14),
              _label('Address Line 2'),
              AppTextField(
                controller: _extraAddr2,
                hintText: '',
                hintStyle: const TextStyle(
                  color: Colors.transparent,
                  height: 0,
                ),
              ),
              const SizedBox(height: 14),
              _label('City'),
              AppTextField(
                controller: _extraCity,
                hintText: '',
                hintStyle: const TextStyle(
                  color: Colors.transparent,
                  height: 0,
                ),
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
                          controller: _extraState,
                          hintText: '',
                          hintStyle: const TextStyle(
                            color: Colors.transparent,
                            height: 0,
                          ),
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
                          controller: _extraZip,
                          hintText: '',
                          keyboardType: TextInputType.text,
                          hintStyle: const TextStyle(
                            color: Colors.transparent,
                            height: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (_editable) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saveChanges,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF121212),
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Save Changes',
                  style: AppFonts.titleSmall(
                    color: AppColors.white,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
