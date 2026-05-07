import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/clients/data/client_models.dart';
import 'package:red5/features/clients/data/clients_api_client.dart';

class AddClientPage extends ConsumerStatefulWidget {
  const AddClientPage({super.key});

  static const path = '/clients/add';
  static const name = 'add-client';

  @override
  ConsumerState<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends ConsumerState<AddClientPage> {
  final _formKey = GlobalKey<FormState>();

  final _clientName = TextEditingController();
  final _contactPerson = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postalCode = TextEditingController();

  String _country = 'United States';
  bool _isSubmitting = false;

  static const _countries = <String>[
    'United States',
    'India',
    'United Kingdom',
    'Canada',
    'Australia',
  ];

  @override
  void dispose() {
    _clientName.dispose();
    _contactPerson.dispose();
    _email.dispose();
    _phone.dispose();
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
  String? _phoneValidator(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Phone is required';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) return 'Phone number must be exactly 10 digits';
    return null;
  }

  String? _postalCodeValidator(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Postal Code is required';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 5 || digits.length > 6) {
      return 'Postal Code must be 5 or 6 digits';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(clientsApiClientProvider);
      final created = await api.createClient(
        name: _clientName.text.trim(),
        contactPerson: _contactPerson.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        addressLine1: _address1.text.trim(),
        addressLine2: _address2.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        country: _country.trim(),
        pincode: _postalCode.text.trim(),
      );
      if (!mounted) return;
      context.pop<ClientModel>(created);
    } catch (e) {
      if (!mounted) return;
      context.showTopSnackBar(
        SnackBar(
          content: Text(
            ApiResponseMessage.fromAnyError(
              e,
              genericFallback: 'Failed to create client',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSubmitting = false);
      return;
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
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Add Client',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            children: [
              _sectionLabel('Basic Info'),
              Text(
                'Client Name *',
                style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _clientName,
                hintText: 'e.g. Apex Structural Group',
                validator: _requiredField('Client Name'),
              ),
              _sectionLabel('Primary Contact'),
              Text(
                'Contact Person',
                style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _contactPerson,
                hintText: 'Full name',
              ),
              const SizedBox(height: 12),
              Text(
                'Email *',
                style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _email,
                hintText: 'email@company.com',
                validator: _requiredField('Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              Text(
                'Phone *',
                style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _phone,
                hintText: '+1 (555) 000-0000',
                validator: _phoneValidator,
                keyboardType: TextInputType.number,
              ),
              _sectionLabel('Address'),
              Text(
                'Address Line 1',
                style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _address1,
                hintText: 'Street address',
              ),
              const SizedBox(height: 12),
              Text(
                'Address Line 2',
                style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _address2,
                hintText: 'Suite, unit, etc. (optional)',
              ),
              const SizedBox(height: 12),
              Text(
                'Country *',
                style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _country,
                items: _countries
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _country = v ?? _country),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'City',
                          style: AppFonts.bodySmall(color: AppColors.inkStrong)
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
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
                        Text(
                          'State / Province',
                          style: AppFonts.bodySmall(color: AppColors.inkStrong)
                              .copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
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
              const SizedBox(height: 12),
              Text(
                'Postal Code *',
                style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              AppTextField(
                controller: _postalCode,
                hintText: 'ZIP or Postal Code',
                validator: _postalCodeValidator,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: AppColors.white,
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
                          'Create',
                          style: AppFonts.titleMedium(color: AppColors.white)
                              .copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
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

