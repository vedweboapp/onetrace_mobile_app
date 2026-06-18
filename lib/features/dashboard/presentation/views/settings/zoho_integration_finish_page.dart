import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/data/zoho_integration_models.dart';
import 'package:red5/features/dashboard/data/zoho_integration_prefs.dart';

/// Post-OAuth setup: pull historical data, key mapping, webhook details.
class ZohoIntegrationFinishPage extends ConsumerStatefulWidget {
  const ZohoIntegrationFinishPage({super.key, required this.connectionId});

  static const pathPrefix = '/settings/integration/zoho/finish';
  static const name = 'settings-integration-zoho-finish';

  static String pathFor(int connectionId) =>
      '$pathPrefix/$connectionId';

  final int connectionId;

  @override
  ConsumerState<ZohoIntegrationFinishPage> createState() =>
      _ZohoIntegrationFinishPageState();
}

class _ZohoIntegrationFinishPageState
    extends ConsumerState<ZohoIntegrationFinishPage> {
  static const _pageBg = Color(0xFFF3F4F6);

  static const _defaultMappings = <ZohoKeyMappingField>[
    ZohoKeyMappingField(
      zohoField: 'contact_name',
      red5Field: 'name',
      label: 'Contact name',
    ),
    ZohoKeyMappingField(
      zohoField: 'email',
      red5Field: 'email',
      label: 'Email',
    ),
    ZohoKeyMappingField(
      zohoField: 'phone',
      red5Field: 'phone',
      label: 'Phone',
    ),
  ];

  bool _submitting = false;
  bool _pullHistoricalData = true;
  late final List<ZohoKeyMappingField> _mappings;
  late final Map<String, TextEditingController> _mappingControllers;

  @override
  void initState() {
    super.initState();
    _mappings = List<ZohoKeyMappingField>.from(_defaultMappings);
    _mappingControllers = {
      for (final field in _mappings)
        field.zohoField: TextEditingController(text: field.red5Field),
    };
  }

  @override
  void dispose() {
    for (final c in _mappingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _finishIntegration() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ZohoIntegrationPrefs.saveCompletedConnection(
        connectionId: widget.connectionId,
        pullHistoricalData: _pullHistoricalData,
      );
      if (!mounted) return;
      context.showAppTopToast(
        title: 'Zoho integration finished',
        type: AppTopToastType.success,
      );
      context.pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pullHistoricalCard() {
    return _sectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pull historical data',
                  style: AppFonts.titleMedium(color: AppColors.inkStrong)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Import existing records from Zoho Inventory when the connection is created.',
                  style: AppFonts.bodySmall(color: const Color(0xFF6B7280))
                      .copyWith(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          Switch(
            value: _pullHistoricalData,
            onChanged: _submitting
                ? null
                : (value) => setState(() => _pullHistoricalData = value),
            activeTrackColor: const Color(0xFF111111),
          ),
        ],
      ),
    );
  }

  Widget _keyMappingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key mapping',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Map incoming Zoho Inventory fields to Red5 fields.',
          style: AppFonts.bodySmall(color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        for (final field in _mappings) ...[
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label ?? field.zohoField,
                  style: AppFonts.labelMedium(color: AppColors.inkStrong)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Zoho: ${field.zohoField}',
                  style: AppFonts.bodySmall(color: const Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: _mappingControllers[field.zohoField]!,
                  hintText: 'Red5 field',
                  enabled: !_submitting,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _webhooksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom webhooks',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create a custom webhook in Zoho Inventory using your Red5 callback URL after setup is complete.',
          style: AppFonts.bodySmall(color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          child: Text(
            'In Zoho Inventory go to Settings → Automation → Webhooks, then add your Red5 integration callback URL and subscribe to item, contact, and invoice events.',
            style: AppFonts.bodyMedium(color: AppColors.inkStrong),
          ),
        ),
      ],
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
          onPressed: _submitting ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Finish Zoho setup',
          style: AppFonts.titleMedium(color: AppColors.inkStrong).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                        Text(
                          'Finish Zoho Inventory setup',
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose whether to import existing Zoho data, map incoming fields, then complete the connection.',
                          style: AppFonts.bodyMedium(
                            color: const Color(0xFF6B7280),
                          ).copyWith(fontSize: 14, height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        _pullHistoricalCard(),
                        const SizedBox(height: 24),
                        _keyMappingSection(),
                        const SizedBox(height: 24),
                        _webhooksSection(),
                      ],
                    ),
            ),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _submitting ? null : () => context.pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _submitting ? null : _finishIntegration,
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
                              : const Text('Finish integration'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
