import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/settings/password_updated_page.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  static const path = '/settings/change-password';
  static const name = 'settings-change-password';

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;
  bool _isSubmitting = false;

  static const _strongFieldBorder = Color(0xFFE5E7EB);
  static const _hintGrey = Color(0xFFB0B0B3);

  @override
  void initState() {
    super.initState();
    _next.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _hasMinLength(String v) => v.length >= 8;
  bool _hasUpper(String v) => v.contains(RegExp(r'[A-Z]'));
  bool _hasLower(String v) => v.contains(RegExp(r'[a-z]'));
  bool _hasDigit(String v) => v.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String v) => v.contains(RegExp(r'[!@#$%^&*]'));

  bool get _allRequirementsMet {
    final v = _next.text;
    return _hasMinLength(v) &&
        _hasUpper(v) &&
        _hasLower(v) &&
        _hasDigit(v) &&
        _hasSpecial(v);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_allRequirementsMet) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Password does not meet all requirements')),
      );
      return;
    }
    if (_next.text != _confirm.text) {
      context.showTopSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    // No change-password endpoint wired yet — simulate success.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    context.go(PasswordUpdatedPage.path);
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppFonts.labelMedium(color: const Color(0xFF9CA3AF)).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        fontSize: 11,
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required bool show,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      enabled: !_isSubmitting,
      validator: validator,
      style: AppFonts.bodyLarge(
        color: AppColors.inkStrong,
      ).copyWith(fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 2),
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle: AppFonts.bodyLarge(
          color: _hintGrey,
        ).copyWith(fontSize: 16, letterSpacing: 2),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _strongFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _strongFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6B7280)),
        ),
        suffixIcon: IconButton(
          onPressed: _isSubmitting ? null : onToggle,
          icon: Icon(
            show ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: const Color(0xFF6B7280),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _requirement(String label, bool satisfied) {
    final color = satisfied
        ? const Color(0xFF16A34A)
        : const Color(0xFF9CA3AF);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            satisfied
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppFonts.bodyMedium(
                color: satisfied
                    ? AppColors.inkStrong
                    : const Color(0xFF6B7280),
              ).copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _next.text;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: _isSubmitting ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Change Password',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E2E4)),
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
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  children: [
                    _label('CURRENT PASSWORD'),
                    const SizedBox(height: 8),
                    _passwordField(
                      controller: _current,
                      show: _showCurrent,
                      onToggle: () =>
                          setState(() => _showCurrent = !_showCurrent),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Current password is required'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _label('NEW PASSWORD'),
                    const SizedBox(height: 8),
                    _passwordField(
                      controller: _next,
                      show: _showNext,
                      onToggle: () => setState(() => _showNext = !_showNext),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'New password is required'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    _label('CONFIRM NEW PASSWORD'),
                    const SizedBox(height: 8),
                    _passwordField(
                      controller: _confirm,
                      show: _showConfirm,
                      onToggle: () =>
                          setState(() => _showConfirm = !_showConfirm),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) {
                          return 'Please confirm the new password';
                        }
                        if (v != _next.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PASSWORD REQUIREMENTS',
                            style: AppFonts.labelMedium(
                              color: const Color(0xFF6B7280),
                            ).copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _requirement(
                            'At least 8 characters',
                            _hasMinLength(value),
                          ),
                          _requirement(
                            'At least one uppercase letter (A-Z)',
                            _hasUpper(value),
                          ),
                          _requirement(
                            'At least one lowercase letter (a-z)',
                            _hasLower(value),
                          ),
                          _requirement(
                            'At least one number (0-9)',
                            _hasDigit(value),
                          ),
                          _requirement(
                            'At least one special character (!@#\$%^&*)',
                            _hasSpecial(value),
                          ),
                        ],
                      ),
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
                      disabledBackgroundColor:
                          const Color(0xFF111111).withValues(alpha: 0.45),
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
                            'Update Password',
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
