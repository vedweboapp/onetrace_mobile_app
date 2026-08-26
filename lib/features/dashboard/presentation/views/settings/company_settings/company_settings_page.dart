part of 'company_settings.dart';

class CompanySettingsPage extends ConsumerStatefulWidget {
  const CompanySettingsPage({super.key});

  static const path = '/settings/company';
  static const name = 'settings-company';

  @override
  ConsumerState<CompanySettingsPage> createState() =>
      _CompanySettingsPageState();
}

class _CompanySettingsPageState extends ConsumerState<CompanySettingsPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TabController _tabController;
  final _companyNameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addr1Controller = TextEditingController();
  final _addr2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  String _companySize = '1-10';
  String _country = 'United States';

  static const _companySizeOptions = <String>[
    '1-10',
    '11-50',
    '50-100',
    '100-500',
    '500+',
  ];

  static const _timezoneOptions = <String>[
    'UTC',
    'UTC-8 (Pacific Time)',
    'UTC-7 (Mountain Time)',
    'UTC-6 (Central Time)',
    'UTC-5 (Eastern Time)',
    'UTC+0 (GMT)',
    'UTC+1 (Central European Time)',
    'UTC+5:30 (India Standard Time)',
  ];

  static const _defaultCountryOptions = <String>[
    'United States',
    'United Kingdom',
    'Canada',
    'India',
    'Australia',
    'Germany',
    'France',
  ];

  final List<String> _countryOptions =
      List<String>.from(_defaultCountryOptions);

  HomeCurrencySettings _currencySettings = HomeCurrencySettings.defaults();
  String? _companyLogoUrl;
  Uint8List? _companyLogoBytes;
  String? _pickedLogoFilename;
  bool _logoPickInFlight = false;
  String _timezone = 'UTC';
  int? _organizationId;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  static const _homeCurrencyOptions = <String>[
    'Indian Rupee - INR',
    'US Dollar - USD',
    'Euro - EUR',
    'British Pound - GBP',
  ];

  static const _weekDays = WorkingDaysChoices.all;

  final Set<int> _operationalDays = {0, 1, 2, 3, 4};
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  String _breakDuration = '30 minutes';

  static const _breakDurationOptions = <String>[
    '15 minutes',
    '30 minutes',
    '45 minutes',
    '60 minutes',
  ];

  static const _scheduleAccent = Color(0xFF2563EB);
  static const _scheduleAccentBg = Color(0xFFEFF6FF);
  static const _innerPanelBg = Color(0xFFF3F4F6);

  static const _pageBackground = Color(0xFFF3F4F6);
  static const _panelBorder = Color(0xFFE5E7EB);
  static const _labelGrey = Color(0xFF6B7280);
  static const _photoCaption = Color(0xFF6B8FA8);

  static const _saveButtonColor = Color(0xFF111827);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCompanySettings());
  }

  Future<int?> _resolveOrganizationId() async {
    final storage = ref.read(localStorageProvider);
    var orgId = OrganizationIdStorage.read(storage);
    if (orgId != null) return orgId;

    final userId = storage.getString(LocalStorageKeys.authUserId)?.trim() ?? '';
    if (userId.isEmpty) return null;

    try {
      final profile = await ref
          .read(userProfileApiClientProvider)
          .fetchProfile(userId);
      orgId = profile.organizationDetail?.idAsInt;
      if (orgId != null) {
        await OrganizationIdStorage.persist(storage, orgId);
      }
      return orgId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCompanySettings() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final orgId = await _resolveOrganizationId();
    if (orgId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'Organization not found. Sign out and sign in again to continue.';
      });
      return;
    }
    try {
      final api = ref.read(organizationSettingsApiClientProvider);
      final settings = await api.fetchSettings(organizationId: orgId);
      if (!mounted) return;
      _organizationId = orgId;
      _applySettings(settings);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = ApiResponseMessage.fromAnyError(e);
      });
    }
  }

  TimeOfDay? _parseTimeOfDay(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String? _breakDurationFromApi(String raw) {
    return OrganizationSettingsCodec.breakDurationLabelFromApi(
      raw,
      dropdownOptions: _breakDurationOptions,
    );
  }

  List<String> _menuWithCurrent(String current, List<String> options) {
    if (current.trim().isEmpty) return options;
    if (options.contains(current)) return options;
    return [current, ...options];
  }

  void _applySettings(OrganizationSettingsModel settings) {
    _companyNameController.text = settings.companyName;
    _websiteController.text = settings.websiteLink;
    _descriptionController.text = settings.description;
    _addr1Controller.text = settings.streetAddress;
    _addr2Controller.text = '';
    _cityController.text = settings.city;
    _stateController.text = settings.state;
    _pincodeController.text = settings.pincode;
    if (settings.companySize.isNotEmpty) {
      _companySize = settings.companySize;
    }
    if (settings.country.isNotEmpty) {
      _country = settings.country;
    }
    _companyLogoUrl = settings.companyLogo.isNotEmpty
        ? settings.companyLogo
        : null;

    final start = _parseTimeOfDay(settings.startTime);
    if (start != null) _startTime = start;
    final end = _parseTimeOfDay(settings.endTime);
    if (end != null) _endTime = end;
    if (settings.timezone.isNotEmpty) _timezone = settings.timezone;

    _operationalDays.clear();
    for (final day in settings.workingDays) {
      final idx = _weekDays.indexWhere(
        (w) =>
            w.toLowerCase() == day.toLowerCase() ||
            w.toLowerCase().startsWith(day.toLowerCase()),
      );
      if (idx >= 0) _operationalDays.add(idx);
    }

    final breakLabel = _breakDurationFromApi(settings.breakDuration);
    if (breakLabel != null) _breakDuration = breakLabel;

    var homeCurrency = _homeCurrencyOptions.first;
    if (settings.currency.isNotEmpty) {
      final code = settings.currency.toUpperCase();
      final match = _homeCurrencyOptions.where(
        (o) => o.toUpperCase().contains(code),
      );
      if (match.isNotEmpty) homeCurrency = match.first;
    }

    final symbol = settings.symbol.isNotEmpty
        ? settings.symbol
        : HomeCurrencySettings.defaultSymbolFor(homeCurrency);
    final symbolPosition = settings.symbolPosition.toLowerCase() == 'after'
        ? 'After Value'
        : 'Before Value';
    final separator = settings.digitSeparator.isNotEmpty
        ? OrganizationSettingsCodec.digitSeparatorFromApi(
            settings.digitSeparator,
          )
        : HomeCurrencySettings.defaultSeparatorFor(homeCurrency);
    final formatMode = settings.format.toLowerCase().contains('code')
        ? CurrencyFormatMode.code
        : CurrencyFormatMode.symbol;

    _currencySettings = HomeCurrencySettings(
      homeCurrency: homeCurrency,
      formatMode: formatMode,
      symbol: symbol,
      symbolPosition: symbolPosition,
      digitSeparator: separator,
      decimalPlaces: settings.decimalPlaces ?? 2,
    );
  }

  List<String> _selectedWorkingDays() {
    final days = _operationalDays.map((i) => _weekDays[i]).toList();
    days.sort((a, b) => _weekDays.indexOf(a).compareTo(_weekDays.indexOf(b)));
    return days;
  }

  String _formatTimeForApi(TimeOfDay time) => '${_formatTime(time)}:00';

  OrganizationSettingsWrite _buildUpdatePayload() {
    return OrganizationSettingsWrite(
      companyName: _companyNameController.text.trim(),
      companySize: _companySize,
      websiteLink: _websiteController.text.trim(),
      description: _descriptionController.text.trim(),
      timezone: _timezone,
      streetAddress: _addr1Controller.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      country: _country,
      workingDays: _selectedWorkingDays(),
      startTime: _formatTimeForApi(_startTime),
      endTime: _formatTimeForApi(_endTime),
      breakDuration: OrganizationSettingsCodec.breakDurationToApi(
        _breakDuration,
      ),
      currency: _currencySettings.currencyCode,
      format: _currencySettings.formatMode == CurrencyFormatMode.code
          ? 'code'
          : 'symbol',
      symbol: _currencySettings.symbol,
      symbolPosition: _currencySettings.symbolBefore ? 'before' : 'after',
      digitSeparator: _currencySettings.digitSeparator,
      decimalPlaces: _currencySettings.decimalPlaces,
    );
  }

  Future<void> _saveChanges() async {
    final orgId = _organizationId;
    if (orgId == null) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text(
            'Organization not found. Sign out and sign in again to continue.',
          ),
        ),
      );
      return;
    }
    final companyName = _companyNameController.text.trim();
    if (companyName.isEmpty) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Company name is required.')),
      );
      return;
    }
    if (_country.trim().isEmpty) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text(AppStrings.companySettingsCountryRequired),
        ),
      );
      return;
    }
    if (_pincodeController.text.trim().isEmpty) {
      context.showTopSnackBar(
        const SnackBar(
          content: Text(AppStrings.companySettingsPincodeRequired),
        ),
      );
      return;
    }
    if (_saving) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final api = ref.read(organizationSettingsApiClientProvider);
      final updated = await api.updateSettings(
        organizationId: orgId,
        body: _buildUpdatePayload(),
        companyLogoBytes: _companyLogoBytes,
        companyLogoFileName: _pickedLogoFilename ?? 'company_logo.jpg',
      );
      if (!mounted) return;
      _applySettings(updated);
      _companyLogoBytes = null;
      _pickedLogoFilename = null;
      context.showTopSnackBar(
        const SnackBar(content: Text(AppStrings.companySettingsSaved)),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromDioException(
              e,
              genericFallback: AppStrings.apiErrorSaveCompanySettings,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: AppStrings.apiErrorSaveCompanySettings,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _addr1Controller.dispose();
    _addr2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  InputDecoration _orgFieldDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.inkStrong, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
    );
  }

  TextStyle _orgFieldTextStyle() {
    return AppFonts.bodyMedium(
      color: AppColors.inkStrong,
    ).copyWith(fontWeight: FontWeight.w500, fontSize: 15);
  }

  Widget _orgLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: AppFonts.labelMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFE53935)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _orgDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final menu = _menuWithCurrent(value, items);
    final effective = menu.contains(value) ? value : menu.first;
    return InputDecorator(
      decoration: _orgFieldDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          isDense: true,
          value: effective,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B7280),
          ),
          style: _orgFieldTextStyle(),
          dropdownColor: AppColors.white,
          items: menu
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e, style: _orgFieldTextStyle()),
                ),
              )
              .toList(),
          onChanged: _saving ? null : onChanged,
        ),
      ),
    );
  }

  Future<void> _openChangeHomeCurrency() async {
    final picked = await Navigator.of(context).push<HomeCurrencySettings>(
      MaterialPageRoute<HomeCurrencySettings>(
        builder: (context) => _ChangeHomeCurrencyPage(
          initial: _currencySettings,
          options: _homeCurrencyOptions,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _currencySettings = picked);
    }
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

  Widget _sectionHeader(String uppercaseTitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 20,
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
              letterSpacing: 1.0,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _companyLogoImageProvider() {
    if (_companyLogoBytes != null) {
      return MemoryImage(_companyLogoBytes!);
    }
    final url = _companyLogoUrl;
    if (url != null && url.isNotEmpty) return NetworkImage(url);
    return null;
  }

  String _logoPickErrorMessage(Object e) {
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

  Future<void> _pickCompanyLogo(ImageSource source) async {
    if (_logoPickInFlight || _saving || !mounted) return;
    setState(() => _logoPickInFlight = true);
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
        _companyLogoBytes = bytes;
        _pickedLogoFilename = name.isEmpty ? 'company_logo.jpg' : name;
      });
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(content: Text(_logoPickErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _logoPickInFlight = false);
    }
  }

  void _showCompanyLogoOptionsSheet() {
    if (_saving) return;
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
                        'Company logo',
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
                      await _pickCompanyLogo(ImageSource.camera);
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
                      await _pickCompanyLogo(ImageSource.gallery);
                    },
                  ),
                  if (_companyLogoBytes != null ||
                      (_companyLogoUrl?.isNotEmpty ?? false))
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
                        'Remove logo',
                        style: AppFonts.bodyLarge(
                          color: const Color(0xFFE53935),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _companyLogoBytes = null;
                          _pickedLogoFilename = null;
                          _companyLogoUrl = null;
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

  Widget _profilePhotoPicker() {
    final logo = _companyLogoImageProvider();
    final hasLogo = logo != null;

    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DottedBorder(
                  options: RoundedRectDottedBorderOptions(
                    radius: const Radius.circular(66),
                    strokeWidth: 1.8,
                    color: const Color(0xFFD1D5DB),
                    dashPattern: const [5, 4],
                  ),
                  child: SizedBox(
                    width: 124,
                    height: 124,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF5F6F8),
                          ),
                          child: hasLogo
                              ? ClipOval(
                                  child: Image(
                                    image: logo,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        Icon(
                                          Icons.business_rounded,
                                          size: 46,
                                          color: AppColors.mutedLight,
                                        ),
                                  ),
                                )
                              : Icon(
                                  Icons.business_rounded,
                                  size: 46,
                                  color: AppColors.mutedLight,
                                ),
                        ),
                        if (_logoPickInFlight)
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
                ),
                Positioned(
                  right: 6,
                  bottom: 8,
                  child: Material(
                    color: const Color(0xFF111827),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _saving || _logoPickInFlight
                          ? null
                          : _showCompanyLogoOptionsSheet,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.photo_camera_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _saving || _logoPickInFlight
                ? null
                : _showCompanyLogoOptionsSheet,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                _companyLogoBytes != null
                    ? 'Logo selected â€” save to upload'
                    : 'Upload Profile Photo (Optional)',
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(
                  color: _photoCaption,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganisationDetailsTab() {
    final enabled = !_saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('COMPANY INFORMATION'),
        const SizedBox(height: 4),
        _profilePhotoPicker(),
        const SizedBox(height: 20),
        _orgLabel('Company Name'),
        AppTextField(
          controller: _companyNameController,
          hintText: '',
          enabled: enabled,
          textStyle: _orgFieldTextStyle(),
          hintStyle: const TextStyle(color: Colors.transparent, height: 0),
        ),
        const SizedBox(height: 16),
        _orgLabel('Company Size'),
        _orgDropdown(
          value: _companySize,
          items: _companySizeOptions,
          onChanged: (v) {
            if (v != null) setState(() => _companySize = v);
          },
        ),
        const SizedBox(height: 16),
        _orgLabel('Website URL'),
        AppTextField(
          controller: _websiteController,
          hintText: AppStrings.companySettingsWebsiteHint,
          keyboardType: TextInputType.url,
          enabled: enabled,
          textStyle: _orgFieldTextStyle(),
        ),
        const SizedBox(height: 16),
        _orgLabel('Timezone'),
        _orgDropdown(
          value: _timezone,
          items: _timezoneOptions,
          onChanged: (v) {
            if (v != null) setState(() => _timezone = v);
          },
        ),
        const SizedBox(height: 16),
        _orgLabel('Company Description'),
        TextField(
          controller: _descriptionController,
          enabled: enabled,
          maxLines: 5,
          minLines: 4,
          style: _orgFieldTextStyle(),
          decoration: _orgFieldDecoration().copyWith(
            hintText: AppStrings.companySettingsDescriptionHint,
            hintStyle: AppFonts.bodyMedium(
              color: _labelGrey,
            ).copyWith(fontWeight: FontWeight.w400, fontSize: 15),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 28),
        _sectionHeader('ADDRESS'),
        const SizedBox(height: 4),
        AppAddressFields(
          line1: _addr1Controller,
          line2: _addr2Controller,
          city: _cityController,
          state: _stateController,
          postalCode: _pincodeController,
          enabled: enabled,
          layout: AppAddressLayout.entityWithCountryDropdown,
          line1Hint: AppStrings.companySettingsAddress1Hint,
          line2Hint: AppStrings.companySettingsAddress2Hint,
          cityHint: AppStrings.companySettingsCityHint,
          stateHint: AppStrings.companySettingsStateHint,
          postalCodeHint: AppStrings.companySettingsPincodeHint,
          postalCodeLabel: 'Postal Code',
          textStyle: _orgFieldTextStyle(),
          countryDropdownValue: _country,
          countryDropdownOptions: _countryOptions,
          onCountryDropdownChanged: (v) => setState(() => _country = v),
          dropdownDecoration: _orgFieldDecoration(),
          dropdownValueStyle: _orgFieldTextStyle(),
          labelBuilder: (text, {required = false}) =>
              _orgLabel(text, required: required),
          onCountryResolved: (country) {
            final matched =
                matchCountryOption(country, _countryOptions) ?? country;
            setState(() {
              if (!_countryOptions.contains(matched)) {
                _countryOptions.insert(0, matched);
              }
              _country = matched;
            });
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get _currencySymbol => _currencySettings.displayUnit;

  String get _formatSample => _currencySettings.formatPreview();

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _scheduleSectionLabel(String text) {
    return Text(
      text,
      style: AppFonts.labelMedium(
        color: _labelGrey,
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.6, fontSize: 11),
    );
  }

  Widget _operationalDayChip(int index) {
    final selected = _operationalDays.contains(index);
    final label = _weekDays[index];
    return Material(
      color: selected ? _scheduleAccentBg : AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _saving
            ? null
            : () {
                setState(() {
                  if (selected) {
                    _operationalDays.remove(index);
                  } else {
                    _operationalDays.add(index);
                  }
                });
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _scheduleAccent : const Color(0xFFD1D5DB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: selected ? _scheduleAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected ? _scheduleAccent : const Color(0xFFD1D5DB),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.bodyMedium(
                    color: selected ? _scheduleAccent : _labelGrey,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleTimeField({
    required String timeText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _innerPanelBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  timeText,
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              const Icon(
                Icons.access_time_rounded,
                color: Color(0xFF6B7280),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    return _settingsCard(
      children: [
        Text(
          'Working Schedule',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          'Current Timezone: $_timezone',
          style: AppFonts.bodyMedium(
            color: _labelGrey,
          ).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: _panelBorder),
        const SizedBox(height: 18),
        _scheduleSectionLabel('OPERATIONAL DAYS'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final itemWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var i = 0; i < _weekDays.length; i++)
                  SizedBox(width: itemWidth, child: _operationalDayChip(i)),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _scheduleSectionLabel('START TIME'),
        const SizedBox(height: 8),
        _scheduleTimeField(
          timeText: _formatTime(_startTime),
          onTap: () => _pickTime(isStart: true),
        ),
        const SizedBox(height: 18),
        _scheduleSectionLabel('END TIME'),
        const SizedBox(height: 8),
        _scheduleTimeField(
          timeText: _formatTime(_endTime),
          onTap: () => _pickTime(isStart: false),
        ),
        const SizedBox(height: 18),
        _scheduleSectionLabel('BREAK DURATION'),
        const SizedBox(height: 8),
        Material(
          color: _innerPanelBg,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _breakDuration,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF6B7280),
                ),
                style: AppFonts.bodyMedium(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                dropdownColor: AppColors.white,
                items: _breakDurationOptions
                    .map(
                      (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _breakDuration = v);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _currenciesSectionTitle(String title) {
    return Text(
      title,
      style: AppFonts.bodyMedium(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
    );
  }

  Widget _buildCurrenciesTab() {
    return _settingsCard(
      children: [
        _currenciesSectionTitle('Home Currency'),
        const SizedBox(height: 12),
        Material(
          color: _innerPanelBg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _openChangeHomeCurrency,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _panelBorder),
                    ),
                    child: Text(
                      _currencySymbol,
                      style: AppFonts.titleMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currencySettings.homeCurrency,
                          style: AppFonts.bodyMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your primary currency',
                          style: AppFonts.bodySmall(
                            color: _labelGrey,
                          ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _currenciesSectionTitle('Format'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: _innerPanelBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _formatSample,
                style: AppFonts.headlineSmall(
                  color: AppColors.inkStrong,
                ).copyWith(fontWeight: FontWeight.w800, fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                'Current format',
                style: AppFonts.bodySmall(
                  color: _labelGrey,
                ).copyWith(fontWeight: FontWeight.w500, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _openChangeHomeCurrency,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.inkStrong,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Customize',
                    style: AppFonts.labelLarge(
                      color: Colors.white,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    if (_loading) {
      return const AppSkeletonScreenBody(scrollable: true, toastBlockCount: 5);
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: _labelGrey),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadCompanySettings,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return IgnorePointer(
      ignoring: _saving,
      child: TabBarView(
        controller: _tabController,
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            children: [_buildOrganisationDetailsTab()],
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            children: [_buildScheduleTab()],
          ),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            children: [_buildCurrenciesTab()],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _pageBackground,
      drawerEnableOpenDragGesture: true,
      drawer: _SettingsDrawer(
        selected: _SettingsDrawerSelection.company,
        onExit: _logoutToDashboard,
        onPersonalProfile: () => _closeDrawerPush(PersonalProfilePage.path),
        onUsers: () => _closeDrawerPush(UsersSettingsPage.path),
        onCompany: () => _scaffoldKey.currentState?.closeDrawer(),
        onPrivacy: () => _closeDrawerPush(PrivacySettingsPage.path),
        onMetadata: () => _closeDrawerPush(MetadataSettingsPage.path),
        onIntegration: () => _closeDrawerPush(IntegrationSettingsPage.path),
      ),
      appBar: AppBar(
        backgroundColor: _pageBackground,
        surfaceTintColor: _pageBackground,
        leading: IconButton(
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: AppColors.inkStrong),
        ),
        title: Text(
          'Company Settings',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        // actions: [
        //   IconButton(
        //     onPressed: _loading || _saving
        //         ? null
        //         : () {
        //             if (_tabController.index != 0) {
        //               _tabController.animateTo(0);
        //             }
        //           },
        //     icon: const Icon(
        //       Icons.edit_outlined,
        //       color: AppColors.inkStrong,
        //     ),
        //     tooltip: 'Edit organisation details',
        //   ),
        // ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
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
                  Tab(text: 'Organisation Details'),
                  Tab(text: 'Schedule'),
                  Tab(text: 'Currencies'),
                ],
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
            ],
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildTabContent()),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _panelBorder)),
              ),
              padding: EdgeInsets.fromLTRB(
                14,
                10,
                14,
                MediaQuery.of(context).padding.bottom + 10,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading || _saving || _loadError != null
                      ? null
                      : _saveChanges,
                  style: FilledButton.styleFrom(
                    backgroundColor: _saveButtonColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _saveButtonColor.withValues(
                      alpha: 0.45,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: AppFonts.labelLarge(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.w700),
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

