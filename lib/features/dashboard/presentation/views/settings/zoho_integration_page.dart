import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';

/// Zoho CRM OAuth-style fields (UI; wire API when backend is ready).
class ZohoIntegrationPage extends StatefulWidget {
  const ZohoIntegrationPage({super.key});

  static const path = '/settings/integration/zoho';
  static const name = 'settings-integration-zoho';

  static const prefsKeyLastConnectedIso = 'integration_zoho_last_connected_iso';

  @override
  State<ZohoIntegrationPage> createState() => _ZohoIntegrationPageState();
}

class _ZohoIntegrationPageState extends State<ZohoIntegrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _refreshToken = TextEditingController();
  final _scope = TextEditingController(text: 'ZohoCRM.modules.all');
  bool _obscureSecret = true;
  bool _submitting = false;

  static const _pageBg = Color(0xFFF3F4F6);
  static const _cardRadius = 16.0;

  static const List<String> _scopeOptions = <String>[
    'ZohoCRM.modules.all',
    'ZohoCRM.users.ALL',
    'ZohoCRM.settings.ALL',
    'ZohoCRM.coql.READ',
  ];

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    _refreshToken.dispose();
    _scope.dispose();
    super.dispose();
  }

  String? Function(String?) _required(String label) {
    return (String? v) {
      if ((v ?? '').trim().isEmpty) return '$label is required';
      return null;
    };
  }

  Future<void> _pickScope() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Text(
                  'Scope',
                  style: AppFonts.titleMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              for (final s in _scopeOptions)
                ListTile(
                  title: Text(
                    s,
                    style: AppFonts.bodyMedium(color: AppColors.inkStrong),
                  ),
                  trailing: _scope.text.trim() == s
                      ? const Icon(Icons.check, color: AppColors.inkStrong)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen != null && mounted) {
      setState(() => _scope.text = chosen);
    }
  }

  Future<void> _connect() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ZohoIntegrationPage.prefsKeyLastConnectedIso,
        DateTime.now().toUtc().toIso8601String(),
      );
      if (!mounted) return;
      context.showTopSnackBar(
        const SnackBar(
          content: Text('Zoho integration saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _fieldLabel(String text, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppFonts.labelMedium(color: const Color(0xFF6B7280))
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          if (optional)
            Text(
              'Optional',
              style: AppFonts.labelSmall(color: AppColors.muted).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
            )
          else
            Text(
              '*',
              style: AppFonts.labelMedium(color: const Color(0xFFE53935))
                  .copyWith(fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        surfaceTintColor: _pageBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Zoho Integration',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(_cardRadius),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Client ID'),
                        AppTextField(
                          controller: _clientId,
                          hintText: 'Enter your Client ID',
                          prefixIcon: Icons.person_outline_rounded,
                          validator: _required('Client ID'),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 18),
                        _fieldLabel('Client Secret'),
                        AppTextField(
                          controller: _clientSecret,
                          hintText: 'Enter your Client Secret',
                          prefixIcon: Icons.shield_outlined,
                          obscureText: _obscureSecret,
                          validator: _required('Client Secret'),
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureSecret = !_obscureSecret,
                            ),
                            icon: Icon(
                              _obscureSecret
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.muted,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _fieldLabel('Refresh Token'),
                        AppTextField(
                          controller: _refreshToken,
                          hintText: 'Paste refresh token here',
                          prefixIcon: Icons.notifications_outlined,
                          validator: _required('Refresh Token'),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 18),
                        _fieldLabel('Scope', optional: true),
                        Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: _pickScope,
                            borderRadius: BorderRadius.circular(10),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                prefixIcon: const Icon(
                                  Icons.public_rounded,
                                  color: AppColors.textFieldHint,
                                  size: 22,
                                ),
                                suffixIcon: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.muted,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.textFieldBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.textFieldBorder,
                                  ),
                                ),
                              ),
                              child: Text(
                                _scope.text.trim().isEmpty
                                    ? 'Select scope'
                                    : _scope.text.trim(),
                                style: AppFonts.bodyMedium(
                                  color: AppColors.inkStrong,
                                ).copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: _pageBg,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _submitting ? null : _connect,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.white,
                            ),
                          )
                        : Text(
                            'Connect Zoho',
                            style: AppFonts.titleMedium(
                              color: AppColors.white,
                            ).copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
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
