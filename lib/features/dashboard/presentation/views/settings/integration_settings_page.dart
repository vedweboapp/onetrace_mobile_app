import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/features/dashboard/presentation/views/settings/zoho_integration_page.dart';

/// Hub for third-party integrations (Zoho, etc.).
class IntegrationSettingsPage extends StatefulWidget {
  const IntegrationSettingsPage({super.key});

  static const path = '/settings/integration';
  static const name = 'settings-integration';

  @override
  State<IntegrationSettingsPage> createState() =>
      _IntegrationSettingsPageState();
}

class _IntegrationSettingsPageState extends State<IntegrationSettingsPage> {
  DateTime? _zohoLastConnected;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ZohoIntegrationPage.prefsKeyLastConnectedIso);
    DateTime? dt;
    if (raw != null && raw.trim().isNotEmpty) {
      dt = DateTime.tryParse(raw.trim());
    }
    if (!mounted) return;
    setState(() => _zohoLastConnected = dt);
  }

  String _subtitleForZoho() {
    final d = _zohoLastConnected;
    if (d == null) return 'Tap to connect';
    return DateFormat('MMM d, yyyy • h:mm a', 'en_US').format(d).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Integration',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            'INTEGRATION',
            style: AppFonts.labelMedium(color: const Color(0xFF9E9E9E)).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 14),
          Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () async {
                await context.push(ZohoIntegrationPage.path);
                await _loadPrefs();
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const _ZohoLogoBadge(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zoho',
                            style: AppFonts.titleMedium(
                              color: AppColors.inkStrong,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subtitleForZoho(),
                            style: AppFonts.bodySmall(
                              color: const Color(0xFF9E9E9E),
                            ).copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZohoLogoBadge extends StatelessWidget {
  const _ZohoLogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Z',
              style: TextStyle(
                color: const Color(0xFF00A651),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                height: 1,
              ),
            ),
            Text(
              'o',
              style: TextStyle(
                color: const Color(0xFFE42527),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                height: 1,
              ),
            ),
            Text(
              'h',
              style: TextStyle(
                color: const Color(0xFFFFC107),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                height: 1,
              ),
            ),
            Text(
              'o',
              style: TextStyle(
                color: const Color(0xFF0098D4),
                fontWeight: FontWeight.w900,
                fontSize: 13,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
