import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/employee_role/forms/data/form_metadata_models.dart';
import 'package:red5/employee_role/forms/presentation/widgets/form_metadata_layout_widgets.dart';
import 'package:red5/features/forms/data/forms_api_client.dart';

/// Read-only form metadata preview (sections + field cards).
class FormMetadataDetailPage extends ConsumerStatefulWidget {
  const FormMetadataDetailPage({super.key, required this.formId});

  static const path = '/settings/metadata/forms/:formId';
  static const name = 'settings-form-metadata-detail';

  static String pathFor(int formId) => '/settings/metadata/forms/$formId';

  final int formId;

  @override
  ConsumerState<FormMetadataDetailPage> createState() =>
      _FormMetadataDetailPageState();
}

class _FormMetadataDetailPageState
    extends ConsumerState<FormMetadataDetailPage> {
  Map<String, dynamic>? _metadata;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final metadata = await ref
          .read(formsApiClientProvider)
          .fetchFormMetadata('${widget.formId}');
      if (!mounted) return;
      setState(() {
        _metadata = metadata;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load form metadata',
        );
      });
    }
  }

  String get _title {
    final metadata = _metadata;
    if (metadata == null) return 'Form';
    return metadata['name']?.toString().trim().isNotEmpty == true
        ? metadata['name'].toString().trim()
        : 'Form ${widget.formId}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          _title,
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppFonts.bodyMedium(color: AppColors.error),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final metadata = _metadata ?? const <String, dynamic>{};
    final sections = parseFormMetadataSections(metadata);

    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No sections or fields configured for this form.',
            textAlign: TextAlign.center,
            style: AppFonts.bodyMedium(color: AppColors.muted),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final section in sections) ...[
          FormSectionPanel(
            section: section,
            fieldBuilder: (field) => FormMetadataPreviewTile(field: field),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
