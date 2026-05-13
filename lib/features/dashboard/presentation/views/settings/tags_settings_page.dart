import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_brand_color_sheet.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

/// Module and Field → Tags for quotations (`GET/POST /api/v1/tag/`, `PUT/DELETE …/{id}/`).
class TagsSettingsPage extends ConsumerStatefulWidget {
  const TagsSettingsPage({super.key});

  static const path = '/settings/metadata/tags';
  static const name = 'settings-tags';

  @override
  ConsumerState<TagsSettingsPage> createState() => _TagsSettingsPageState();
}

class _TagsSettingsPageState extends ConsumerState<TagsSettingsPage> {
  List<TagItem>? _items;
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
      final list = await api.fetchTags();
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
          genericFallback: 'Failed to load tags',
        );
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDelete(TagItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tag?'),
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
      await ref.read(quoteProjectApiClientProvider).deleteTag(item.id);
      if (!mounted) return;
      _toast('Tag deleted');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _toast(
        ApiResponseMessage.fromAnyError(
          e,
          genericFallback: 'Delete failed',
        ),
      );
    }
  }

  void _openActions(TagItem item) {
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
                _showTagEditorSheet(editing: item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFB91C1C)),
              title: const Text('Delete', style: TextStyle(color: Color(0xFFB91C1C))),
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

  void _showTagEditorSheet({TagItem? editing}) {
    _showTagFormSheet(
      context: context,
      ref: ref,
      editing: editing,
      onSaved: _load,
      onMessage: _toast,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.inkStrong),
        ),
        title: Text(
          'Tags',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: AppColors.inkStrong),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        onPressed: () => _showTagEditorSheet(),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: AppFonts.bodyMedium(color: const Color(0xFFB91C1C)),
                  ),
                ),
              if (_loading && (_items == null || _items!.isEmpty))
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_items != null && _items!.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No tags yet.\nTap + to create one.',
                      textAlign: TextAlign.center,
                      style: AppFonts.bodyMedium(color: AppColors.muted),
                    ),
                  ),
                )
              else if (_items != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: _TagCard(
                      items: _items!,
                      onMore: _openActions,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const _VisibilityInfoCard(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

void _showTagFormSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Future<void> Function() onSaved,
  required void Function(String) onMessage,
  TagItem? editing,
}) {
  final api = ref.read(quoteProjectApiClientProvider);
  final controller = TextEditingController(text: editing?.name ?? '');
  const colors = <Color>[
    AppColors.plotPinBlue,
    AppColors.plotPinGreen,
    AppColors.plotPinAmber,
    AppColors.plotPinRose,
    AppColors.plotPinViolet,
  ];
  var selectedIndex = 0;
  var customColor =
      parseHexColor(editing?.colourHex ?? '') ?? colors[0];
  var isCustomSelected = false;
  if (editing != null) {
    final matchIdx = colors.indexWhere((c) => colorsEqual(c, customColor));
    if (matchIdx >= 0) {
      selectedIndex = matchIdx;
      isCustomSelected = false;
    } else {
      isCustomSelected = true;
    }
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      var saving = false;

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> submit() async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  onMessage('Please enter a tag name');
                  return;
                }
                final colourHex = toHexRgb(customColor);
                final textHex = contrastTextHexForBg(customColor);
                setSheetState(() => saving = true);
                try {
                  if (editing == null) {
                    await api.createTag(
                      name: name,
                      colourHex: colourHex,
                      textColourHex: textHex,
                      isActive: true,
                    );
                  } else {
                    await api.updateTag(
                      tagId: editing.id,
                      name: name,
                      colourHex: colourHex,
                      textColourHex: textHex,
                      isActive: editing.isActive,
                    );
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  await onSaved();
                  if (context.mounted) {
                    onMessage(editing == null ? 'Tag created' : 'Tag updated');
                  }
                } catch (e) {
                  if (context.mounted) {
                    onMessage(
                      ApiResponseMessage.fromAnyError(
                        e,
                        genericFallback: 'Save failed',
                      ),
                    );
                  }
                } finally {
                  if (context.mounted) {
                    setSheetState(() => saving = false);
                  }
                }
              }

              return Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
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
                    Row(
                      children: [
                        Text(
                          editing == null ? 'Add Tag' : 'Edit Tag',
                          style: AppFonts.labelMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: saving ? null : () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Color.fromARGB(255, 79, 80, 82),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Tag Name',
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF6B7280),
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: controller,
                      hintText: 'e.g. High Priority',
                      hintStyle: AppFonts.bodyMedium(
                        color: AppColors.textFieldHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tag Color',
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF6B7280),
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < colors.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              right: i == colors.length - 1 ? 0 : 12,
                            ),
                            child: InkWell(
                              onTap: saving
                                  ? null
                                  : () => setSheetState(() {
                                        selectedIndex = i;
                                        customColor = colors[i];
                                        isCustomSelected = false;
                                      }),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors[i],
                                  border: Border.all(
                                    color: i == selectedIndex && !isCustomSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: i == selectedIndex && !isCustomSelected
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x33000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: i == selectedIndex && !isCustomSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: saving
                              ? null
                              : () async {
                                  final picked = await showBrandColorBottomSheet(
                                    ctx,
                                    initialColor: customColor,
                                  );
                                  if (picked == null) return;
                                  setSheetState(() {
                                    customColor = picked;
                                    isCustomSelected = true;
                                  });
                                },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCustomSelected
                                  ? customColor
                                  : const Color(0xFFF3F4F6),
                              border: Border.all(
                                color: isCustomSelected
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFFE5E7EB),
                                width: isCustomSelected ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              isCustomSelected
                                  ? Icons.check_rounded
                                  : Icons.add,
                              size: 16,
                              color: isCustomSelected
                                  ? Colors.white
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isCustomSelected) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            'Selected:',
                            style: AppFonts.bodySmall(
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: customColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            toHexRgb(customColor),
                            style: AppFonts.bodySmall(
                              color: AppColors.inkStrong,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CUSTOM',
                            style: AppFonts.labelSmall(
                              color: const Color(0xFF2563EB),
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: saving ? null : submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF020617),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                editing == null ? 'Save Tag' : 'Update Tag',
                                style: AppFonts.labelLarge(
                                  color: Colors.white,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  ).whenComplete(controller.dispose);
}

class _TagCard extends StatelessWidget {
  const _TagCard({
    required this.items,
    required this.onMore,
  });

  final List<TagItem> items;
  final void Function(TagItem) onMore;

  Color _dotColor(TagItem t) =>
      parseHexColor(t.colourHex) ?? AppColors.plotPinBlue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _dotColor(item),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.name,
                    style: AppFonts.bodyLarge(
                      color: AppColors.inkStrong,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.mutedLight,
                    size: 20,
                  ),
                  onPressed: () => onMore(item),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VisibilityInfoCard extends StatelessWidget {
  const _VisibilityInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage Visibility',
                  style: AppFonts.bodyMedium(
                    color: AppColors.inkStrong,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'These tags will be available across all quotations within '
                  'the System Metadata context.',
                  style: AppFonts.bodySmall(
                    color: const Color(0xFF6B7280),
                  ).copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
