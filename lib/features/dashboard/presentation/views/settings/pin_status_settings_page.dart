import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_status_screen_widgets.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';
import 'package:red5/features/dashboard/presentation/widgets/pin_status_delete_dialog.dart';
import 'package:red5/features/dashboard/presentation/widgets/pin_status_form_sheet.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

/// Meta data → Pin Status (`GET/POST /api/v1/pin-status/`, `PUT/DELETE …/{id}/`).
class PinStatusSettingsPage extends ConsumerStatefulWidget {
  const PinStatusSettingsPage({super.key});

  static const path = '/settings/metadata/pin-status';
  static const name = 'settings-pin-status';

  @override
  ConsumerState<PinStatusSettingsPage> createState() =>
      _PinStatusSettingsPageState();
}

class _PinStatusSettingsPageState extends ConsumerState<PinStatusSettingsPage> {
  List<PinStatusItem>? _items;
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
      final api = ref.read(quoteProjectApiClientProvider);
      final list = await api.fetchPinStatuses();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Failed to load pin statuses',
        );
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    context.showTopSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDelete(PinStatusItem item) async {
    final request = await showPinStatusDeleteDialog(
      context: context,
      item: item,
      allStatuses: _items ?? const [],
    );
    if (request == null || !mounted) return;
    try {
      await ref
          .read(quoteProjectApiClientProvider)
          .deletePinStatus(item.id, moveToStatusId: request.moveToStatusId);
      if (!mounted) return;
      _toast('Status deleted');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(
        ApiResponseMessage.fromAnyError(e, genericFallback: 'Delete failed'),
      );
    }
  }

  void _openActions(PinStatusItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _showStatusEditorSheet(editing: item);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Color(0xFFB91C1C),
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFB91C1C)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusEditorSheet({PinStatusItem? editing}) async {
    await showPinStatusFormSheet(
      context: context,
      ref: ref,
      editing: editing,
      onSaved: (_) => _load(),
      onMessage: _toast,
    );
  }

  Widget _buildMainContent() {
    if (_loading && (_items == null || _items!.isEmpty)) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_items != null && _items!.isEmpty) {
      return const MetadataStatusEmptyState(
        description:
            'Create your first pin status to start organizing your system metadata.',
      );
    }

    if (_items != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: _PinStatusListCard(items: _items!, onMore: _openActions),
      );
    }

    return const SizedBox.shrink();
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
          'Pin Status',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          SettingsToolbarAvatar(
            onTap: () => context.push(PersonalProfilePage.path),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      bottomNavigationBar: MetadataStatusAddButton(
        onPressed: () => _showStatusEditorSheet(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MetadataStatusSectionLabel(),
            Expanded(child: _buildMainContent()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  style: AppFonts.bodyMedium(color: const Color(0xFFB91C1C)),
                ),
              ),
            const MetadataVisibilityInfoCard(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PinStatusListCard extends StatelessWidget {
  const _PinStatusListCard({required this.items, required this.onMore});

  final List<PinStatusItem> items;
  final void Function(PinStatusItem) onMore;

  Color _dotColor(PinStatusItem s) =>
      parseHexColor(s.bgColour) ?? AppColors.plotPinBlue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Color(0xFFE5E7EB)),
              _PinStatusRow(
                item: items[i],
                dotColor: _dotColor(items[i]),
                onMore: () => onMore(items[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PinStatusRow extends StatelessWidget {
  const _PinStatusRow({
    required this.item,
    required this.dotColor,
    required this.onMore,
  });

  final PinStatusItem item;
  final Color dotColor;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onMore,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.statusName,
                  style: AppFonts.bodyLarge(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 22,
                ),
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
