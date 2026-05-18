import 'dart:math' as math;

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/providers/local_storage_provider.dart';
import 'package:red5/core/storage/local_storage.dart';
import 'package:red5/core/storage/local_storage_keys.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/features/dashboard/data/organization_settings_api_client.dart';
import 'package:red5/features/dashboard/data/organization_settings_models.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/dashboard/presentation/views/dashboard_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/integration_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/privacy_settings_page.dart';
import 'package:red5/features/dashboard/presentation/views/settings/users_settings_page.dart';

class CompanySettingsPage extends ConsumerStatefulWidget {
  const CompanySettingsPage({super.key});

  static const path = '/settings/company';
  static const name = 'settings-company';

  @override
  ConsumerState<CompanySettingsPage> createState() =>
      _CompanySettingsPageState();
}

enum CurrencyFormatMode { symbol, code }

/// Home currency + display format (Change Home Currency screen).
class HomeCurrencySettings {
  const HomeCurrencySettings({
    required this.homeCurrency,
    this.formatMode = CurrencyFormatMode.symbol,
    this.symbol = '₹',
    this.symbolPosition = 'Before Value',
    this.digitSeparator = '12,34,567.89',
    this.decimalPlaces = 2,
  });

  final String homeCurrency;
  final CurrencyFormatMode formatMode;
  final String symbol;
  final String symbolPosition;
  final String digitSeparator;
  final int decimalPlaces;

  factory HomeCurrencySettings.defaults() {
    return const HomeCurrencySettings(homeCurrency: 'Indian Rupee - INR');
  }

  String get currencyCode {
    final parts = homeCurrency.split(' - ');
    if (parts.length >= 2) return parts.last.trim();
    return 'INR';
  }

  String get displayUnit =>
      formatMode == CurrencyFormatMode.symbol ? symbol : currencyCode;

  bool get symbolBefore => symbolPosition == 'Before Value';

  String formatPreview([double value = 1234567.89]) {
    final amount = formatAmount(value);
    if (symbolBefore) return '$displayUnit $amount';
    return '$amount $displayUnit';
  }

  String formatAmount(double value) {
    final rounded =
        (value * math.pow(10, decimalPlaces)).round() /
        math.pow(10, decimalPlaces);
    final fixed = rounded.toStringAsFixed(decimalPlaces);
    final parts = fixed.split('.');
    final grouped = _groupInteger(int.parse(parts[0]), digitSeparator);
    if (decimalPlaces == 0) return grouped;
    final decSep = digitSeparator.contains(',') &&
            digitSeparator.indexOf(',') > digitSeparator.indexOf('.')
        ? ','
        : '.';
    return '$grouped$decSep${parts[1]}';
  }

  static String defaultSymbolFor(String homeCurrency) {
    if (homeCurrency.contains('INR')) return '₹';
    if (homeCurrency.contains('USD')) return '\$';
    if (homeCurrency.contains('EUR')) return '€';
    if (homeCurrency.contains('GBP')) return '£';
    return '₹';
  }

  static String defaultSeparatorFor(String homeCurrency) {
    if (homeCurrency.contains('INR')) return '12,34,567.89';
    if (homeCurrency.contains('EUR')) return '1.234.567,89';
    return '1,234,567.89';
  }

  static String _groupInteger(int value, String pattern) {
    if (pattern.startsWith('12,34')) {
      return _indianGrouping(value);
    }
    if (pattern.contains('.') && pattern.contains(',')) {
      return _europeanGrouping(value);
    }
    return _usGrouping(value);
  }

  static String _indianGrouping(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final chunks = <String>[];
    while (rest.length > 2) {
      chunks.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) chunks.insert(0, rest);
    return '${chunks.join(',')},$last3';
  }

