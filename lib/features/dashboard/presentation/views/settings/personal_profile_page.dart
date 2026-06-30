import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/preferences/nav_menu_style_preference.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/storage/organization_id_storage.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:red5/core/utils/phone_number_utils.dart';
import 'package:red5/core/widgets/app_phone_text_field.dart';
import 'package:red5/core/widgets/app_address_fields.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/core/widgets/app_skeleton.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/employee_role/employee_home/employee_home_page.dart';
import 'package:red5/employee_role/presentation/employee_technician_settings_routes.dart';
import 'package:red5/employee_role/presentation/widgets/technician_settings_drawer.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/company_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/integration_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/settings_feature_flags.dart';
import 'package:red5/features/dashboard/presentation/views/settings/privacy_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';
import 'package:red5/features/user_profile/data/role_models.dart';
import 'package:red5/features/user_profile/data/roles_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_api_client.dart';
import 'package:red5/features/user_profile/data/user_profile_models.dart'
    show AppearanceSettingsModel, UserAddressModel, UserProfileModel;

/// Personal profile + RED 5 sidebar; edit mode adds multi phone/email, add rows, save.
class PersonalProfilePage extends ConsumerStatefulWidget {
  const PersonalProfilePage({
    super.key,
    this.useTechnicianSettingsNav = false,
  });

  /// When true (technician/worker routes), drawer shows only Profile + Privacy,
  /// exit returns to [TechnicianHomePage]. Profile data uses `/user-profile/` API.
  final bool useTechnicianSettingsNav;

  static const path = '/settings/personal-profile';
  static const name = 'settings-personal-profile';

  @override
  ConsumerState<PersonalProfilePage> createState() =>
      _PersonalProfilePageState();
}

enum _AppearanceMode { light, dark }

