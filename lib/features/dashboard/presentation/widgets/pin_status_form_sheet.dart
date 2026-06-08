import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/core/navigation/safe_overlay_pop.dart';
import 'package:red5/core/utils/text_controller_lifecycle.dart';
import 'package:red5/core/network/api_response_message.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_brand_color_sheet.dart';
import 'package:red5/features/dashboard/presentation/views/settings/metadata_color_utils.dart';
import 'package:red5/features/quote/data/quote_project_api_client.dart';

Future<void> showPinStatusFormSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Future<void> Function(PinStatusItem saved) onSaved,
  required void Function(String) onMessage,
  PinStatusItem? editing,
}) async {
  final api = ref.read(quoteProjectApiClientProvider);
  final controller = TextEditingController(text: editing?.statusName ?? '');
  const colors = <Color>[
    AppColors.plotPinBlue,
    AppColors.plotPinGreen,
    AppColors.plotPinAmber,
    AppColors.plotPinRose,
    AppColors.plotPinViolet,
  ];
  var selectedIndex = 0;
  var customColor = parseHexColor(editing?.bgColour ?? '') ?? colors[0];
  var isCustomSelected = false;
  final isActive = editing?.isActive ?? true;
  if (editing != null) {
    final matchIdx = colors.indexWhere((c) => colorsEqual(c, customColor));
    if (matchIdx >= 0) {
      selectedIndex = matchIdx;
      isCustomSelected = false;
    } else {
      isCustomSelected = true;
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      var saving = false;
      final maxSheetHeight = MediaQuery.sizeOf(ctx).height * 0.92;

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> submit() async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  onMessage('Please enter a status name');
                  return;
                }
                final bgHex = toHexRgb(customColor);
                final textHex = contrastTextHexForBg(customColor);
                setSheetState(() => saving = true);
                var closedSheet = false;
                try {
                  final PinStatusItem savedItem;
                  if (editing == null) {
                    savedItem = await api.createPinStatus(
                      statusName: name,
                      bgColour: bgHex,
                      textColour: textHex,
                      isActive: true,
                    );
                  } else {
                    savedItem = await api.updatePinStatus(
                      statusId: editing.id,
                      statusName: name,
                      bgColour: bgHex,
                      textColour: textHex,
                      isActive: isActive,
                    );
                  }
                  if (ctx.mounted) {
                    popOverlaySafely(ctx);
                    closedSheet = true;
                  }
                  await onSaved(savedItem);
                  if (context.mounted) {
                    onMessage(
                      editing == null ? 'Status created' : 'Status updated',
                    );
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
                  if (!closedSheet && context.mounted) {
                    setSheetState(() => saving = false);
                  }
                }
              }

              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              editing == null ? 'Add Status' : 'Edit Status',
                              style:
                                  AppFonts.titleMedium(
                                    color: AppColors.inkStrong,
                                  ).copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () => popOverlaySafely(ctx),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF6B7280),
                                size: 22,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Status Name',
                          style: AppFonts.bodySmall(
                            color: const Color(0xFF6B7280),
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: controller,
                          hintText: 'e.g. In Progress',
                          hintStyle: AppFonts.bodyMedium(
                            color: AppColors.textFieldHint,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Status Color',
                          style: AppFonts.bodySmall(
                            color: const Color(0xFF6B7280),
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (var i = 0; i < colors.length; i++)
                              Padding(
                                padding: EdgeInsets.only(
                                  right: i == colors.length - 1 ? 12 : 14,
                                ),
                                child: _StatusColorSwatch(
                                  color: colors[i],
                                  selected:
                                      i == selectedIndex && !isCustomSelected,
                                  onTap: saving
                                      ? null
                                      : () => setSheetState(() {
                                          selectedIndex = i;
                                          customColor = colors[i];
                                          isCustomSelected = false;
                                        }),
                                ),
                              ),
                            _StatusColorSwatch(
                              color: isCustomSelected
                                  ? customColor
                                  : const Color(0xFFF3F4F6),
                              selected: isCustomSelected,
                              showAddIcon: !isCustomSelected,
                              onTap: saving
                                  ? null
                                  : () async {
                                      final picked =
                                          await showBrandColorBottomSheet(
                                            ctx,
                                            initialColor: customColor,
                                          );
                                      if (picked == null) return;
                                      setSheetState(() {
                                        customColor = picked;
                                        isCustomSelected = true;
                                      });
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: saving ? null : submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.inkStrong,
                              foregroundColor: Colors.white,
                              elevation: 0,
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
                                    'Save Status',
                                    style: AppFonts.bodyLarge(
                                      color: Colors.white,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  ).whenComplete(() => scheduleDisposeTextControllers([controller]));
}

class _StatusColorSwatch extends StatelessWidget {
  const _StatusColorSwatch({
    required this.color,
    required this.selected,
    this.onTap,
    this.showAddIcon = false,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final bool showAddIcon;

  @override
  Widget build(BuildContext context) {
    final ringColor = showAddIcon
        ? const Color(0xFFE5E7EB)
        : (selected ? color : Colors.transparent);

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: ringColor,
            width: selected && !showAddIcon ? 2.5 : 1.5,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: selected && !showAddIcon
                ? Border.all(color: Colors.white, width: 2.5)
                : null,
          ),
          child: showAddIcon
              ? const Icon(Icons.add, size: 20, color: Color(0xFF9CA3AF))
              : null,
        ),
      ),
    );
  }
}
