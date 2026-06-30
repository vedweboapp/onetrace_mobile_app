import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/core/widgets/top_snackbar.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_brand_color_sheet.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_status_screen_widgets.dart';
import 'package:red5/features/dashboard/presentation/views/settings/personal_profile_page.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

enum MetadataColourKind { projectType, installationType }

/// Settings list + CRUD for project-type or installation-type metadata APIs.
class MetadataColourTypeSettingsPage extends ConsumerStatefulWidget {
  const MetadataColourTypeSettingsPage({super.key, required this.kind});

  final MetadataColourKind kind;

  @override
  ConsumerState<MetadataColourTypeSettingsPage> createState() =>
      _MetadataColourTypeSettingsPageState();
}

class _MetadataColourTypeSettingsPageState
    extends ConsumerState<MetadataColourTypeSettingsPage> {
  List<MetadataColourItem>? _items;
  String? _error;
  bool _loading = true;

  String get _title => switch (widget.kind) {
    MetadataColourKind.projectType => 'Project Type',
    MetadataColourKind.installationType => 'Installation Type',
  };

  String get _nameLabel => switch (widget.kind) {
    MetadataColourKind.projectType => 'Project type name',
    MetadataColourKind.installationType => 'Installation type name',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  QuoteProjectApiClient get _api => ref.read(quoteProjectApiClientProvider);

  Future<List<MetadataColourItem>> _fetchItems() {
    return switch (widget.kind) {
      MetadataColourKind.projectType => _api.fetchProjectTypes(),
      MetadataColourKind.installationType => _api.fetchInstallationTypes(),
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _fetchItems();
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
          genericFallback: 'Failed to load $_title',
        );
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    context.showTopSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDelete(MetadataColourItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_title.toLowerCase()}?'),
        content: Text('Remove "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await switch (widget.kind) {
        MetadataColourKind.projectType => _api.deleteProjectType(item.id),
        MetadataColourKind.installationType =>
          _api.deleteInstallationType(item.id),
      };
      if (!mounted) return;
      _toast('Deleted');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(
        ApiResponseMessage.fromAnyError(e, genericFallback: 'Delete failed'),
      );
    }
  }

  void _openActions(MetadataColourItem item) {
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
                _showEditor(editing: item);
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

  Future<void> _showEditor({MetadataColourItem? editing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MetadataColourTypeEditorSheet(
        kind: widget.kind,
        editing: editing,
        nameLabel: _nameLabel,
        onSave: (name, bgColor, textColor, isActive) async {
          return switch (widget.kind) {
            MetadataColourKind.projectType =>
              editing == null
                  ? await _api.createProjectType(
                      projectType: name,
                      bgColor: bgColor,
                      textColor: textColor,
                      isActive: isActive,
                    ).then(
                      (created) => MetadataColourItem(
                        id: '${created.id}',
                        name: created.name,
                        bgColour: bgColor,
                        textColour: textColor,
                        isActive: isActive,
                      ),
                    )
                  : await _api.updateProjectType(
                      id: editing.id,
                      projectType: name,
                      bgColor: bgColor,
                      textColor: textColor,
                      isActive: isActive,
                    ),
            MetadataColourKind.installationType =>
              editing == null
                  ? await _api.createInstallationType(
                      installationType: name,
                      bgColor: bgColor,
                      textColor: textColor,
                      isActive: isActive,
                    )
                  : await _api.updateInstallationType(
                      id: editing.id,
                      installationType: name,
                      bgColor: bgColor,
                      textColor: textColor,
                      isActive: isActive,
                    ),
          };
        },
        onMessage: _toast,
        onCompleted: () async {
          if (!mounted) return;
          await _load();
        },
      ),
    );
  }

  Widget _buildMainContent() {
    if (_loading && (_items == null || _items!.isEmpty)) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_items != null && _items!.isEmpty) {
      return MetadataStatusEmptyState(
        title: 'No items yet',
        description:
            'Create your first $_title to start organizing your system metadata.',
        icon: Icons.category_outlined,
      );
    }
    if (_items != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: _MetadataColourTypeListCard(
          items: _items!,
          onMore: _openActions,
        ),
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
          _title,
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
        onPressed: () => _showEditor(),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MetadataStatusSectionLabel(
              label: 'SYSTEM METADATA • ${_title.toUpperCase()}',
            ),
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

class _MetadataColourTypeListCard extends StatelessWidget {
  const _MetadataColourTypeListCard({
    required this.items,
    required this.onMore,
  });

  final List<MetadataColourItem> items;
  final void Function(MetadataColourItem) onMore;

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
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
        itemBuilder: (context, index) {
          final item = items[index];
          final bg = parseHexColor(item.bgColour) ?? AppColors.plotPinBlue;
          final text = parseHexColor(item.textColour) ?? AppColors.white;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                style: AppFonts.labelSmall(color: text).copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              item.name,
              style: AppFonts.bodyLarge(
                color: AppColors.inkStrong,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: item.isActive
                ? null
                : Text(
                    'Inactive',
                    style: AppFonts.bodySmall(color: AppColors.muted),
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: () => onMore(item),
            ),
          );
        },
      ),
    );
  }
}

