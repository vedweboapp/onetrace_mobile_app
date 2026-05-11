import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/sites/data/site_models.dart';
import 'package:red5/features/sites/data/sites_api_client.dart';

class AddSitePage extends ConsumerStatefulWidget {
  const AddSitePage({super.key, this.existing});

  /// When non-null the form opens in edit mode pre-filled with [existing] and
  /// submits a `PATCH /item/{id}/` instead of a `POST /item/`.
  final SiteModel? existing;

  static const path = '/sites/add';
  static const name = 'add-site';

  @override
  ConsumerState<AddSitePage> createState() => _AddSitePageState();
}

class _AddSitePageState extends ConsumerState<AddSitePage> {
  final _formKey = GlobalKey<FormState>();

  final _siteName = TextEditingController();
  final _clientName = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();

  String _country = 'United States';
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  static const _countries = <String>[
    'United States',
    'India',
    'United Kingdom',
    'Canada',
    'Australia',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _siteName.text = existing.siteName;
      _clientName.text = existing.clientName;
      _address1.text = existing.addressLine1;
      _address2.text = existing.addressLine2;
      _city.text = existing.city;
      _state.text = existing.state;
      _postalCode.text = existing.postalCode;
      final country = existing.country.trim();
      if (country.isNotEmpty) {
        _country = _countries.contains(country) ? country : _countries.first;
      }
    }
  }

  @override
  void dispose() {
    _siteName.dispose();
    _clientName.dispose();
    _address1.dispose();
    _address2.dispose();
    _city.dispose();
    _state.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  String? Function(String?) _requiredField(String fieldName) {
    return (value) {
      if ((value ?? '').trim().isEmpty) return '$fieldName is required';
      return null;
    };
  }

  String? _postalCodeValidator(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Postal Code is required';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(sitesApiClientProvider);
      final existing = widget.existing;
      final saved = existing == null
          ? await api.createSite(
              siteName: _siteName.text.trim(),
              clientName: _clientName.text.trim(),
              addressLine1: _address1.text.trim(),
              addressLine2: _address2.text.trim(),
              country: _country.trim(),
              city: _city.text.trim(),
              state: _state.text.trim(),
              postalCode: _postalCode.text.trim(),
            )
          : await api.updateSite(
              id: existing.id,
              siteName: _siteName.text.trim(),
              clientName: _clientName.text.trim(),
              addressLine1: _address1.text.trim(),
              addressLine2: _address2.text.trim(),
              country: _country.trim(),
              city: _city.text.trim(),
              state: _state.text.trim(),
              postalCode: _postalCode.text.trim(),
            );
      if (!mounted) return;
      context.pop<SiteModel>(saved);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: _isEditing
                  ? 'Failed to update site'
                  : 'Failed to create site',
            ),
          ),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: AppFonts.labelMedium(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
        ],
      ),
      style: AppFonts.bodySmall(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w700, fontSize: 13),
    );
  }

  InputDecoration _dropdownDecoration() {
    return const InputDecoration(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: _isSubmitting ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          _isEditing ? 'Edit Sites' : 'Add Sites',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.inkStrong.withValues(alpha: 0.08),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  children: [
                    _sectionLabel('Basic Info'),
                    _label('Site Name', required: true),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _siteName,
                      hintText: 'e.g. Apex Structural Group',
                      validator: _requiredField('Site Name'),
                    ),
                    const SizedBox(height: 14),
                    _label('Client Name', required: true),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _clientName,
                      hintText: 'e.g. Apex Structural Group',
                      validator: _requiredField('Client Name'),
                    ),
                    _sectionLabel('Address'),
                    _label('Address Line 1'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _address1,
                      hintText: 'Street address',
                    ),
                    const SizedBox(height: 14),
                    _label('Address Line 2'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _address2,
                      hintText: 'Suite, unit, etc. (optional)',
                    ),
                    const SizedBox(height: 14),
                    _label('Country', required: true),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _country,
                      items: _countries
                          .map(
                            (country) => DropdownMenuItem<String>(
                              value: country,
                              child: Text(country),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) =>
                                setState(() => _country = value ?? _country),
                      decoration: _dropdownDecoration(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('City'),
                              const SizedBox(height: 8),
                              AppTextField(
                                controller: _city,
                                hintText: 'e.g. New York',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('State / Province'),
                              const SizedBox(height: 8),
                              AppTextField(
                                controller: _state,
                                hintText: 'e.g. NY',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _label('Postal Code', required: true),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _postalCode,
                      hintText: 'ZIP or Postal Code',
                      validator: _postalCodeValidator,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: const Color(
                        0xFF111111,
                      ).withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.white,
                            ),
                          )
                        : Text(
                            _isEditing ? 'Save' : 'Create',
                            style: AppFonts.titleMedium(color: AppColors.white)
                                .copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
