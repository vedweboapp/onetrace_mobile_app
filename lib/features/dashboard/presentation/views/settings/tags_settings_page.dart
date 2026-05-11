import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:red5/core/theme/app_colors.dart';
import 'package:red5/core/theme/app_fonts.dart';
import 'package:red5/core/widgets/app_text_field.dart';

/// Module and Field -> Quotations tags. Mirrors the Pin Status metadata view.
class TagsSettingsPage extends StatelessWidget {
  const TagsSettingsPage({super.key});

  static const path = '/settings/metadata/tags';
  static const name = 'settings-tags';

  static const _tagItems = <_TagUi>[
    _TagUi(label: 'High Priority', color: AppColors.plotPinRose),
    _TagUi(label: 'Follow Up', color: AppColors.plotPinAmber),
    _TagUi(label: 'Approved', color: AppColors.plotPinGreen),
    _TagUi(label: 'Draft', color: AppColors.plotPinBlue),
    _TagUi(label: 'Internal', color: AppColors.plotPinViolet),
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
          'Tags',
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
        onPressed: () => _showAddTagSheet(context),
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
              _TagCard(items: _tagItems),
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

void _showAddTagSheet(BuildContext context) {
  final controller = TextEditingController();
  const colors = <Color>[
    AppColors.plotPinBlue,
    AppColors.plotPinGreen,
    AppColors.plotPinAmber,
    AppColors.plotPinRose,
    AppColors.plotPinViolet,
  ];
  var selectedIndex = 0;

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
                          'Add Tag',
                          style: AppFonts.labelMedium(
                            color: AppColors.inkStrong,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
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
                              onTap: () => setState(() => selectedIndex = i),
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
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          // TODO: hook into create-tag API when available.
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
                          'Save Tag',
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

class _TagUi {
  const _TagUi({required this.label, required this.color});

  final String label;
  final Color color;
}

class _TagCard extends StatelessWidget {
  const _TagCard({required this.items});

  final List<_TagUi> items;

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
                    // TODO: per-tag actions (edit / delete) menu.
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
