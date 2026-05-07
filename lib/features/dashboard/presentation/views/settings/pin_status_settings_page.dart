import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';

/// Meta Data → Pin Status categories (static UI for now).
class PinStatusSettingsPage extends StatelessWidget {
  const PinStatusSettingsPage({super.key});

  static const path = '/settings/metadata/pin-status';
  static const name = 'settings-pin-status';

  static const _statusItems = <_PinStatusUi>[
    _PinStatusUi(label: 'Open', color: AppColors.plotPinBlue),
    _PinStatusUi(label: 'In Progress', color: AppColors.plotPinAmber),
    _PinStatusUi(label: 'On Hold', color: AppColors.plotPinViolet),
    _PinStatusUi(label: 'Resolved', color: AppColors.plotPinGreen),
    _PinStatusUi(label: 'Closed', color: AppColors.plotPinRose),
  ];

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
          'Pin Status',
          style: AppFonts.titleMedium(
            color: AppColors.inkStrong,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E7EB)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        onPressed: () => _showAddStatusSheet(context),
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
              _StatusCard(items: _statusItems),
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

String _toHexRgb(Color color) {
  final rgb = color.value.toRadixString(16).padLeft(8, '0').substring(2);
  return '#${rgb.toUpperCase()}';
}

Color? _parseHexColor(String raw) {
  final normalized = raw.trim().replaceAll('#', '');
  if (normalized.length != 6) return null;
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return null;
  return Color(0xFF000000 | value);
}

Future<Color?> _showCustomColorSheet(
  BuildContext context, {
  required Color initialColor,
}) async {
  final controller = TextEditingController(text: _toHexRgb(initialColor));
  var selected = initialColor;
  const palette = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF4F46E5),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFF59E0B),
    Color(0xFFEA580C),
    Color(0xFFE11D48),
    Color(0xFF1E293B),
    Color(0xFF38BDF8),
    Color(0xFF84CC16),
  ];

  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              top: false,
              child: Container(
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Brand Color',
                          style: AppFonts.titleMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: selected,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppTextField(
                              controller: controller,
                              hintText: '#3B82F6',
                              onChanged: (value) {
                                final parsed = _parseHexColor(value);
                                if (parsed != null) {
                                  setState(() => selected = parsed);
                                }
                              },
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CUSTOM',
                            style: AppFonts.labelSmall(color: const Color(0xFF2563EB))
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        InkWell(
                          onTap: () {
                            final parsed = _parseHexColor(controller.text);
                            if (parsed != null) {
                              setState(() => selected = parsed);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: selected,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF93C5FD),
                                width: 2.6,
                              ),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        for (final color in palette)
                          InkWell(
                            onTap: () {
                              setState(() {
                                selected = color;
                                controller.text = _toHexRgb(color);
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected.value == color.value
                                      ? const Color(0xFF93C5FD)
                                      : Colors.transparent,
                                  width: 2.6,
                                ),
                              ),
                              child: selected.value == color.value
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(selected),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Apply Color',
                          style: AppFonts.labelLarge(color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

void _showAddStatusSheet(BuildContext context) {
  final controller = TextEditingController();
  const colors = <Color>[
    AppColors.plotPinBlue,
    AppColors.plotPinGreen,
    AppColors.plotPinAmber,
    AppColors.plotPinRose,
    AppColors.plotPinViolet,
  ];
  var selectedIndex = 0;
  var customColor = colors[selectedIndex];
  var isCustomSelected = false;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setState) {
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
                          'Add Status',
                          style: AppFonts.labelMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.of(ctx).pop(),
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.close_rounded,
                                color: Color.fromARGB(255, 79, 80, 82),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Status Name',
                      style: AppFonts.bodySmall(
                        color: const Color(0xFF6B7280),
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: controller,
                      hintText: 'e.g. In Progress',
                      hintStyle: AppFonts.bodyMedium(
                        color: AppColors.textFieldHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Status Color',
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
                              onTap: () => setState(() {
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
                                    color: i == selectedIndex
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: i == selectedIndex
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x33000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: i == selectedIndex
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
                          onTap: () async {
                            final picked = await _showCustomColorSheet(
                              ctx,
                              initialColor: customColor,
                            );
                            if (picked == null) return;
                            setState(() {
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
                              isCustomSelected ? Icons.check_rounded : Icons.add,
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
                            _toHexRgb(customColor),
                            style: AppFonts.bodySmall(color: AppColors.inkStrong)
                                .copyWith(fontWeight: FontWeight.w700),
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
                        onPressed: () {
                          // TODO: hook into create-pin-status API.
                          Navigator.of(ctx).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF020617),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Save Status',
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
  );
}

class _PinStatusUi {
  const _PinStatusUi({required this.label, required this.color});

  final String label;
  final Color color;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.items});

  final List<_PinStatusUi> items;

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
        separatorBuilder: (_, __) =>
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
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
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
                  onPressed: () {
                    // TODO: per-status actions (edit / delete) menu.
                  },
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
                  'These statuses will be available across all projects '
                  'for pin status within the System Metadata context.',
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
