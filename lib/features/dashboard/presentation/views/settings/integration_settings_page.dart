import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/zoho_integration_api_client.dart';
import 'package:red5/features/dashboard/data/zoho_integration_prefs.dart';
import 'package:red5/features/dashboard/presentation/views/settings/zoho_integration_finish_page.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hub for third-party integrations (Zoho, etc.).
class IntegrationSettingsPage extends ConsumerStatefulWidget {
  const IntegrationSettingsPage({super.key});

  static const path = '/settings/integration';
  static const name = 'settings-integration';

  @override
  ConsumerState<IntegrationSettingsPage> createState() =>
      _IntegrationSettingsPageState();
}

class _IntegrationSettingsPageState extends ConsumerState<IntegrationSettingsPage>
    with WidgetsBindingObserver {
  ZohoIntegrationPrefs _zohoPrefs = const ZohoIntegrationPrefs(
    isConnected: false,
  );
  bool _connecting = false;
  bool _awaitingOAuthReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingOAuthReturn) {
      _awaitingOAuthReturn = false;
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Authorize in browser',
        subtitle: 'When done, tap Complete setup below.',
        type: AppTopToastType.info,
      );
      _loadPrefs();
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await ZohoIntegrationPrefs.load();
    if (!mounted) return;
    setState(() => _zohoPrefs = prefs);
  }

  Future<void> _openFinishSetup(int connectionId) async {
    final finished = await context.push<bool?>(
      ZohoIntegrationFinishPage.pathFor(connectionId),
    );
    if (finished == true) {
      await _loadPrefs();
    }
  }

  Future<void> _connectZoho() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    try {
      final result =
          await ref.read(zohoIntegrationApiClientProvider).connect();
      await ZohoIntegrationPrefs.savePendingConnection(result.connectionId);
      await _loadPrefs();

      final uri = Uri.tryParse(result.authorizationUrl);
      if (uri == null) {
        throw Exception('Invalid authorization URL from server.');
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open Zoho authorization page.');
      }
      _awaitingOAuthReturn = true;
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Continue in browser',
        subtitle: 'Authorize Zoho, then return to the app to finish setup.',
        type: AppTopToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Could not start Zoho connection',
        subtitle: ApiResponseMessage.fromAnyError(e),
        type: AppTopToastType.error,
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  String _connectionDataLabel() {
    if (!_zohoPrefs.isConnected) return 'Not connected';
    final d = _zohoPrefs.lastConnected;
    if (d == null) return 'Connected';
    return DateFormat('MMM d, yyyy • h:mm a', 'en_US').format(d);
  }

  String _fetchDataLabel() {
    if (!_zohoPrefs.isConnected) return '—';
    return _zohoPrefs.pullHistoricalData ? 'On' : 'Off';
  }

  @override
  Widget build(BuildContext context) {
    final pendingId = _zohoPrefs.pendingConnectionId;
    final hasPendingSetup = pendingId != null && pendingId > 0;

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
          Container(
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ZohoLogoBadge(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zoho Inventory',
                            style: AppFonts.titleMedium(
                              color: AppColors.inkStrong,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _integrationMetaRow(
                            label: 'Connection data',
                            value: _connectionDataLabel(),
                          ),
                          const SizedBox(height: 6),
                          _integrationMetaRow(
                            label: 'Fetch data',
                            value: _fetchDataLabel(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _connecting || _zohoPrefs.isConnected
                        ? null
                        : _connectZoho,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor:
                          const Color(0xFF111111).withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _connecting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.white,
                            ),
                          )
                        : Text(
                            _zohoPrefs.isConnected
                                ? 'Connected'
                                : 'Connect Zoho Inventory',
                            style: AppFonts.titleMedium(color: AppColors.white)
                                .copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
                if (hasPendingSetup && !_zohoPrefs.isConnected) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => _openFinishSetup(pendingId),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Complete setup'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _integrationMetaRow({
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: AppFonts.bodySmall(color: const Color(0xFF9E9E9E)).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppFonts.bodySmall(color: AppColors.inkStrong).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
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