class _MetadataColourTypeEditorSheet extends StatefulWidget {
  const _MetadataColourTypeEditorSheet({
    required this.kind,
    required this.editing,
    required this.nameLabel,
    required this.onSave,
    required this.onMessage,
    required this.onCompleted,
  });

  final MetadataColourKind kind;
  final MetadataColourItem? editing;
  final String nameLabel;
  final Future<MetadataColourItem> Function(
    String name,
    String bgColor,
    String textColor,
    bool isActive,
  ) onSave;
  final void Function(String) onMessage;
  final Future<void> Function() onCompleted;

  @override
  State<_MetadataColourTypeEditorSheet> createState() =>
      _MetadataColourTypeEditorSheetState();
}

class _MetadataColourTypeEditorSheetState
    extends State<_MetadataColourTypeEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late Color _bgColor;
  late Color _textColor;
  late final TextEditingController _bgHexController;
  late final TextEditingController _textHexController;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _nameController = TextEditingController(text: editing?.name ?? '');
    _bgColor = parseHexColor(editing?.bgColour ?? '') ??
        const Color(0xFFDBEAFE);
    _textColor = parseHexColor(editing?.textColour ?? '') ??
        const Color(0xFF1E40AF);
    _bgHexController = TextEditingController(text: toHexRgb(_bgColor));
    _textHexController = TextEditingController(text: toHexRgb(_textColor));
    _isActive = editing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bgHexController.dispose();
    _textHexController.dispose();
    super.dispose();
  }

  Future<void> _pickColor({
    required Color initial,
    required ValueChanged<Color> onSelected,
    required TextEditingController hexController,
  }) async {
    final picked = await showBrandColorBottomSheet(
      context,
      initialColor: initial,
    );
    if (picked == null || !mounted) return;
    setState(() {
      onSelected(picked);
      hexController.text = toHexRgb(picked);
    });
  }

  Future<void> _submit() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _nameController.text.trim(),
        toHexRgb(_bgColor),
        toHexRgb(_textColor),
        _isActive,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onCompleted();
      if (mounted) {
        widget.onMessage(
          widget.editing == null ? 'Created' : 'Updated',
        );
      }
    } catch (e) {
      if (!mounted) return;
      widget.onMessage(
        ApiResponseMessage.fromAnyError(e, genericFallback: 'Save failed'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _colorField({
    required String label,
    required Color color,
    required TextEditingController hexController,
    required ValueChanged<Color> onColorChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.bodySmall(
            color: const Color(0xFF6B7280),
          ).copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            InkWell(
              onTap: _saving
                  ? null
                  : () => _pickColor(
                      initial: color,
                      onSelected: onColorChanged,
                      hexController: hexController,
                    ),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppTextField(
                controller: hexController,
                hintText: '#DBEAFE',
                readOnly: _saving,
                onChanged: (value) {
                  final parsed = parseHexColor(value);
                  if (parsed != null) setState(() => onColorChanged(parsed));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final title = widget.editing == null
        ? 'Add ${widget.kind == MetadataColourKind.projectType ? 'project type' : 'installation type'}'
        : 'Edit ${widget.kind == MetadataColourKind.projectType ? 'project type' : 'installation type'}';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: AppFonts.labelMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.nameLabel,
                  style: AppFonts.bodySmall(
                    color: const Color(0xFF6B7280),
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                AppTextField(
                  controller: _nameController,
                  hintText: 'e.g. Residential',
                  readOnly: _saving,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _colorField(
                  label: 'Background color',
                  color: _bgColor,
                  hexController: _bgHexController,
                  onColorChanged: (value) => setState(() => _bgColor = value),
                ),
                const SizedBox(height: 16),
                _colorField(
                  label: 'Text color',
                  color: _textColor,
                  hexController: _textHexController,
                  onColorChanged: (value) => setState(() => _textColor = value),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Active',
                    style: AppFonts.bodyMedium(color: AppColors.inkStrong),
                  ),
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