class _PersonalProfilePageState extends ConsumerState<PersonalProfilePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TabController _tabController;

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _profilePhotoBytes;
  bool _photoPickInFlight = false;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _addr1Controller = TextEditingController();
  final _addr2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();

  late final List<TextEditingController> _phoneControllers;
  final List<CountryCode> _phoneCountries = <CountryCode>[];
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

  /// `/user-profile/` state.
  UserProfileModel? _profile;
  String? _profileId;
  List<RoleModel> _roles = const [];
  int? _selectedRoleId;
  String? _pickedImageFilename;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _photoUrl;

  // --- Appearance / Branding (matches the UI shown in your screenshot) ---
  _AppearanceMode _appearanceMode = _AppearanceMode.light;
  int _selectedBrandColor = 0;
  String _systemLanguage = 'English (United States)';
  String _organizationName = '';

  List<String> _systemLanguages = const ['English (United States)'];
  List<Color> _accentColors = const [
    Color(0xFF000000),
    Color(0xFFF97316),
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFF4B5563),
  ];

  static const _brandPalette = <Color>[
    Color(0xFF000000), // #000000
    Color(0xFFF97316), // #F97316
    Color(0xFF2563EB), // #2563EB
    Color(0xFF059669), // #059669
    Color(0xFF4B5563), // #4B5563
  ];

  // --- Main app navigation (dashboard overflow menu) ---
  NavMenuStyle _navMenuStyle = NavMenuStyle.drawer;

  bool get _isTechnicianProfile => widget.useTechnicianSettingsNav;

  @override
  void initState() {
    _accentColors = List<Color>.from(_brandPalette);
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _phoneControllers = [TextEditingController()];
    _phoneCountries.add(PhoneNumberUtils.defaultCountry);
    _emailControllers = [TextEditingController()];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadProfile());
      _loadNavMenuPreference();
    });
  }

  void _loadNavMenuPreference() {
    final storage = ref.read(localStorageProvider);
    final style = NavMenuStylePreference.read(storage);
    if (mounted) setState(() => _navMenuStyle = style);
  }

  Future<void> _setNavMenuStyle(NavMenuStyle style) async {
    final storage = ref.read(localStorageProvider);
    await NavMenuStylePreference.write(storage, style);
    if (!mounted) return;
    setState(() => _navMenuStyle = style);
    if (mounted) {
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            style == NavMenuStyle.bottomSheet
                ? 'Overflow menu will open as a bottom sheet.'
                : 'Overflow menu will open from the side drawer.',
          ),
        ),
      );
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(userProfileApiClientProvider);
      final rolesApi = ref.read(rolesApiClientProvider);
      final storage = ref.read(localStorageProvider);
      final storedUserId =
          storage.getString(LocalStorageKeys.authUserId)?.trim() ?? '';

      List<RoleModel> roles = const [];
      try {
        roles = await rolesApi.fetchAllRoles();
      } catch (_) {
        roles = const [];
      }

      UserProfileModel? profile;
      if (storedUserId.isNotEmpty) {
        try {
          profile = await api.fetchProfile(storedUserId);
        } catch (_) {
          profile = null;
        }
      }
      if (profile == null) {
        final brief = await api.fetchCurrentProfile();
        if (!mounted) return;
        if (brief == null) {
          setState(() {
            _loading = false;
            _loadError = 'No profile found.';
          });
          return;
        }
        profile = brief;
        final id = brief.id.trim();
        if (id.isNotEmpty) {
          try {
            profile = await api.fetchProfile(id);
          } catch (_) {
            profile = brief;
          }
        }
      }
      if (!mounted) return;
      setState(() => _roles = roles);
      _applyProfile(profile);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = ApiResponseMessage.fromAnyError(e);
      });
    }
  }

  void _applyProfile(UserProfileModel profile) {
    _profile = profile;
    _profileId = profile.id;
    _firstNameController.text = profile.firstName;
    _lastNameController.text = profile.lastName;
    _dobController.text = profile.dateOfBirth;
    final rid = int.tryParse(
      profile.roleDetail?.id.trim() ?? profile.roleId.trim(),
    );
    _selectedRoleId = rid;

    for (final c in _phoneControllers) {
      c.dispose();
    }
    _phoneControllers.clear();
    _phoneCountries.clear();
    for (final c in _emailControllers) {
      c.dispose();
    }
    _emailControllers.clear();

    final comms = profile.communications;
    if (comms.isEmpty) {
      final parsed = PhoneNumberUtils.parse(profile.phoneNumber);
      _phoneCountries.add(parsed.country);
      _phoneControllers.add(TextEditingController(text: parsed.nationalDigits));
      _emailControllers.add(TextEditingController(text: profile.email));
    } else {
      for (final c in comms) {
        final parsed = PhoneNumberUtils.parse(c.phone);
        _phoneCountries.add(parsed.country);
        _phoneControllers.add(
          TextEditingController(text: parsed.nationalDigits),
        );
        _emailControllers.add(TextEditingController(text: c.email));
      }
      final n = math.max(_phoneControllers.length, _emailControllers.length);
      while (_phoneControllers.length < n) {
        _phoneControllers.add(TextEditingController());
        _phoneCountries.add(PhoneNumberUtils.defaultCountry);
      }
      while (_emailControllers.length < n) {
        _emailControllers.add(TextEditingController());
      }
    }

    final addrs = profile.addresses;
    if (addrs.isEmpty) {
      _addr1Controller.text = profile.addressLine1;
      _addr2Controller.text = profile.addressLine2;
      _cityController.text = profile.city;
      _stateController.text = profile.state;
      _zipController.text = profile.postalCode;
      _showExtraAddress = false;
      _extraAddr1.clear();
      _extraAddr2.clear();
      _extraCity.clear();
      _extraState.clear();
      _extraZip.clear();
    } else {
      final ordered = List<UserAddressModel>.from(addrs)
        ..sort((a, b) {
          if (a.isPrimary == b.isPrimary) return 0;
          return a.isPrimary ? -1 : 1;
        });
      final primary = ordered.first;
      _addr1Controller.text = primary.address1;
      _addr2Controller.text = primary.address2;
      _cityController.text = primary.city;
      _stateController.text = primary.state;
      _zipController.text = primary.pincode;
      if (ordered.length > 1) {
        _showExtraAddress = true;
        final second = ordered[1];
        _extraAddr1.text = second.address1;
        _extraAddr2.text = second.address2;
        _extraCity.text = second.city;
        _extraState.text = second.state;
        _extraZip.text = second.pincode;
      } else {
        _showExtraAddress = false;
        _extraAddr1.clear();
        _extraAddr2.clear();
        _extraCity.clear();
        _extraState.clear();
        _extraZip.clear();
      }
    }

    final gender = profile.gender;
    if (_genderOptions.contains(gender)) {
      _gender = gender;
    } else {
      _gender = gender.isNotEmpty ? _genderOptions.last : _genderOptions.first;
    }
    _photoUrl = profile.userImage.isEmpty ? null : profile.userImage;
    _organizationName = profile.organizationDetail?.companyName ?? '';

    final orgId = profile.organizationDetail?.idAsInt;
    if (orgId != null && profile.id != 'local-employee-profile') {
      unawaited(
        OrganizationIdStorage.persist(ref.read(localStorageProvider), orgId),
      );
    }

    _applyAppearanceSettings(profile.appearanceSettings);
  }

  void _applyAppearanceSettings(AppearanceSettingsModel? appearance) {
    if (appearance == null) return;

    _appearanceMode = appearance.themeMode == 'dark'
        ? _AppearanceMode.dark
        : _AppearanceMode.light;

    if (appearance.languageOptions.isNotEmpty) {
      _systemLanguages = appearance.languageOptions
          .map((o) => o.label)
          .toList();
      final selected = appearance.languageOptions.where(
        (o) => o.id == appearance.language,
      );
      _systemLanguage = selected.isNotEmpty
          ? selected.first.label
          : appearance.languageOptions.first.label;
    }

    if (appearance.accentPresets.isNotEmpty) {
      _accentColors = appearance.accentPresets
          .map((p) => _colorFromHex(p.hex ?? '#000000'))
          .toList();
      final selectedHex = appearance.resolvedAccentHex;
      var selectedIndex = 0;
      for (var i = 0; i < appearance.accentPresets.length; i++) {
        final hex = appearance.accentPresets[i].hex ?? '';
        if (hex.toLowerCase() == selectedHex.toLowerCase() ||
            appearance.accentPresets[i].id == appearance.accentPresetId) {
          selectedIndex = i;
          break;
        }
      }
      _selectedBrandColor = selectedIndex.clamp(0, _accentColors.length - 1);
    } else {
      _accentColors = List<Color>.from(_brandPalette);
      final hex = appearance.resolvedAccentHex;
      if (hex.isNotEmpty) {
        final target = _colorFromHex(hex);
        final idx = _accentColors.indexWhere((c) => _colorsMatch(c, target));
        if (idx >= 0) _selectedBrandColor = idx;
      }
    }
  }

  Color _colorFromHex(String hex) {
    var value = hex.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return _brandPalette.first;
    return Color(parsed);
  }

  bool _colorsMatch(Color a, Color b) =>
      a.red == b.red && a.green == b.green && a.blue == b.blue;

  static const _genderOptions = <String>['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
    _tabController.dispose();
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
      if (widget.useTechnicianSettingsNav) {
        context.go(TechnicianHomePage.path);
      } else {
        context.go(DashboardPage.path);
      }
    });
  }

  void _toggleEdit() {
    if (_loading || _saving) return;
    if (_editable) {
      _saveChanges();
      return;
    }
    setState(() => _editable = true);
  }

  Future<void> _saveChanges() async {
    final profileId = _profileId;
    if (profileId == null || profileId.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Profile not loaded yet.')),
      );
      return;
    }
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final gender = _gender.trim();
    if (firstName.isEmpty || lastName.isEmpty || gender.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text('First name, last name, and gender are required.'),
        ),
      );
      return;
    }

    String primaryEmail = '';
    for (final c in _emailControllers) {
      final t = c.text.trim();
      if (t.isNotEmpty) {
        primaryEmail = t;
        break;
      }
    }
    if (primaryEmail.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Email is required.')),
      );
      return;
    }

    String primaryPhone = '';
    for (var i = 0; i < _phoneControllers.length; i++) {
      final national = _phoneControllers[i].text.trim();
      if (national.isEmpty) continue;
      final country = i < _phoneCountries.length
          ? _phoneCountries[i]
          : PhoneNumberUtils.defaultCountry;
      primaryPhone = PhoneNumberUtils.formatFull(country, national);
      break;
    }
    if (primaryPhone.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Phone number is required.')),
      );
      return;
    }

    final roleInt = _isTechnicianProfile
        ? (int.tryParse(
              _profile?.roleDetail?.id.trim() ??
                  _profile?.roleId.trim() ??
                  '',
            ) ??
            0)
        : (_selectedRoleId ?? int.tryParse(_profile?.roleId ?? '') ?? 0);
    if (roleInt <= 0) {
      context.showTopSnackBar(const SnackBar(content: Text('Select a role.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(userProfileApiClientProvider);
      final updated = await api.replaceProfile(
        id: profileId,
        email: primaryEmail,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: primaryPhone,
        gender: gender,
        role: roleInt,
        address1: _addr1Controller.text.trim(),
        address2: _addr2Controller.text.trim(),
        profileImageBytes: _profilePhotoBytes?.toList(),
        profileImageFilename: _pickedImageFilename,
      );
      if (!mounted) return;
      _applyProfile(updated);
      setState(() {
        _saving = false;
        _editable = false;
        _profilePhotoBytes = null;
        _pickedImageFilename = null;
      });
      context.showSuccessTopPopup(
        title: 'Profile updated successfully',
        subtitle: 'Your changes have been saved.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showTopSnackBar(
        SnackBar(content: Text(ApiResponseMessage.fromAnyError(e))),
      );
    }
  }

  void _addPhone() {
    setState(() {
      _phoneControllers.add(TextEditingController(text: ''));
      _phoneCountries.add(PhoneNumberUtils.defaultCountry);
    });
  }

  void _removePhone(int index) {
    if (_phoneControllers.length <= 1) return;
    setState(() {
      final removed = _phoneControllers.removeAt(index);
      removed.dispose();
      if (index < _phoneCountries.length) {
        _phoneCountries.removeAt(index);
      }
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
      final name = picked.name.trim();
      setState(() {
        _profilePhotoBytes = bytes;
        _pickedImageFilename = name.isEmpty ? 'profile.jpg' : name;
      });
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
                    leading: Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.inkStrong,
                    ),
                    title: Text(
                      'Take photo',
                      style: AppFonts.bodyLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w500),
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
                      style: AppFonts.bodyLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w500),
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
                        setState(() {
                          _profilePhotoBytes = null;
                          _pickedImageFilename = null;
                          _photoUrl = null;
                        });
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
            uppercaseTitle,
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

  Widget _smallHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppFonts.labelMedium(color: AppColors.inkStrong).copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _appearanceToggle({bool interactive = true}) {
    final selectedBg = AppColors.white;
    final baseBg = const Color(0xFFE5E7EB);
    final enabled = interactive;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AppearanceButton(
              icon: Icons.wb_sunny_rounded,
              label: 'Light',
              selected: _appearanceMode == _AppearanceMode.light,
              selectedColor: _brandPalette[1],
              selectedBg: selectedBg,
              onTap: enabled
                  ? () =>
                        setState(() => _appearanceMode = _AppearanceMode.light)
                  : null,
            ),
          ),
          Expanded(
            child: _AppearanceButton(
              icon: Icons.nightlight_round,
              label: 'Dark',
              selected: _appearanceMode == _AppearanceMode.dark,
              selectedColor: _brandPalette[4],
              selectedBg: selectedBg,
              onTap: enabled
                  ? () => setState(() => _appearanceMode = _AppearanceMode.dark)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandColorRow({bool interactive = true}) {
    final enabled = interactive;
    return Row(
      children: [
        for (var i = 0; i < _accentColors.length; i++)
          Padding(
            padding: EdgeInsets.only(
              right: i == _accentColors.length - 1 ? 0 : 10,
            ),
            child: InkWell(
              onTap: enabled
                  ? () => setState(() => _selectedBrandColor = i)
                  : null,
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _accentColors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _selectedBrandColor == i
                        ? Colors.black
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: _selectedBrandColor == i
                    ? Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: i == 0 ? Colors.white : Colors.black,
                      )
                    : null,
              ),
            ),
          ),
        const SizedBox(width: 8),
        InkWell(
          onTap: enabled
              ? () {
                  // Placeholder: you can wire a bottom sheet later if needed.
                }
              : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(Icons.add, color: Color(0xFF9CA3AF), size: 18),
          ),
        ),
      ],
    );
  }

  Widget _systemLanguageDropdown({bool interactive = true}) {
    return InputDecorator(
      decoration: _fieldDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: SizedBox(
          height: 24,
          child: DropdownButton<String>(
            isDense: true,
            isExpanded: true,
            value: _systemLanguage,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF6B7280),
            ),
            style: _fieldTextStyle(),
            dropdownColor: AppColors.white,
            padding: EdgeInsets.zero,
            items: _systemLanguages
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e, style: _fieldTextStyle()),
                  ),
                )
                .toList(),
            onChanged: !interactive
                ? null
                : (v) => setState(() => _systemLanguage = v ?? _systemLanguage),
          ),
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
    bool enabled = true,
  }) {
    final inactiveColor =
        enabled ? const Color(0xFF525860) : const Color(0xFF9CA3AF);
    final iconColor = enabled ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected && enabled
            ? const Color(0xFFF2F2F4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Image.asset(
                  iconAsset,
                  width: 22,
                  height: 22,
                  color: iconColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style:
                        AppFonts.bodyMedium(
                          color: selected && enabled
                              ? AppColors.inkStrong
                              : inactiveColor,
                        ).copyWith(
                          fontWeight: selected && enabled
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

  ImageProvider? _avatarImage() {
    if (_profilePhotoBytes != null) return MemoryImage(_profilePhotoBytes!);
    final url = _photoUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  Widget _profileHeader() {
    final avatar = _avatarImage();
    final hasPhoto = avatar != null;
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
                        backgroundImage: avatar,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
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
            items: _genderOptions
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

  List<RoleModel> _rolesForMenu() {
    final out = List<RoleModel>.from(_roles);
    final sid = _selectedRoleId;
    if (sid == null) return out;
    final idStr = sid.toString();
    if (out.any((r) => r.id == idStr)) return out;
    final label = (_profile?.roleDetail?.roleName ?? _profile?.role ?? '').trim();
    return [
      RoleModel(id: idStr, roleName: label.isNotEmpty ? label : 'Role #$idStr'),
      ...out,
    ];
  }

  Widget _roleReadOnlyField() {
    final label = (_profile?.roleDetail?.roleName.trim().isNotEmpty ?? false)
        ? _profile!.roleDetail!.roleName.trim()
        : (_profile?.role.trim().isNotEmpty ?? false)
        ? _profile!.role.trim()
        : '—';
    return InputDecorator(
      decoration: _fieldDecoration(),
      child: Text(label, style: _fieldTextStyle()),
    );
  }

  Widget _roleDropdown(bool enabled) {
    final menu = _rolesForMenu();
    if (menu.isEmpty) {
      return InputDecorator(
        decoration: _fieldDecoration(),
        child: Text(
          'No roles available',
          style: _fieldTextStyle().copyWith(color: _labelGrey),
        ),
      );
    }
    final items = <DropdownMenuItem<int>>[];
    for (final r in menu) {
      final id = int.tryParse(r.id);
      if (id == null) continue;
      items.add(
        DropdownMenuItem<int>(
          value: id,
          child: Text(r.roleName, style: _fieldTextStyle()),
        ),
      );
    }
    final value =
        _selectedRoleId != null && items.any((e) => e.value == _selectedRoleId)
        ? _selectedRoleId
        : null;
    return InputDecorator(
      decoration: _fieldDecoration(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isDense: true,
          isExpanded: true,
          value: value,
          hint: Text(
            'Select role',
            style: _fieldTextStyle().copyWith(color: _labelGrey),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B7280),
          ),
          style: _fieldTextStyle(),
          dropdownColor: AppColors.white,
          padding: EdgeInsets.zero,
          items: items,
          onChanged: !enabled
              ? null
              : (v) => setState(() => _selectedRoleId = v),
        ),
      ),
    );
  }

  Widget _addRowButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    final bool isDisabled = !_editable;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isDisabled ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 10),
            decoration: BoxDecoration(
              color: isDisabled
                  ? _labelGrey.withOpacity(0.09)
                  : AppColors.inkStrong.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDisabled ? _labelGrey : AppColors.inkStrong,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 20,
                  color: isDisabled ? _labelGrey : AppColors.inkStrong,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppFonts.bodyMedium(
                    color: isDisabled ? _labelGrey : AppColors.inkStrong,
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
          AppPhoneTextField(
            key: ValueKey('profile-phone-$index'),
            controller: _phoneControllers[index],
            hintText: 'Phone number',
            enabled: enabled,
            initialCountry: index < _phoneCountries.length
                ? _phoneCountries[index]
                : PhoneNumberUtils.defaultCountry,
            onCountryChanged: (country) {
              if (index < _phoneCountries.length) {
                _phoneCountries[index] = country;
              } else {
                _phoneCountries.add(country);
              }
            },
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.white,
      drawerEnableOpenDragGesture: true,
      drawer: widget.useTechnicianSettingsNav
          ? TechnicianSettingsDrawer(
              selected: TechnicianSettingsSection.personalProfile,
              onExit: _logoutToDashboard,
              onPersonalProfile: () =>
                  _scaffoldKey.currentState?.closeDrawer(),
              onPrivacy: () {
                _scaffoldKey.currentState?.closeDrawer();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  context.push(EmployeeTechnicianSettingsRoutes.privacy);
                });
              },
            )
          : Drawer(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
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
                            onTap: () =>
                                _scaffoldKey.currentState?.closeDrawer(),
                          ),
                          _sidebarNavTile(
                            title: 'Users',
                            iconAsset: 'assets/images/public.png',
                            selected: false,
                            onTap: () =>
                                _closeDrawerPush(UsersSettingsPage.path),
                          ),
                          _sidebarNavTile(
                            title: 'Company Settings',
                            iconAsset: 'assets/images/company.png',
                            selected: false,
                            onTap: () =>
                                _closeDrawerPush(CompanySettingsPage.path),
                          ),
                          _sidebarNavTile(
                            title: 'Privacy',
                            iconAsset: 'assets/images/privacy.png',
                            selected: false,
                            onTap: () =>
                                _closeDrawerPush(PrivacySettingsPage.path),
                          ),
                          if (SettingsFeatureFlags.showMetaData) ...[
                            _sectionLabelCaps('CUSTOMISATION'),
                            _sidebarNavTile(
                              title: 'Meta Data',
                              iconAsset: 'assets/images/database (1).png',
                              selected: false,
                              enabled: SettingsFeatureFlags.metadataEnabled,
                              onTap: () =>
                                  _closeDrawerPush(MetadataSettingsPage.path),
                            ),
                          ],
                          _sectionLabelCaps('INTEGRATION'),
                          _sidebarNavTile(
                            title: 'Integration',
                            iconAsset: 'assets/images/integration.png',
                            selected: false,
                            onTap: () =>
                                _closeDrawerPush(IntegrationSettingsPage.path),
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
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.inkStrong,
                            ),
                          )
                        : _editable
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
        bottom: _buildAppBarBottom(),
      ),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget? _buildAppBarBottom() {
    if (_loading || (_loadError != null && _profile == null)) {
      return const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
      );
    }
    return PreferredSize(
      preferredSize: const Size.fromHeight(49),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.inkStrong,
            indicatorWeight: 3,
            labelColor: AppColors.inkStrong,
            unselectedLabelColor: _labelGrey,
            labelStyle: AppFonts.bodyMedium(
              color: AppColors.inkStrong,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 15),
            unselectedLabelStyle: AppFonts.bodyMedium(
              color: _labelGrey,
            ).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
            tabs: const [
              Tab(text: 'Personal Profile'),
              Tab(text: 'Appearance'),
            ],
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: const AppSkeletonScreenBody(
          scrollable: false,
          toastBlockCount: 4,
        ),
      );
    }
    if (_loadError != null && _profile == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.inkStrong, size: 48),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: AppFonts.bodyMedium(color: AppColors.inkStrong),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => unawaited(_loadProfile()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inkStrong,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final enabled = _editable;
    return TabBarView(
      controller: _tabController,
      children: [
        RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [_buildProfileTabContent(enabled)],
          ),
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [_buildAppearanceTabContent()],
        ),
      ],
    );
  }

  Widget _buildAppearanceTabContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('VISUAL THEME'),
        _smallHeading('Appearance'),
        _appearanceToggle(interactive: true),
        const SizedBox(height: 18),
        _smallHeading('Brand Color'),
        _brandColorRow(interactive: true),
        const SizedBox(height: 22),
        _sectionHeader('SYSTEM LANGUAGE'),
        _systemLanguageDropdown(interactive: true),
        const SizedBox(height: 22),
        _sectionHeader('NAVIGATION'),
        _smallHeading('Overflow menu'),
        Text(
          'Side drawer: top bar shows the menu icon; bottom bar is Home, Clients, and Projects only. '
          'Bottom sheet: no top menu icon; use More (⋯) on the bar to open Sites, Contacts, Groups, Products, and Quotations.',
          style: AppFonts.bodySmall(
            color: _labelGrey,
          ).copyWith(fontWeight: FontWeight.w500, height: 1.45),
        ),
        const SizedBox(height: 12),
        _navMenuStyleToggle(),
      ],
    );
  }

  Widget _navMenuStyleToggle() {
    final selectedBg = AppColors.white;
    final baseBg = const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AppearanceButton(
              icon: Icons.view_sidebar_rounded,
              label: 'Side drawer',
              selected: _navMenuStyle == NavMenuStyle.drawer,
              selectedColor: _brandPalette[2],
              selectedBg: selectedBg,
              onTap: () => unawaited(_setNavMenuStyle(NavMenuStyle.drawer)),
            ),
          ),
          Expanded(
            child: _AppearanceButton(
              icon: Icons.layers_rounded,
              label: 'Bottom sheet',
              selected: _navMenuStyle == NavMenuStyle.bottomSheet,
              selectedColor: _brandPalette[1],
              selectedBg: selectedBg,
              onTap: () =>
                  unawaited(_setNavMenuStyle(NavMenuStyle.bottomSheet)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTabContent(bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        _isTechnicianProfile
            ? _roleReadOnlyField()
            : _roleDropdown(enabled),
        if (_organizationName.isNotEmpty) ...[
          const SizedBox(height: 14),
          _label('Organization'),
          InputDecorator(
            decoration: _fieldDecoration(),
            child: Text(_organizationName, style: _fieldTextStyle()),
          ),
        ],
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
                          color: enabled ? const Color(0xFF6B7280) : _labelGrey,
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
          AppPhoneTextField(
            controller: _phoneControllers.first,
            hintText: '',
            enabled: false,
            showCountryPicker: false,
            initialCountry: _phoneCountries.isNotEmpty
                ? _phoneCountries.first
                : PhoneNumberUtils.defaultCountry,
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
          for (var i = 0; i < _phoneControllers.length; i++) _phoneFieldRow(i),
          _addRowButton(label: 'Add Phone', onPressed: _addPhone),
          const SizedBox(height: 8),
          for (var i = 0; i < _emailControllers.length; i++) _emailFieldRow(i),
          _addRowButton(label: 'Add Email', onPressed: _addEmail),
        ],
        const SizedBox(height: 28),
        _sectionHeader('ADDRESS'),
        AppAddressFields(
          line1: _addr1Controller,
          line2: _addr2Controller,
          city: _cityController,
          state: _stateController,
          postalCode: _zipController,
          enabled: enabled,
          layout: AppAddressLayout.profile,
          hintStyle: const TextStyle(color: Colors.transparent, height: 0),
          labelBuilder: (text, {required = false}) => _label(text),
          onPlaceSelected: (_) {
            if (mounted) setState(() {});
          },
        ),
        if (_editable) ...[
          _addRowButton(label: 'Add Address', onPressed: _addAddressBlock),
          if (_showExtraAddress) ...[
            const SizedBox(height: 20),
            AppAddressFields(
              line1: _extraAddr1,
              line2: _extraAddr2,
              city: _extraCity,
              state: _extraState,
              postalCode: _extraZip,
              layout: AppAddressLayout.profile,
              hintStyle: const TextStyle(color: Colors.transparent, height: 0),
              labelBuilder: (text, {required = false}) => _label(text),
              onPlaceSelected: (_) {
                if (mounted) setState(() {});
              },
            ),
          ],
        ],
        if (_editable) ...[
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _saveChanges,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF121212),
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: AppFonts.titleSmall(
                        color: AppColors.white,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AppearanceButton extends StatelessWidget {
  const _AppearanceButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedBg,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedBg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedBg : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? selectedColor : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppFonts.bodyMedium(
                  color: selected
                      ? AppColors.inkStrong
                      : const Color(0xFF6B7280),
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