  static String _usGrouping(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      if (count == 3) {
        buf.write(',');
        count = 0;
      }
      buf.write(s[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }

  static String _europeanGrouping(int n) => _usGrouping(n).replaceAll(',', '.');
}

enum _AppearanceMode { light, dark }

enum _NavigationStyle { sidebar, bottomBar }

class _CompanySettingsPageState extends ConsumerState<CompanySettingsPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TabController _tabController;
  final _companyNameController = TextEditingController();

  HomeCurrencySettings _currencySettings = HomeCurrencySettings.defaults();
  String? _companyLogoUrl;
  String _timezone = 'GMT+0';
  bool _loading = true;
  String? _loadError;

  static const _homeCurrencyOptions = <String>[
    'Indian Rupee - INR',
    'US Dollar - USD',
    'Euro - EUR',
    'British Pound - GBP',
  ];

  static const _weekDays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

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

  _AppearanceMode _appearanceMode = _AppearanceMode.light;
  _NavigationStyle _navigationStyle = _NavigationStyle.sidebar;
  int _selectedBrandColor = 0;
  Color? _customBrandColor;

  static const _pageBackground = Color(0xFFF3F4F6);
  static const _panelBorder = Color(0xFFE5E7EB);
  static const _labelGrey = Color(0xFF6B7280);
  static const _photoCaption = Color(0xFF6B8FA8);

  static const _brandPalette = <Color>[
    Color(0xFF000000), // #000000
    Color(0xFFF97316), // #F97316
    Color(0xFF2563EB), // #2563EB
    Color(0xFF059669), // #059669
    Color(0xFF4B5563), // #4B5563
  ];
  static const _customSheetPalette = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFF59E0B),
    Color(0xFFEA580C),
    Color(0xFFE11D48),
    Color(0xFF1E293B),
    Color(0xFF38BDF8),
    Color(0xFF84CC16),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCompanySettings());
  }

  int? _resolveOrganizationId(LocalStorage storage) {
    final stored = storage.getInt(LocalStorageKeys.authOrganizationId);
    if (stored != null) return stored;
    final raw = storage.getString(LocalStorageKeys.authOrganizationId)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _loadCompanySettings() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final orgId = _resolveOrganizationId(ref.read(localStorageProvider));
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
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    for (final option in _breakDurationOptions) {
      if (option.toLowerCase() == lower) return option;
    }
    final digits = int.tryParse(trimmed.replaceAll(RegExp(r'[^0-9]'), ''));
    if (digits != null) {
      final match = _breakDurationOptions.where(
        (o) => o.startsWith('$digits '),
      );
      if (match.isNotEmpty) return match.first;
      return '$digits minutes';
    }
    return null;
  }

  void _applySettings(OrganizationSettingsModel settings) {
    _companyNameController.text = settings.companyName;
    _companyLogoUrl =
        settings.companyLogo.isNotEmpty ? settings.companyLogo : null;

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
        ? settings.digitSeparator
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

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    super.dispose();
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

  Widget _profilePhotoPicker() {
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
                  child: Container(
                    width: 124,
                    height: 124,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF5F6F8),
                    ),
                    child: _companyLogoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              _companyLogoUrl!,
                              width: 124,
                              height: 124,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
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
                      onTap: () {},
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
          Text(
            'Company Logo',
            style: AppFonts.bodyMedium(
              color: _photoCaption,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _appearanceToggle() {
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
              icon: Icons.wb_sunny_rounded,
              label: 'Light',
              selected: _appearanceMode == _AppearanceMode.light,
              selectedColor: _brandPalette[1],
              selectedBg: selectedBg,
              onTap: () =>
                  setState(() => _appearanceMode = _AppearanceMode.light),
            ),
          ),
          Expanded(
            child: _AppearanceButton(
              icon: Icons.nightlight_round,
              label: 'Dark',
              selected: _appearanceMode == _AppearanceMode.dark,
              selectedColor: _brandPalette[4],
              selectedBg: selectedBg,
              onTap: () =>
                  setState(() => _appearanceMode = _AppearanceMode.dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandColorRow() {
    return Row(
      children: [
        for (var i = 0; i < _brandPalette.length; i++)
          Padding(
            padding: EdgeInsets.only(
              right: i == _brandPalette.length - 1 ? 0 : 10,
            ),
            child: InkWell(
              onTap: () => setState(() => _selectedBrandColor = i),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _brandPalette[i],
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
        if (_customBrandColor != null) ...[
          const SizedBox(width: 10),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _customBrandColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        InkWell(
          onTap: _showBrandColorBottomSheet,
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

  String _hexOf(Color color) {
    final hex = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${hex.substring(2)}';
  }

  void _showBrandColorBottomSheet() {
    final initialColor = _brandPalette[_selectedBrandColor];
    final initialIndex = _customSheetPalette.indexWhere(
      (c) => c.value == initialColor.value,
    );
    var localIndex = initialIndex < 0 ? 0 : initialIndex;
    var selectedColor = _customSheetPalette[localIndex];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Brand Color',
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.close_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: selectedColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _hexOf(selectedColor),
                            style: AppFonts.bodyMedium(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            'CUSTOM',
                            style:
                                AppFonts.labelSmall(
                                  color: const Color(0xFF2563EB),
                                ).copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < _customSheetPalette.length; i++)
                          InkWell(
                            onTap: () {
                              setBottomState(() {
                                localIndex = i;
                                selectedColor = _customSheetPalette[i];
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _customSheetPalette[i],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: i == localIndex
                                      ? const Color(0xFF93C5FD)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: i == localIndex
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          final color = _customSheetPalette[localIndex];
                          setState(() {
                            final existingIndex = _brandPalette.indexWhere(
                              (c) => c.value == color.value,
                            );
                            if (existingIndex >= 0) {
                              _selectedBrandColor = existingIndex;
                              _customBrandColor = null;
                            } else {
                              _customBrandColor = color;
                            }
                          });
                          Navigator.of(ctx).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Apply Color',
                          style: AppFonts.labelLarge(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrganisationDetailsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('COMPANY INFORMATION'),
        const SizedBox(height: 4),
        _profilePhotoPicker(),
        const SizedBox(height: 20),
        _smallHeading('Company Name'),
        AppTextField(
          controller: _companyNameController,
          hintText: '',
          textStyle: AppFonts.bodyLarge(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w500),
          hintStyle: const TextStyle(color: Colors.transparent, height: 0),
        ),
        const SizedBox(height: 22),
        const Divider(color: _panelBorder, height: 1),
        const SizedBox(height: 14),
        _sectionHeader('VISUAL THEME'),
        _smallHeading('Appearance'),
        _appearanceToggle(),
        const SizedBox(height: 18),
        _smallHeading('Brand Color'),
        _brandColorRow(),
        const SizedBox(height: 22),
        const Divider(color: _panelBorder, height: 1),
        const SizedBox(height: 14),
        _sectionHeader('PLATFORM LAYOUT'),
        _smallHeading('Navigation Style'),
        _NavigationTile(
          selected: _navigationStyle == _NavigationStyle.sidebar,
          title: 'Sidebar Navigation',
          subtitle: 'Traditional vertical menu',
          icon: Icons.apps_rounded,
          onTap: () =>
              setState(() => _navigationStyle = _NavigationStyle.sidebar),
        ),
        const SizedBox(height: 12),
        _NavigationTile(
          selected: _navigationStyle == _NavigationStyle.bottomBar,
          title: 'Bottom Bar Menu',
          subtitle: 'Compact tab style for mobile',
          icon: Icons.space_dashboard_rounded,
          onTap: () =>
              setState(() => _navigationStyle = _NavigationStyle.bottomBar),
        ),
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
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
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
      style: AppFonts.labelMedium(color: _labelGrey).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        fontSize: 11,
      ),
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
        onTap: () {
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
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
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
                  style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
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
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Current Timezone: $_timezone',
          style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
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
                  SizedBox(
                    width: itemWidth,
                    child: _operationalDayChip(i),
                  ),
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
                style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                dropdownColor: AppColors.white,
                items: _breakDurationOptions
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(e),
                      ),
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
      style: AppFonts.bodyMedium(color: AppColors.inkStrong).copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
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
                      style: AppFonts.titleMedium(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 22),
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
                          style: AppFonts.bodySmall(color: _labelGrey).copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
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
                style: AppFonts.headlineSmall(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                'Current format',
                style: AppFonts.bodySmall(color: _labelGrey).copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
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
                    style: AppFonts.labelLarge(color: Colors.white).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
      return const Center(child: CircularProgressIndicator());
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
    return TabBarView(
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
                labelStyle: AppFonts.bodyMedium(color: AppColors.inkStrong)
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                unselectedLabelStyle: AppFonts.bodyMedium(color: _labelGrey)
                    .copyWith(fontWeight: FontWeight.w500, fontSize: 15),
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
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandPalette[0],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
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

class _AppearanceButton extends StatelessWidget {
  const _AppearanceButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedBg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedBg;
  final VoidCallback onTap;

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

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.black : const Color(0xFFE5E7EB),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF6B7280), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.bodyMedium(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF6B7280),
                      ).copyWith(fontWeight: FontWeight.w500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.black : Colors.transparent,
                  border: Border.all(
                    color: selected ? Colors.black : const Color(0xFFD1D5DB),
                    width: 1.8,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.circle, size: 6, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SettingsDrawerSelection {
  personalProfile,
  users,
  company,
  privacy,
  metadata,
  integration,
}

class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({
    required this.selected,
    required this.onExit,
    required this.onPersonalProfile,
    required this.onUsers,
    required this.onCompany,
    required this.onPrivacy,
    required this.onMetadata,
    required this.onIntegration,
  });

  final _SettingsDrawerSelection selected;
  final VoidCallback onExit;
  final VoidCallback onPersonalProfile;
  final VoidCallback onUsers;
  final VoidCallback onCompany;
  final VoidCallback onPrivacy;
  final VoidCallback onMetadata;
  final VoidCallback onIntegration;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
                    onPressed: onExit,
                    icon: const Icon(
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
                    selected:
                        selected == _SettingsDrawerSelection.personalProfile,
                    onTap: onPersonalProfile,
                  ),
                  _sidebarNavTile(
                    title: 'Users',
                    iconAsset: 'assets/images/public.png',
                    selected: selected == _SettingsDrawerSelection.users,
                    onTap: onUsers,
                  ),
                  _sidebarNavTile(
                    title: 'Company Settings',
                    iconAsset: 'assets/images/company.png',
                    selected: selected == _SettingsDrawerSelection.company,
                    onTap: onCompany,
                  ),
                  _sidebarNavTile(
                    title: 'Privacy',
                    iconAsset: 'assets/images/privacy.png',
                    selected: selected == _SettingsDrawerSelection.privacy,
                    onTap: onPrivacy,
                  ),
                  _sectionLabelCaps('CUSTOMISATION'),
                  _sidebarNavTile(
                    title: 'Module and Field',
                    iconAsset: 'assets/images/database (1).png',
                    selected: selected == _SettingsDrawerSelection.metadata,
                    onTap: onMetadata,
                  ),
                  _sectionLabelCaps('INTEGRATION'),
                  _sidebarNavTile(
                    title: 'Integration',
                    iconAsset: 'assets/images/integration.png',
                    selected: selected == _SettingsDrawerSelection.integration,
                    onTap: onIntegration,
                  ),
                ],
              ),
            ),
          ],
        ),
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
}

class _ChangeHomeCurrencyPage extends StatefulWidget {
  const _ChangeHomeCurrencyPage({
    required this.initial,
    required this.options,
  });

  final HomeCurrencySettings initial;
  final List<String> options;

  @override
  State<_ChangeHomeCurrencyPage> createState() =>
      _ChangeHomeCurrencyPageState();
}

class _ChangeHomeCurrencyPageState extends State<_ChangeHomeCurrencyPage> {
  static const _labelGrey = Color(0xFF6B7280);
  static const _fieldBorder = Color(0xFFE5E7EB);
  static const _fieldFill = Color(0xFFF9FAFB);
  static const _toggleBg = Color(0xFFE5E7EB);

  static const _symbolPositions = <String>[
    'Before Value',
    'After Value',
  ];

  static const _digitSeparators = <String>[
    '12,34,567.89',
    '1,234,567.89',
    '1.234.567,89',
  ];

  late String _homeCurrency;
  late CurrencyFormatMode _formatMode;
  late String _symbolPosition;
  late String _digitSeparator;
  late final TextEditingController _symbolController;
  late final TextEditingController _decimalPlacesController;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _homeCurrency = widget.options.contains(s.homeCurrency)
        ? s.homeCurrency
        : widget.options.first;
    _formatMode = s.formatMode;
    _symbolPosition = _symbolPositions.contains(s.symbolPosition)
        ? s.symbolPosition
        : _symbolPositions.first;
    _digitSeparator = _digitSeparators.contains(s.digitSeparator)
        ? s.digitSeparator
        : _digitSeparators.first;
    _symbolController = TextEditingController(text: s.symbol);
    _decimalPlacesController =
        TextEditingController(text: s.decimalPlaces.toString());
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _decimalPlacesController.dispose();
    super.dispose();
  }

  HomeCurrencySettings get _draft => HomeCurrencySettings(
        homeCurrency: _homeCurrency,
        formatMode: _formatMode,
        symbol: _symbolController.text.trim().isEmpty
            ? HomeCurrencySettings.defaultSymbolFor(_homeCurrency)
            : _symbolController.text.trim(),
        symbolPosition: _symbolPosition,
        digitSeparator: _digitSeparator,
        decimalPlaces: int.tryParse(_decimalPlacesController.text.trim()) ?? 2,
      );

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppColors.textFieldFocusBorder,
          width: 1.2,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppFonts.bodyMedium(color: _labelGrey).copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _formatModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _toggleBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FormatModeChip(
              label: 'Symbol',
              selected: _formatMode == CurrencyFormatMode.symbol,
              onTap: () =>
                  setState(() => _formatMode = CurrencyFormatMode.symbol),
            ),
          ),
          Expanded(
            child: _FormatModeChip(
              label: 'Code',
              selected: _formatMode == CurrencyFormatMode.code,
              onTap: () => setState(() => _formatMode = CurrencyFormatMode.code),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBox() {
    return DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: const Radius.circular(12),
        strokeWidth: 1.4,
        color: const Color(0xFFD1D5DB),
        dashPattern: const [5, 4],
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: const Color(0xFFF9FAFB),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _fieldBorder),
              ),
              child: const Icon(
                Icons.visibility_outlined,
                color: Color(0xFF6B7280),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PREVIEW',
                    style: AppFonts.labelMedium(color: _labelGrey).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _draft.formatPreview(),
                    style: AppFonts.headlineSmall(color: AppColors.inkStrong)
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 24),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirm() {
    Navigator.of(context).pop(_draft);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Change Home Currency',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.inkStrong),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              children: [
                _fieldLabel('Home Currency'),
                InputDecorator(
                  decoration: _inputDecoration(),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _homeCurrency,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                      dropdownColor: AppColors.white,
                      items: widget.options
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _homeCurrency = v;
                          _symbolController.text =
                              HomeCurrencySettings.defaultSymbolFor(v);
                          _digitSeparator =
                              HomeCurrencySettings.defaultSeparatorFor(v);
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel('Format'),
                          _formatModeToggle(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel('Symbol'),
                          TextField(
                            controller: _symbolController,
                            enabled: _formatMode == CurrencyFormatMode.symbol,
                            onChanged: (_) => setState(() {}),
                            style: AppFonts.bodyMedium(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                            decoration: _inputDecoration(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _fieldLabel('Symbol Position'),
                InputDecorator(
                  decoration: _inputDecoration(),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _symbolPosition,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      style: AppFonts.bodyMedium(color: AppColors.inkStrong)
                          .copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                      items: _symbolPositions
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e,
                              child: Text(e),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _symbolPosition = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel('Digit Separators'),
                          InputDecorator(
                            decoration: _inputDecoration(),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _digitSeparator,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF6B7280),
                                  size: 20,
                                ),
                                style: AppFonts.bodyMedium(
                                  color: AppColors.inkStrong,
                                ).copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                                items: _digitSeparators
                                    .map(
                                      (e) => DropdownMenuItem<String>(
                                        value: e,
                                        child: Text(
                                          e,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _digitSeparator = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _fieldLabel('Decimal Places'),
                          TextField(
                            controller: _decimalPlacesController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            onChanged: (_) => setState(() {}),
                            style: AppFonts.bodyMedium(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                            decoration: _inputDecoration(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _previewBox(),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.inkStrong,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Confirm Changes',
                      style: AppFonts.labelLarge(color: Colors.white).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.inkStrong,
                      side: const BorderSide(color: _fieldBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppFonts.labelLarge(
                        color: AppColors.inkStrong,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatModeChip extends StatelessWidget {
  const _FormatModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: AppFonts.bodyMedium(
                color: selected ? AppColors.inkStrong : const Color(0xFF6B7280),
              ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
